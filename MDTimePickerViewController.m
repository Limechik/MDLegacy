#import "MDTimePickerViewController.h"
#import "MDTheme.h"

@implementation MDTimePickerViewController {
    NSInteger _minutes; void (^_cb)(NSInteger); UIDatePicker *_picker;
}
- (id)initWithTitle:(NSString *)t minutes:(NSInteger)m onChange:(void (^)(NSInteger))cb {
    self = [super initWithNibName:nil bundle:nil];
    self.title = t; _minutes = m; _cb = [cb copy];
    return self;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return YES; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [MDTheme background];
    _picker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 30, self.view.bounds.size.width, 216)];
    _picker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _picker.datePickerMode = UIDatePickerModeTime;
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *c = [cal components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:[NSDate date]];
    c.hour = _minutes / 60; c.minute = _minutes % 60;
    _picker.date = [cal dateFromComponents:c];
    [_picker addTarget:self action:@selector(changed) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_picker];
}
- (void)changed {
    NSDateComponents *c = [[NSCalendar currentCalendar] components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:_picker.date];
    _minutes = c.hour * 60 + c.minute;
    if (_cb) _cb(_minutes);
}
@end
