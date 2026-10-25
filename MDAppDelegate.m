#import "MDAppDelegate.h"
#import "MDCatalogViewController.h"
#import "MDLibraryViewController.h"
#import "MDSettingsViewController.h"
#import "MDImageLoader.h"
#import "MDHttp.h"
#import "MDTheme.h"

@implementation MDAppDelegate

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    [MDTheme apply];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [MDTheme background];

    UINavigationController *cat = [[UINavigationController alloc] initWithRootViewController:[MDCatalogViewController new]];
    UINavigationController *lib = [[UINavigationController alloc] initWithRootViewController:[MDLibraryViewController new]];
    UINavigationController *set = [[UINavigationController alloc] initWithRootViewController:[MDSettingsViewController new]];
    cat.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Каталог" image:[UIImage imageNamed:@"tab_catalog"] tag:0];
    lib.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Библиотека" image:[UIImage imageNamed:@"tab_library"] tag:1];
    set.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Настройки" image:[UIImage imageNamed:@"tab_settings"] tag:2];

    UITabBarController *tabs = [UITabBarController new];
    tabs.viewControllers = @[cat, lib, set];
    self.window.rootViewController = tabs;
    [self.window makeKeyAndVisible];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{ [MDImageLoader pruneDisk]; });
    return YES;
}
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)app {
    [MDImageLoader trimMemory]; [MDHttp dropMemoryCache];
}
@end
