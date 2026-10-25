#import <UIKit/UIKit.h>
// Warm tint overlay (separate transparent window above everything, touches pass through).
// Only shown while the reader is on screen: reader calls +start / +stop.
@interface MDNightMode : NSObject
+ (void)start;
+ (void)stop;
+ (void)setPreview:(BOOL)on;       // settings screen: show while dragging the intensity slider
@end
