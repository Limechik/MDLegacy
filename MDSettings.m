#import "MDSettings.h"
@implementation MDSettings

+ (NSUserDefaults *)d { return [NSUserDefaults standardUserDefaults]; }

+ (NSArray *)languageCodes {
    return @[@"en", @"ru", @"uk", @"ja", @"zh", @"ko", @"es", @"es-la", @"pt-br", @"fr", @"de", @"it", @"pl"];
}
+ (NSString *)nameForLanguage:(NSString *)c {
    NSDictionary *n = @{@"en":@"Английский", @"ru":@"Русский", @"uk":@"Украинский", @"ja":@"Японский",
        @"zh":@"Китайский", @"ko":@"Корейский", @"es":@"Испанский", @"es-la":@"Испанский (Лат. Ам.)",
        @"pt-br":@"Португальский (Бр.)", @"fr":@"Французский", @"de":@"Немецкий", @"it":@"Итальянский", @"pl":@"Польский"};
    return n[c] ?: c;
}
+ (NSString *)language {
    NSString *l = [[self d] stringForKey:@"MDLanguage"];
    if (l) return l;
    NSArray *pl = [NSLocale preferredLanguages];                        // "ru", "en", "pt-BR"…
    NSString *sys = pl.count ? pl[0] : @"en";
    sys = [[sys lowercaseString] componentsSeparatedByString:@"_"][0];
    return [[self languageCodes] containsObject:sys] ? sys : @"en";
}
+ (void)setLanguage:(NSString *)l { [[self d] setObject:l forKey:@"MDLanguage"]; [[self d] synchronize]; }

+ (BOOL)dataSaver    { return [[self d] boolForKey:@"MDDataSaver"]; }
+ (void)setDataSaver:(BOOL)v { [[self d] setBool:v forKey:@"MDDataSaver"]; [[self d] synchronize]; }
+ (BOOL)showAdult    { return [[self d] boolForKey:@"MDShowAdult"]; }
+ (void)setShowAdult:(BOOL)v { [[self d] setBool:v forKey:@"MDShowAdult"]; [[self d] synchronize]; }

+ (NSInteger)nightMode { return [[self d] integerForKey:@"MDNightMode"]; }
+ (void)setNightMode:(NSInteger)v { [[self d] setInteger:v forKey:@"MDNightMode"]; [[self d] synchronize]; }
+ (float)nightIntensity {
    id o = [[self d] objectForKey:@"MDNightIntensity"];
    float v = o ? [o floatValue] : 0.2f;
    return MAX(0.05f, MIN(0.40f, v));
}
+ (void)setNightIntensity:(float)v { [[self d] setFloat:MAX(0.05f, MIN(0.40f, v)) forKey:@"MDNightIntensity"]; [[self d] synchronize]; }
+ (NSInteger)nightStart { id o = [[self d] objectForKey:@"MDNightStart"]; return o ? [o integerValue] : 21 * 60; }
+ (void)setNightStart:(NSInteger)m { [[self d] setInteger:m forKey:@"MDNightStart"]; [[self d] synchronize]; }
+ (NSInteger)nightEnd { id o = [[self d] objectForKey:@"MDNightEnd"]; return o ? [o integerValue] : 7 * 60; }
+ (void)setNightEnd:(NSInteger)m { [[self d] setInteger:m forKey:@"MDNightEnd"]; [[self d] synchronize]; }

+ (NSArray *)contentRatings {
    return [self showAdult] ? @[@"safe", @"suggestive", @"erotica", @"pornographic"] : @[@"safe", @"suggestive"];
}
@end
