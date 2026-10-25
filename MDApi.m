#import "MDApi.h"
#import "MDHttp.h"
#import "MDSettings.h"
#import "MDUtil.h"
#include <unistd.h>

static NSString *const kBase = @"https://api.mangadex.org";
static NSTimeInterval gLastRequest;

@implementation MDApi

+ (NSInteger)pageSize { return 24; }

+ (NSError *)errorWithText:(NSString *)t code:(NSInteger)c {
    return [NSError errorWithDomain:@"ru.local.mangadex.api" code:c userInfo:@{NSLocalizedDescriptionKey: t}];
}

// ≥0.24 s between requests (API allows ~5 req/s).
+ (void)pace {
    @synchronized (self) {
        NSTimeInterval now = CFAbsoluteTimeGetCurrent();
        double wait = (gLastRequest - now) + 0.24;
        if (wait > 0) { usleep((useconds_t)(wait * 1e6)); now = CFAbsoluteTimeGetCurrent(); }
        gLastRequest = now;
    }
}

+ (id)request:(NSString *)path ttl:(NSTimeInterval)ttl error:(NSError **)err {
    NSString *url = [kBase stringByAppendingString:path];
    BOOL canRetry = YES;
    for (;;) {
        [self pace];
        MDHttpResponse *r = [MDHttp get:url cacheForTTL:ttl];
        if (r.error) { if (err) *err = r.error; return nil; }
        if (canRetry && r.statusCode == 429) {                    // rate-limited: wait Retry-After once
            NSInteger s = [r.headers[@"retry-after"] integerValue];
            if (s < 1 || s > 28) s = 1;
            sleep((unsigned)s); canRetry = NO; continue;
        }
        if (!r.isSuccessful) {
            if (err) *err = [self errorWithText:[NSString stringWithFormat:@"Ошибка сервера (HTTP %ld)", (long)r.statusCode] code:r.statusCode];
            return nil;
        }
        id j = r.body.length ? [NSJSONSerialization JSONObjectWithData:r.body options:0 error:nil] : nil;
        if (!j) { if (err) *err = [self errorWithText:@"Неверный ответ" code:-2]; return nil; }
        return j;
    }
}

+ (NSString *)ratingsSuffix {
    NSMutableString *s = [NSMutableString string];
    for (NSString *r in [MDSettings contentRatings]) [s appendFormat:@"&contentRating[]=%@", r];
    return s;
}
+ (NSString *)catalogSuffix {
    return [NSString stringWithFormat:@"&includes[]=cover_art&includes[]=author%@&hasAvailableChapters=true", [self ratingsSuffix]];
}

+ (NSArray *)listPath:(NSString *)path total:(NSInteger *)t error:(NSError **)e {
    NSDictionary *j = [self request:path ttl:120 error:e];
    if (![j isKindOfClass:[NSDictionary class]]) return nil;
    if (t) *t = [j[@"total"] integerValue];
    return [MDManga listFromJson:j[@"data"]];
}

+ (NSArray *)popularWithOffset:(NSInteger)o total:(NSInteger *)t error:(NSError **)e {
    return [self listPath:[NSString stringWithFormat:@"/manga?limit=%ld&offset=%ld&order[followedCount]=desc%@",
                           (long)[self pageSize], (long)o, [self catalogSuffix]] total:t error:e];
}
+ (NSArray *)latestWithOffset:(NSInteger)o total:(NSInteger *)t error:(NSError **)e {
    return [self listPath:[NSString stringWithFormat:@"/manga?limit=%ld&offset=%ld&order[latestUploadedChapter]=desc%@",
                           (long)[self pageSize], (long)o, [self catalogSuffix]] total:t error:e];
}
+ (NSArray *)searchTitle:(NSString *)q offset:(NSInteger)o total:(NSInteger *)t error:(NSError **)e {
    return [self listPath:[NSString stringWithFormat:@"/manga?limit=%ld&offset=%ld&title=%@%@",
                           (long)[self pageSize], (long)o, [MDUtil escape:q], [self catalogSuffix]] total:t error:e];
}

+ (MDManga *)manga:(NSString *)ident error:(NSError **)e {
    NSDictionary *j = [self request:[NSString stringWithFormat:@"/manga/%@?includes[]=cover_art&includes[]=author&includes[]=artist", ident]
                                ttl:300 error:e];
    MDManga *m = [j isKindOfClass:[NSDictionary class]] ? [MDManga fromJson:j[@"data"]] : nil;
    if (!m && e && !*e) *e = [self errorWithText:@"Манга не найдена" code:-3];
    return m;
}

// Feed is paged (max 500). Ascending by volume, then chapter.
+ (NSArray *)chaptersOfManga:(NSString *)ident language:(NSString *)lang error:(NSError **)e {
    NSMutableArray *all = [NSMutableArray array];
    NSInteger offset = 0, total = 0;
    do {
        NSString *p = [NSString stringWithFormat:
            @"/manga/%@/feed?limit=500&offset=%ld&order[volume]=asc&order[chapter]=asc&includes[]=scanlation_group%@",
            ident, (long)offset, [self ratingsSuffix]];
        if (lang.length) p = [p stringByAppendingFormat:@"&translatedLanguage[]=%@", lang];
        NSDictionary *j = [self request:p ttl:120 error:e];
        if (![j isKindOfClass:[NSDictionary class]]) return nil;
        total = [j[@"total"] integerValue];
        NSArray *raw = j[@"data"];
        if (![raw isKindOfClass:[NSArray class]] || !raw.count) break;
        [all addObjectsFromArray:[MDChapter listFromJson:raw]];
        offset += raw.count;
    } while (offset < total);
    return all;
}

// /at-home/server/{id} → baseUrl + chapter.hash + chapter.data | dataSaver
+ (NSArray *)pagesOfChapter:(NSString *)ident saver:(BOOL)saver error:(NSError **)e {
    return [self pagesOfChapter:ident saver:saver useCache:YES error:e];
}
+ (NSArray *)pagesOfChapter:(NSString *)ident saver:(BOOL)saver useCache:(BOOL)cache error:(NSError **)e {
    NSDictionary *j = [self request:[NSString stringWithFormat:@"/at-home/server/%@", ident] ttl:(cache ? 180 : 0) error:e];
    if (![j isKindOfClass:[NSDictionary class]]) return nil;
    NSString *base = j[@"baseUrl"]; NSDictionary *ch = j[@"chapter"];
    NSString *hash = [ch isKindOfClass:[NSDictionary class]] ? ch[@"hash"] : nil;
    NSArray *data = ch[@"data"], *saverArr = ch[@"dataSaver"];
    NSArray *files; NSString *folder;
    if (saver && [saverArr count])      { files = saverArr; folder = @"data-saver"; }   // fall back like the original
    else if ([data count])              { files = data;     folder = @"data"; }
    else if ([saverArr count])          { files = saverArr; folder = @"data-saver"; }
    if (![base length] || ![hash length] || !files.count) {
        if (e) *e = [self errorWithText:@"Нет страниц" code:-4];
        return nil;
    }
    NSMutableArray *urls = [NSMutableArray array];
    for (id f in files) if ([f isKindOfClass:[NSString class]])
        [urls addObject:[NSString stringWithFormat:@"%@/%@/%@/%@", base, folder, hash, f]];
    return urls;
}
@end
