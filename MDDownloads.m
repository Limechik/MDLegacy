#import "MDDownloads.h"
#import "MDApi.h"
#import "MDHttp.h"
#import "MDSettings.h"
#import "MDUtil.h"
#import <UIKit/UIKit.h>

NSString *const MDDownloadsChangedNotification = @"MDDownloadsChanged";

@implementation MDDownloads
static NSMutableDictionary *gIndex;      // {mangas:{id:{title,author,coverFile}}, chapters:{id:{mangaId,number,volume,title,language,group,published,pages,bytes}}}
static NSMutableDictionary *gActive;     // chapterId → {state: queued|loading|failed, done, total, mangaId, error}
static NSMutableSet *gCancelled;
static NSOperationQueue *gQueue;
static UIBackgroundTaskIdentifier gBg;
static BOOL gNotifyPending;

+ (void)initialize {
    if (self != [MDDownloads class]) return;
    gActive = [NSMutableDictionary dictionary]; gCancelled = [NSMutableSet set];
    gQueue = [NSOperationQueue new]; gQueue.maxConcurrentOperationCount = 1;   // one chapter at a time
    gBg = UIBackgroundTaskInvalid;
}

#pragma mark - Paths / index
+ (NSString *)root {
    static NSString *r; static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        r = [docs stringByAppendingPathComponent:@"Downloads"];
        [[NSFileManager defaultManager] createDirectoryAtPath:r withIntermediateDirectories:YES attributes:nil error:nil];
        [[NSURL fileURLWithPath:r] setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];   // don't fill iCloud backup
    });
    return r;
}
+ (NSString *)indexPath {
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0]
             stringByAppendingPathComponent:@"downloads.plist"] copy];
}
+ (NSMutableDictionary *)index {                       // inside @synchronized(self)
    if (!gIndex) {
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:[self indexPath]];
        gIndex = [NSMutableDictionary dictionary];
        gIndex[@"mangas"]   = [NSMutableDictionary dictionaryWithDictionary:d[@"mangas"]   ?: @{}];
        gIndex[@"chapters"] = [NSMutableDictionary dictionaryWithDictionary:d[@"chapters"] ?: @{}];
    }
    return gIndex;
}
+ (void)saveIndex { [[self index] writeToFile:[self indexPath] atomically:YES]; }
+ (NSString *)mangaDir:(NSString *)mid { return [[self root] stringByAppendingPathComponent:mid]; }
+ (NSString *)chapterDir:(NSString *)cid manga:(NSString *)mid { return [[self mangaDir:mid] stringByAppendingPathComponent:cid]; }

+ (void)notify {
    @synchronized (self) { if (gNotifyPending) return; gNotifyPending = YES; }
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @synchronized (self) { gNotifyPending = NO; }
            [[NSNotificationCenter defaultCenter] postNotificationName:MDDownloadsChangedNotification object:nil];
        });
    });
}

+ (void)updateBackgroundTask {                          // keep downloading for a while after the app is backgrounded
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL busy = NO;
        @synchronized (self) { for (NSDictionary *a in gActive.allValues) if (![a[@"state"] isEqual:@"failed"]) { busy = YES; break; } }
        UIApplication *app = [UIApplication sharedApplication];
        if (busy && gBg == UIBackgroundTaskInvalid) {
            gBg = [app beginBackgroundTaskWithExpirationHandler:^{ [app endBackgroundTask:gBg]; gBg = UIBackgroundTaskInvalid; }];
        } else if (!busy && gBg != UIBackgroundTaskInvalid) {
            [app endBackgroundTask:gBg]; gBg = UIBackgroundTaskInvalid;
        }
    });
}

#pragma mark - Queue
+ (void)enqueueChapters:(NSArray *)chapters manga:(MDManga *)m {
    if (!m.identifier.length) return;
    NSMutableArray *todo = [NSMutableArray array];
    @synchronized (self) {
        [self index][@"mangas"][m.identifier] = @{@"title": m.title ?: @"", @"author": m.author ?: @"", @"coverFile": m.coverFile ?: @""};
        for (MDChapter *c in chapters) {
            if ([self index][@"chapters"][c.identifier]) continue;                         // already offline
            NSString *st = gActive[c.identifier][@"state"];
            if (st && ![st isEqual:@"failed"]) continue;                                    // already queued/running
            gActive[c.identifier] = [@{@"state": @"queued", @"done": @0, @"total": @(c.pages), @"mangaId": m.identifier} mutableCopy];
            [gCancelled removeObject:c.identifier];
            [todo addObject:c];
        }
        [self saveIndex];
    }
    if (!todo.count) return;
    [self updateBackgroundTask]; [self notify];
    for (MDChapter *c in todo)
        [gQueue addOperationWithBlock:^{ @autoreleasepool { [self runChapter:c manga:m]; } }];
}

