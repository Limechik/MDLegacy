#import "MDTheme.h"

@implementation MDTheme
+ (UIColor *)background    { return [UIColor colorWithWhite:0.07 alpha:1]; }
+ (UIColor *)surface       { return [UIColor colorWithWhite:0.12 alpha:1]; }
+ (UIColor *)text          { return [UIColor colorWithWhite:0.94 alpha:1]; }
+ (UIColor *)secondaryText { return [UIColor colorWithWhite:0.62 alpha:1]; }
+ (UIColor *)separator     { return [UIColor colorWithWhite:0.22 alpha:1]; }
+ (UIColor *)accent        { return [UIColor colorWithRed:0.30 green:0.60 blue:1.0 alpha:1]; }
+ (UIBarStyle)barStyle     { return UIBarStyleBlackOpaque; }

+ (void)apply {
    UIColor *bar = [UIColor colorWithWhite:0.13 alpha:1], *clear = [UIColor clearColor];
    [[UINavigationBar appearance] setTintColor:bar];
    [[UINavigationBar appearance] setTitleTextAttributes:@{UITextAttributeTextColor: [UIColor whiteColor],
                                                           UITextAttributeTextShadowColor: clear}];
    [[UIBarButtonItem appearance] setTintColor:[UIColor colorWithWhite:0.30 alpha:1]];
    [[UISearchBar appearance] setTintColor:bar];
    [[UISegmentedControl appearance] setTintColor:[UIColor colorWithWhite:0.32 alpha:1]];
    [[UITabBar appearance] setTintColor:bar];
    [[UITabBar appearance] setSelectedImageTintColor:[self accent]];
    [[UITabBarItem appearance] setTitleTextAttributes:@{UITextAttributeTextColor: [UIColor colorWithWhite:0.62 alpha:1],
                                                        UITextAttributeTextShadowColor: clear} forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:@{UITextAttributeTextColor: [self accent],
                                                        UITextAttributeTextShadowColor: clear} forState:UIControlStateSelected];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque];
}

+ (void)styleTable:(UITableView *)t {
    t.backgroundView = nil; t.backgroundColor = [self background]; t.separatorColor = [self separator];
}
+ (void)styleCell:(UITableViewCell *)c {
    c.backgroundColor = [self surface];
    c.textLabel.textColor = [self text]; c.textLabel.backgroundColor = [UIColor clearColor];
    c.detailTextLabel.textColor = [self secondaryText]; c.detailTextLabel.backgroundColor = [UIColor clearColor];
    UIView *sel = [[UIView alloc] init]; sel.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1];
    c.selectedBackgroundView = sel;
}
+ (UIView *)sectionHeader:(NSString *)title {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 34)]; v.backgroundColor = [UIColor clearColor];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 8, 280, 22)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth; l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont boldSystemFontOfSize:14]; l.textColor = [self secondaryText]; l.text = title;
    [v addSubview:l]; return v;
}
@end
