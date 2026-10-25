#import <Foundation/Foundation.h>

@interface MDManga : NSObject
@property (nonatomic, copy) NSString *identifier, *title, *summary, *author, *coverFile, *status, *contentRating, *localCover;
@property (nonatomic) NSInteger year;
@property (nonatomic, strong) NSArray *tags, *languages;
+ (MDManga *)fromJson:(NSDictionary *)j;
+ (NSArray *)listFromJson:(NSArray *)arr;
- (NSString *)coverUrlForPixelWidth:(CGFloat)w;
- (NSString *)statusName;
@end

@interface MDChapter : NSObject
@property (nonatomic, copy) NSString *identifier, *number, *volume, *title, *language, *group;
@property (nonatomic, strong) NSDate *published;
@property (nonatomic) NSInteger pages;
@property (nonatomic) BOOL external;
+ (MDChapter *)fromJson:(NSDictionary *)j;
+ (NSArray *)listFromJson:(NSArray *)arr;           // skips external-only chapters
- (NSString *)displayName;
- (NSString *)subtitle;
@end
