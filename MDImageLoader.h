#import <UIKit/UIKit.h>
@interface MDImageLoader : NSObject
// Memory cache → disk cache → network. Completion on main thread (nil on failure).
+ (void)loadURL:(NSString *)url maxPixel:(CGFloat)px completion:(void (^)(UIImage *img))cb;
+ (void)trimMemory;
+ (NSString *)lastError;     // last failure reason (for the settings screen)
+ (unsigned long long)diskUsage;
+ (void)clearDisk;
+ (void)pruneDisk;       // keep ≤ ~100 MB, oldest first
@end
