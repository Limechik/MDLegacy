#import "MDNightMode.h"
#import "MDSettings.h"

@implementation MDNightMode
static UIWindow *gWin; static NSTimer *gTimer; static BOOL gSession, gPreview;

+ (BOOL)scheduleActive {
    NSDateComponents *c = [[NSCalendar currentCalendar] components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:[NSDate date]];
    NSInteger now = c.hour * 60 + c.minute, s = [MDSettings nightStart], e = [MDSettings nightEnd];
    if (s == e) return NO;
    return s < e ? (now >= s && now < e) : (now >= s || now < e);     // window may cross midnight (21:00 → 07:00)
}
+ (BOOL)shouldBeOn {
    if (gPreview) return YES;
    if (!gSession) return NO;
    switch ([MDSettings nightMode]) {
        case 1: return YES;
        case 2: return [self scheduleActive];
        default: return NO;
    }
}
+ (void)update {
    if ([self shouldBeOn]) {
        if (!gWin) {
            gWin = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
            gWin.windowLevel = UIWindowLevelAlert + 100; gWin.userInteractionEnabled = NO; gWin.opaque = NO;
        }
        gWin.backgroundColor = [UIColor colorWithRed:1.0 green:0.58 blue:0.2 alpha:[MDSettings nightIntensity]];
        gWin.hidden = NO;
    } else {
        gWin.hidden = YES;
    }
}
+ (void)start {
    gSession = YES;
    [gTimer invalidate];
    gTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(update) userInfo:nil repeats:YES];   // schedule edge
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self update];
}
+ (void)stop {
    gSession = NO; [gTimer invalidate]; gTimer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self update];
}
+ (void)setPreview:(BOOL)on { gPreview = on; [self update]; }
@end