+ (BOOL)isCancelled:(NSString *)cid { @synchronized (self) { return [gCancelled containsObject:cid]; } }

+ (void)cancelChapter:(NSString *)cid {
    @synchronized (self) { [gCancelled addObject:cid]; [gActive removeObjectForKey:cid]; }
    [self updateBackgroundTask]; [self notify];
}

+ (void)setState:(NSString *)s chapter:(NSString *)cid done:(NSInteger)d total:(NSInteger)t error:(NSString *)e {
    @synchronized (self) {
        NSMutableDictionary *a = gActive[cid]; if (!a) return;
        a[@"state"] = s; if (d >= 0) a[@"done"] = @(d); if (t >= 0) a[@"total"] = @(t); if (e) a[@"error"] = e;
    }
    [self notify];
}

+ (NSInteger)existingPagesInDir:(NSString *)dir total:(NSInteger)n {
    NSFileManager *fm = [NSFileManager defaultManager]; NSInteger have = 0;
    for (NSString *f in [fm contentsOfDirectoryAtPath:dir error:nil]) {
        NSInteger idx = [f integerValue];
        if (idx < n && [[fm attributesOfItemAtPath:[dir stringByAppendingPathComponent:f] error:nil] fileSize] > 0) have++;
    }
    return have;
}

