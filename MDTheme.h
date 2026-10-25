#import <UIKit/UIKit.h>
@interface MDTheme : NSObject
+ (void)apply;                                   // UIAppearance, call before creating any UI
+ (UIColor *)background; + (UIColor *)surface; + (UIColor *)text;
+ (UIColor *)secondaryText; + (UIColor *)separator; + (UIColor *)accent;
+ (UIBarStyle)barStyle;
+ (void)styleTable:(UITableView *)t;
+ (void)styleCell:(UITableViewCell *)c;          // call from willDisplayCell:
+ (UIView *)sectionHeader:(NSString *)title;
@end
