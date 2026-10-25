#import <UIKit/UIKit.h>
@interface MDTimePickerViewController : UIViewController
- (id)initWithTitle:(NSString *)title minutes:(NSInteger)minutes onChange:(void (^)(NSInteger minutes))cb;
@end