+ (void)ensureCoverForManga:(MDManga *)m {
    NSString *path = [[self mangaDir:m.identifier] stringByAppendingPathComponent:@"cover.jpg"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return;
    NSString *url = [m coverUrlForPixelWidth:256]; if (!url) return;
    MDHttpResponse *r = [MDHttp get:url cacheForTTL:0];
    if (r.isSuccessful && r.body.length) [r.body writeToFile:path atomically:YES];
}

+ (void)downloadMissing:(NSArray *)urls dir:(NSString *)dir chapter:(NSString *)cid {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableSet *have = [NSMutableSet set];
    for (NSString *f in [fm contentsOfDirectoryAtPath:dir error:nil])
        if ([[fm attributesOfItemAtPath:[dir stringByAppendingPathComponent:f] error:nil] fileSize] > 0) [have addObject:@([f integerValue])];
    NSObject *lock = [NSObject new]; __block NSInteger done = have.count; NSInteger total = urls.count;
    [self setState:@"loading" chapter:cid done:done total:total error:nil];
    NSOperationQueue *pq = [NSOperationQueue new]; pq.maxConcurrentOperationCount = 3;
    for (NSInteger i = 0; i < total; i++) {
        if ([have containsObject:@(i)]) continue;
        NSString *url = urls[i], *ext = [[url pathExtension] lowercaseString];
        if (!ext.length) ext = @"jpg";
        NSString *path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%03ld.%@", (long)i, ext]];
        [pq addOperationWithBlock:^{
            @autoreleasepool {
                for (int attempt = 0; attempt < 3; attempt++) {
                    if ([self isCancelled:cid]) return;
                    MDHttpResponse *r = [MDHttp get:url cacheForTTL:0];
                    if (r.isSuccessful && r.body.length) {
                        [r.body writeToFile:path atomically:YES];
                        NSInteger d; @synchronized (lock) { done++; d = done; }
                        [self setState:@"loading" chapter:cid done:d total:total error:nil];
                        return;
                    }
                    [NSThread sleepForTimeInterval:1.0 + attempt];
                }
            }
        }];
    }
    [pq waitUntilAllOperationsAreFinished];
}

+ (void)runChapter:(MDChapter *)c manga:(MDManga *)m {
    NSString *cid = c.identifier, *mid = m.identifier;
    if ([self isCancelled:cid]) { @synchronized (self) { [gCancelled removeObject:cid]; } [self updateBackgroundTask]; return; }
    @synchronized (self) { if (!gActive[cid]) return; }
    NSString *dir = [self chapterDir:cid manga:mid];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    [self setState:@"loading" chapter:cid done:-1 total:-1 error:nil];
    [self ensureCoverForManga:m];

    BOOL saver = [MDSettings dataSaver]; NSInteger total = 0; NSString *err = @"не удалось получить страницы";
    for (int round = 0; round < 3; round++) {
        if ([self isCancelled:cid]) break;
        NSError *e = nil;
        NSArray *urls = [MDApi pagesOfChapter:cid saver:saver useCache:(round == 0) error:&e];   // later rounds: fresh server
        if (!urls) { err = e.localizedDescription ?: err; [NSThread sleepForTimeInterval:2]; continue; }
        total = urls.count;
        [self downloadMissing:urls dir:dir chapter:cid];
        if ([self existingPagesInDir:dir total:total] >= total) { err = nil; break; }
        err = @"не все страницы загружены"; [NSThread sleepForTimeInterval:2];
    }

    if ([self isCancelled:cid]) {
        [[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
        @synchronized (self) { [gCancelled removeObject:cid]; }
    } else if (!err && total > 0) {
        unsigned long long bytes = 0; NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *f in [fm contentsOfDirectoryAtPath:dir error:nil])
            bytes += [[fm attributesOfItemAtPath:[dir stringByAppendingPathComponent:f] error:nil] fileSize];
        @synchronized (self) {
            [self index][@"chapters"][cid] = @{@"mangaId": mid, @"number": c.number ?: @"", @"volume": c.volume ?: @"",
                @"title": c.title ?: @"", @"language": c.language ?: @"", @"group": c.group ?: @"",
                @"published": c.published ?: [NSDate dateWithTimeIntervalSince1970:0],
                @"pages": @(total), @"bytes": @(bytes)};
            [gActive removeObjectForKey:cid]; [self saveIndex];
        }
    } else {
        [self setState:@"failed" chapter:cid done:-1 total:-1 error:err];
    }
    [self updateBackgroundTask]; [self notify];
}

#pragma mark - Queries
+ (BOOL)isDownloaded:(NSString *)cid { @synchronized (self) { return [self index][@"chapters"][cid] != nil; } }

+ (NSString *)statusForChapter:(NSString *)cid {
    @synchronized (self) {
        NSDictionary *a = gActive[cid];
        if (a) {
            NSString *s = a[@"state"];
            if ([s isEqual:@"queued"]) return @"в очереди";
            if ([s isEqual:@"failed"]) return @"ошибка загрузки";
            NSInteger t = [a[@"total"] integerValue], d = [a[@"done"] integerValue];
            return t > 0 ? [NSString stringWithFormat:@"%ld%%", (long)(d * 100 / t)] : @"загрузка…";
        }
        return [self index][@"chapters"][cid] ? @"офлайн" : nil;
    }
}

+ (NSArray *)localPagesForChapter:(NSString *)cid {
    NSDictionary *rec; @synchronized (self) { rec = [self index][@"chapters"][cid]; }
    if (!rec) return nil;
    NSString *dir = [self chapterDir:cid manga:rec[@"mangaId"]];
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil])
        if ([f integerValue] >= 0 && [f length] > 3 && isdigit([f characterAtIndex:0])) [files addObject:f];
    [files sortUsingSelector:@selector(compare:)];                                         // 000.jpg, 001.jpg …
    if ((NSInteger)files.count < [rec[@"pages"] integerValue]) return nil;                 // damaged → fall back to network
    NSMutableArray *paths = [NSMutableArray array];
    for (NSString *f in files) [paths addObject:[dir stringByAppendingPathComponent:f]];
    return paths;
}

