#import <Foundation/Foundation.h>
#import "MDModels.h"

@interface MDApi : NSObject
+ (NSInteger)pageSize;   // 24, as in the original client
// All calls block — use a background queue.
+ (NSArray *)popularWithOffset:(NSInteger)o total:(NSInteger *)t error:(NSError **)e;
+ (NSArray *)latestWithOffset:(NSInteger)o total:(NSInteger *)t error:(NSError **)e;
+ (NSArray *)searchTitle:(NSString *)q offset:(NSInteger)o total:(NSInteger *)t error:(NSError **)e;
+ (MDManga *)manga:(NSString *)ident error:(NSError **)e;
+ (NSArray *)chaptersOfManga:(NSString *)ident language:(NSString *)lang error:(NSError **)e;
+ (NSArray *)pagesOfChapter:(NSString *)ident saver:(BOOL)saver error:(NSError **)e;
+ (NSArray *)pagesOfChapter:(NSString *)ident saver:(BOOL)saver useCache:(BOOL)cache error:(NSError **)e;   // → [NSString url]
@end
