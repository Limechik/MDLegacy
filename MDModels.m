#import "MDModels.h"
#import "MDSettings.h"
#import "MDUtil.h"

static NSString *MDStr(id o) { return ([o isKindOfClass:[NSString class]] && [o length]) ? o : nil; }
static NSDictionary *MDDict(id o) { return [o isKindOfClass:[NSDictionary class]] ? o : nil; }
static NSArray *MDArr(id o) { return [o isKindOfClass:[NSArray class]] ? o : nil; }

// {"en":"..","ja-ro":".."} → preferred language, then en, ja-ro, ja, then anything
static NSString *MDPick(NSDictionary *d, NSString *pref) {
    d = MDDict(d); if (!d) return nil;
    for (NSString *k in @[pref ?: @"en", @"en", @"ja-ro", @"ja"]) { NSString *s = MDStr(d[k]); if (s) return s; }
    for (id v in d.allValues) { NSString *s = MDStr(v); if (s) return s; }
    return nil;
}

@implementation MDManga
+ (MDManga *)fromJson:(NSDictionary *)j {
    j = MDDict(j); NSString *ident = MDStr(j[@"id"]); if (!ident) return nil;
    NSDictionary *a = MDDict(j[@"attributes"]);
    NSString *lang = [MDSettings language];
    MDManga *m = [MDManga new];
    m.identifier = ident;
    m.title = MDPick(a[@"title"], lang);
    if (!m.title) for (id alt in MDArr(a[@"altTitles"])) { m.title = MDPick(alt, lang); if (m.title) break; }
    m.title = m.title ?: @"(без названия)";
    m.summary = MDPick(a[@"description"], lang);
    m.status = MDStr(a[@"status"]);
    m.contentRating = MDStr(a[@"contentRating"]);
    m.year = [a[@"year"] respondsToSelector:@selector(integerValue)] ? [a[@"year"] integerValue] : 0;
    m.languages = MDArr(a[@"availableTranslatedLanguages"]);
    NSMutableArray *tags = [NSMutableArray array];
    for (NSDictionary *t in MDArr(a[@"tags"])) { NSString *n = MDPick(MDDict(t[@"attributes"])[@"name"], @"en"); if (n) [tags addObject:n]; }
    m.tags = tags;
    for (NSDictionary *rel in MDArr(j[@"relationships"])) {
        NSString *type = MDStr(rel[@"type"]); NSDictionary *ra = MDDict(rel[@"attributes"]);
        if ([type isEqualToString:@"cover_art"]) m.coverFile = MDStr(ra[@"fileName"]) ?: m.coverFile;
        else if ([type isEqualToString:@"author"] && !m.author) m.author = MDStr(ra[@"name"]);
    }
    return m;
}
+ (NSArray *)listFromJson:(NSArray *)arr {
    NSMutableArray *out = [NSMutableArray array];
    for (id o in MDArr(arr)) { MDManga *m = [self fromJson:o]; if (m) [out addObject:m]; }
    return out;
}
- (NSString *)coverUrlForPixelWidth:(CGFloat)w {
    if (self.localCover.length && [[NSFileManager defaultManager] fileExistsAtPath:self.localCover]) return self.localCover;   // offline copy
    if (!self.identifier.length || !self.coverFile.length) return nil;
    return [NSString stringWithFormat:@"https://uploads.mangadex.org/covers/%@/%@%@",
            self.identifier, self.coverFile, w > 256 ? @".512.jpg" : @".256.jpg"];
}
- (NSString *)statusName {
    NSDictionary *n = @{@"ongoing":@"Выходит", @"completed":@"Завершено", @"hiatus":@"Пауза", @"cancelled":@"Отменено"};
    return n[self.status] ?: @"";
}
@end

@implementation MDChapter
+ (MDChapter *)fromJson:(NSDictionary *)j {
    j = MDDict(j); NSString *ident = MDStr(j[@"id"]); if (!ident) return nil;
    NSDictionary *a = MDDict(j[@"attributes"]);
    MDChapter *c = [MDChapter new];
    c.identifier = ident;
    c.number = MDStr(a[@"chapter"]); c.volume = MDStr(a[@"volume"]); c.title = MDStr(a[@"title"]);
    c.language = MDStr(a[@"translatedLanguage"]);
    c.published = [MDUtil parseTime:MDStr(a[@"publishAt"])];
    c.pages = [a[@"pages"] respondsToSelector:@selector(integerValue)] ? [a[@"pages"] integerValue] : 0;
    c.external = MDStr(a[@"externalUrl"]) != nil;
    for (NSDictionary *rel in MDArr(j[@"relationships"]))
        if ([MDStr(rel[@"type"]) isEqualToString:@"scanlation_group"]) c.group = MDStr(MDDict(rel[@"attributes"])[@"name"]);
    return c;
}
+ (NSArray *)listFromJson:(NSArray *)arr {
    NSMutableArray *out = [NSMutableArray array];
    for (id o in MDArr(arr)) { MDChapter *c = [self fromJson:o]; if (c && !c.external) [out addObject:c]; }
    return out;
}
- (NSString *)displayName {
    NSMutableString *s = [NSMutableString string];
    if (self.volume) [s appendFormat:@"Том %@ ", self.volume];
    [s appendString:self.number ? [NSString stringWithFormat:@"Глава %@", self.number] : @"Ваншот"];
    if (self.title) [s appendFormat:@" — %@", self.title];
    return s;
}
- (NSString *)subtitle {
    NSMutableArray *p = [NSMutableArray array];
    if (self.group) [p addObject:self.group];
    if (self.published) [p addObject:[MDUtil ago:self.published]];
    return [p componentsJoinedByString:@" · "];
}
@end
