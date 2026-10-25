#import <Foundation/Foundation.h>
@interface MDSettings : NSObject
+ (NSString *)language;            + (void)setLanguage:(NSString *)l;
+ (NSArray *)languageCodes;        + (NSString *)nameForLanguage:(NSString *)code;
+ (BOOL)dataSaver;                 + (void)setDataSaver:(BOOL)v;
+ (BOOL)showAdult;                 + (void)setShowAdult:(BOOL)v;
// Night mode (warm tint, active only inside the reader): 0 off, 1 always, 2 schedule
+ (NSInteger)nightMode;            + (void)setNightMode:(NSInteger)v;
+ (float)nightIntensity;           + (void)setNightIntensity:(float)v;      // 0.05 … 0.40
+ (NSInteger)nightStart;           + (void)setNightStart:(NSInteger)m;      // minutes since midnight, default 21:00
+ (NSInteger)nightEnd;             + (void)setNightEnd:(NSInteger)m;        // default 07:00
+ (NSArray *)contentRatings;       // safe, suggestive [, erotica, pornographic]
@end