+ (void)deleteChapter:(NSString *)cid {
    @synchronized (self) {
        NSDictionary *rec = [self index][@"chapters"][cid]; if (!rec) return;
        NSString *mid = rec[@"mangaId"];
        [[NSFileManager defaultManager] removeItemAtPath:[self chapterDir:cid manga:mid] error:nil];
        [[self index][@"chapters"] removeObjectForKey:cid];
        BOOL any = NO; for (NSDictionary *r in [[self index][@"chapters"] allValues]) if ([r[@"mangaId"] isEqual:mid]) { any = YES; break; }
        if (!any) { [[self index][@"mangas"] removeObjectForKey:mid]; [[NSFileManager defaultManager] removeItemAtPath:[self mangaDir:mid] error:nil]; }
        [self saveIndex];
    }
    [self notify];
}
+ (void)deleteManga:(NSString *)mid {
    @synchronized (self) {
        for (NSString *cid in [[self index][@"chapters"] allKeys])
            if ([[self index][@"chapters"][cid][@"mangaId"] isEqual:mid]) [[self index][@"chapters"] removeObjectForKey:cid];
        [[self index][@"mangas"] removeObjectForKey:mid];
        [[NSFileManager defaultManager] removeItemAtPath:[self mangaDir:mid] error:nil];
        [self saveIndex];
    }
    [self notify];
}
+ (void)deleteAll {
    @synchronized (self) {
        [[self index][@"chapters"] removeAllObjects]; [[self index][@"mangas"] removeAllObjects];
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *f in [fm contentsOfDirectoryAtPath:[self root] error:nil]) [fm removeItemAtPath:[[self root] stringByAppendingPathComponent:f] error:nil];
        [self saveIndex];
    }
    [self notify];
}

+ (NSString *)coverPathForManga:(NSString *)mid {
    NSString *p = [[self mangaDir:mid] stringByAppendingPathComponent:@"cover.jpg"];
    return [[NSFileManager defaultManager] fileExistsAtPath:p] ? p : nil;
}

+ (NSArray *)downloadedMangas {
    NSMutableArray *out = [NSMutableArray array];
    @synchronized (self) {
        NSMutableDictionary *count = [NSMutableDictionary dictionary], *bytes = [NSMutableDictionary dictionary];
        for (NSDictionary *r in [[self index][@"chapters"] allValues]) {
            NSString *mid = r[@"mangaId"];
            count[mid] = @([count[mid] integerValue] + 1); bytes[mid] = @([bytes[mid] unsignedLongLongValue] + [r[@"bytes"] unsignedLongLongValue]);
        }
        for (NSString *mid in count) {
            NSDictionary *m = [self index][@"mangas"][mid];
            [out addObject:@{@"mangaId": mid, @"title": m[@"title"] ?: @"", @"author": m[@"author"] ?: @"", @"coverFile": m[@"coverFile"] ?: @"",
                             @"count": count[mid], @"bytes": bytes[mid]}];
        }
    }
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"title"] localizedCaseInsensitiveCompare:b[@"title"]]; }];
    return out;
}

+ (NSArray *)downloadedChaptersOfManga:(NSString *)mid {
    NSMutableArray *out = [NSMutableArray array];
    @synchronized (self) {
        NSDictionary *all = [self index][@"chapters"];
        for (NSString *cid in all) {
            NSDictionary *r = all[cid]; if (![r[@"mangaId"] isEqual:mid]) continue;
            MDChapter *c = [MDChapter new]; c.identifier = cid;
            c.number = [r[@"number"] length] ? r[@"number"] : nil; c.volume = [r[@"volume"] length] ? r[@"volume"] : nil;
            c.title = [r[@"title"] length] ? r[@"title"] : nil; c.language = r[@"language"];
            c.group = [r[@"group"] length] ? r[@"group"] : nil; c.published = r[@"published"]; c.pages = [r[@"pages"] integerValue];
            [out addObject:c];
        }
    }
    [out sortUsingComparator:^NSComparisonResult(MDChapter *a, MDChapter *b) {
        double x = a.number ? a.number.doubleValue : -1, y = b.number ? b.number.doubleValue : -1;
        if (x < y) return NSOrderedAscending; if (x > y) return NSOrderedDescending;
        return (a.published && b.published) ? [a.published compare:b.published] : NSOrderedSame;
    }];
    return out;
}

+ (NSInteger)pendingCountForManga:(NSString *)mid {
    NSInteger n = 0;
    @synchronized (self) { for (NSDictionary *a in gActive.allValues) if ([a[@"mangaId"] isEqual:mid] && ![a[@"state"] isEqual:@"failed"]) n++; }
    return n;
}
+ (unsigned long long)totalSize {
    unsigned long long t = 0;
    @synchronized (self) { for (NSDictionary *r in [[self index][@"chapters"] allValues]) t += [r[@"bytes"] unsignedLongLongValue]; }
    return t;
}
@end
