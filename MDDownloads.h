#import <Foundation/Foundation.h>
#import "MDModels.h"

extern NSString *const MDDownloadsChangedNotification;   // posted on main thread (coalesced)

// Offline storage: Documents/Downloads/<mangaId>/<chapterId>/001.jpg …  + index in Documents/downloads.plist
@interface MDDownloads : NSObject
+ (void)enqueueChapters:(NSArray *)chapters manga:(MDManga *)m;
+ (void)cancelChapter:(NSString *)cid;
+ (BOOL)isDownloaded:(NSString *)cid;
+ (NSString *)statusForChapter:(NSString *)cid;          // nil | "в очереди" | "37%" | "ошибка загрузки" | "офлайн"
+ (NSArray *)localPagesForChapter:(NSString *)cid;       // absolute file paths, or nil
+ (void)deleteChapter:(NSString *)cid;
+ (void)deleteManga:(NSString *)mid;
+ (void)deleteAll;
+ (NSArray *)downloadedMangas;                           // [{mangaId,title,author,coverFile,count,bytes}]
+ (NSArray *)downloadedChaptersOfManga:(NSString *)mid;  // [MDChapter] ascending
+ (NSString *)coverPathForManga:(NSString *)mid;         // nil if none
+ (NSInteger)pendingCountForManga:(NSString *)mid;
+ (unsigned long long)totalSize;
@end
