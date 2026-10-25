#import "MDLibrary.h"

@implementation MDLibrary
static NSMutableDictionary *gStore;

+ (NSString *)path {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    return [docs stringByAppendingPathComponent:@"library.plist"];
}
+ (NSMutableDictionary *)store {                      // call inside @synchronized(self)
    if (!gStore) {
        gStore = [NSMutableDictionary dictionaryWithContentsOfFile:[self path]] ?: [NSMutableDictionary dictionary];
        for (NSString *k in @[@"favorites", @"history"])
            if (![gStore[k] isKindOfClass:[NSMutableArray class]]) gStore[k] = [NSMutableArray arrayWithArray:gStore[k] ?: @[]];
        if (![gStore[@"progress"] isKindOfClass:[NSMutableDictionary class]])
            gStore[@"progress"] = [NSMutableDictionary dictionaryWithDictionary:gStore[@"progress"] ?: @{}];
    }
    return gStore;
}
+ (void)save { [[self store] writeToFile:[self path] atomically:YES]; }

+ (NSArray *)favorites { @synchronized (self) { return [[self store][@"favorites"] copy]; } }
+ (BOOL)isFavorite:(NSString *)mid {
    @synchronized (self) { for (NSDictionary *d in [self store][@"favorites"]) if ([d[@"mangaId"] isEqual:mid]) return YES; }
    return NO;
}
+ (void)addFavorite:(MDManga *)m {
    if ([self isFavorite:m.identifier]) return;
    @synchronized (self) {
        [[self store][@"favorites"] insertObject:@{@"mangaId": m.identifier, @"title": m.title ?: @"",
            @"coverFile": m.coverFile ?: @"", @"added": [NSDate date]} atIndex:0];
        [self save];
    }
}
+ (void)removeFavorite:(NSString *)mid {
    @synchronized (self) {
        NSMutableArray *a = [self store][@"favorites"];
        for (NSInteger i = a.count - 1; i >= 0; i--) if ([a[i][@"mangaId"] isEqual:mid]) [a removeObjectAtIndex:i];
        [self save];
    }
}

+ (void)recordManga:(MDManga *)m chapter:(MDChapter *)c page:(NSInteger)page total:(NSInteger)total {
    if (!m.identifier || !c.identifier) return;
    @synchronized (self) {
        NSMutableArray *h = [self store][@"history"];
        for (NSInteger i = h.count - 1; i >= 0; i--) if ([h[i][@"mangaId"] isEqual:m.identifier]) [h removeObjectAtIndex:i];
        [h insertObject:@{@"mangaId": m.identifier, @"title": m.title ?: @"", @"coverFile": m.coverFile ?: @"",
            @"chapterId": c.identifier, @"chapterName": [c displayName], @"page": @(page), @"time": [NSDate date]} atIndex:0];
        while (h.count > 100) [h removeLastObject];
        BOOL finished = total > 0 && page >= total - 1;
        [self store][@"progress"][c.identifier] = @{@"page": @(page), @"finished": @(finished)};
        [self save];
    }
}
+ (NSArray *)history { @synchronized (self) { return [[self store][@"history"] copy]; } }
+ (NSDictionary *)lastReadOfManga:(NSString *)mid {
    for (NSDictionary *d in [self history]) if ([d[@"mangaId"] isEqual:mid]) return d;
    return nil;
}
+ (void)clearHistory { @synchronized (self) { [[self store][@"history"] removeAllObjects]; [self save]; } }

+ (NSInteger)pageOfChapter:(NSString *)cid {
    @synchronized (self) {
        NSDictionary *p = [self store][@"progress"][cid];
        return [p[@"finished"] boolValue] ? 0 : [p[@"page"] integerValue];
    }
}
+ (BOOL)isChapterFinished:(NSString *)cid {
    @synchronized (self) { return [[self store][@"progress"][cid][@"finished"] boolValue]; }
}
@end
