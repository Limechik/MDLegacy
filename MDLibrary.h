#import <Foundation/Foundation.h>
#import "MDModels.h"

// Persisted in Documents/library.plist: favorites, history, progress
@interface MDLibrary : NSObject
+ (NSArray *)favorites;                              // [{mangaId,title,coverFile,added}]
+ (BOOL)isFavorite:(NSString *)mangaId;
+ (void)addFavorite:(MDManga *)m;
+ (void)removeFavorite:(NSString *)mangaId;

+ (void)recordManga:(MDManga *)m chapter:(MDChapter *)c page:(NSInteger)page total:(NSInteger)total;
+ (NSArray *)history;                                // newest first [{mangaId,title,coverFile,chapterId,chapterName,page,time}]
+ (NSDictionary *)lastReadOfManga:(NSString *)mangaId;
+ (void)clearHistory;

+ (NSInteger)pageOfChapter:(NSString *)chapterId;    // 0-based, 0 when unknown/finished
+ (BOOL)isChapterFinished:(NSString *)chapterId;
@end
