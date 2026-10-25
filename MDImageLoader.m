#import "MDImageLoader.h"
#import "MDHttp.h"
#import "MDUtil.h"
#import <ImageIO/ImageIO.h>

@implementation MDImageLoader
static NSString *gLastError;
+ (NSString *)lastError { @synchronized (self) { return gLastError; } }
+ (void)setLastError:(NSString *)e { @synchronized (self) { gLastError = e; } }

+ (NSCache *)cache {
    static NSCache *c; static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [NSCache new]; c.totalCostLimit = 32 * 1024 * 1024; });
    return c;
}
+ (NSOperationQueue *)queue {
    static NSOperationQueue *q; static dispatch_once_t once;
    dispatch_once(&once, ^{ q = [NSOperationQueue new]; q.maxConcurrentOperationCount = 3; });
    return q;
}
+ (NSString *)folder {
    NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    NSString *dir = [caches stringByAppendingPathComponent:@"MDImages"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}
+ (NSString *)pathFor:(NSString *)url { return [[self folder] stringByAppendingPathComponent:[MDUtil md5:url]]; }

+ (UIImage *)decode:(NSData *)d maxPixel:(CGFloat)px {
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)d, NULL);
    if (!src) return nil;
    NSDictionary *o = @{(id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                        (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
                        (id)kCGImageSourceThumbnailMaxPixelSize: @(px)};
    CGImageRef cg = CGImageSourceCreateThumbnailAtIndex(src, 0, (__bridge CFDictionaryRef)o);
    CFRelease(src);
    if (!cg) return nil;
    UIImage *img = [UIImage imageWithCGImage:cg scale:1 orientation:UIImageOrientationUp];
    CGImageRelease(cg);
    return img;
}

+ (void)loadURL:(NSString *)url maxPixel:(CGFloat)px completion:(void (^)(UIImage *))cb {
    if (!url.length) { cb(nil); return; }
    NSString *key = [NSString stringWithFormat:@"%@|%d", url, (int)px];
    UIImage *hit = [[self cache] objectForKey:key];
    if (hit) { cb(hit); return; }
    [[self queue] addOperationWithBlock:^{
        @autoreleasepool {
            BOOL isFile = [url hasPrefix:@"/"];            // offline copy: absolute path, no network, never deleted
            NSString *path = isFile ? url : [self pathFor:url];
            NSData *d = [NSData dataWithContentsOfFile:path];
            if (!d && !isFile) {
                MDHttpResponse *r = [MDHttp get:url cacheForTTL:0];
                if (r.isSuccessful && !r.body.length) { [NSThread sleepForTimeInterval:0.6]; r = [MDHttp get:url cacheForTTL:0]; }   // empty 200: retry once
                if (r.isSuccessful && r.body.length) { d = r.body; [d writeToFile:path atomically:YES]; }
                else [self setLastError:[NSString stringWithFormat:@"%@: %@", [url lastPathComponent],
                        r.error ? r.error.localizedDescription : [NSString stringWithFormat:@"HTTP %ld, %lu байт, end=%ld, %@", (long)r.statusCode, (unsigned long)r.body.length, (long)r.endCode, r.headers]]];
            }
            UIImage *img = d ? [self decode:d maxPixel:px] : nil;
            if (!img && d) { [self setLastError:[NSString stringWithFormat:@"%@: не удалось декодировать (%lu байт)", [url lastPathComponent], (unsigned long)d.length]];
                if (!isFile) [[NSFileManager defaultManager] removeItemAtPath:path error:nil]; }   // corrupted download
            if (img) [[self cache] setObject:img forKey:key
                                      cost:(NSUInteger)(img.size.width * img.size.height * 4)];
            dispatch_async(dispatch_get_main_queue(), ^{ cb(img); });
        }
    }];
}

+ (void)trimMemory { [[self cache] removeAllObjects]; }

+ (unsigned long long)diskUsage {
    unsigned long long total = 0; NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *f in [fm contentsOfDirectoryAtPath:[self folder] error:nil])
        total += [[fm attributesOfItemAtPath:[[self folder] stringByAppendingPathComponent:f] error:nil] fileSize];
    return total;
}
+ (void)clearDisk {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *f in [fm contentsOfDirectoryAtPath:[self folder] error:nil])
        [fm removeItemAtPath:[[self folder] stringByAppendingPathComponent:f] error:nil];
}
+ (void)pruneDisk {
    const unsigned long long limit = 100ull * 1024 * 1024;
    NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *files = [NSMutableArray array];
    unsigned long long total = 0;
    for (NSString *f in [fm contentsOfDirectoryAtPath:[self folder] error:nil]) {
        NSString *p = [[self folder] stringByAppendingPathComponent:f];
        NSDictionary *a = [fm attributesOfItemAtPath:p error:nil];
        total += [a fileSize]; [files addObject:@{@"p": p, @"s": @([a fileSize]), @"d": [a fileModificationDate] ?: [NSDate distantPast]}];
    }
    if (total <= limit) return;
    [files sortUsingComparator:^NSComparisonResult(NSDictionary *x, NSDictionary *y) { return [x[@"d"] compare:y[@"d"]]; }];
    for (NSDictionary *f in files) {
        if (total <= limit * 3 / 4) break;
        [fm removeItemAtPath:f[@"p"] error:nil]; total -= [f[@"s"] unsignedLongLongValue];
    }
}
@end
