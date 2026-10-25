#import "MDSettingsViewController.h"
#import "MDTimePickerViewController.h"
#import "MDSettings.h"
#import "MDImageLoader.h"
#import "MDLibrary.h"
#import "MDDownloads.h"
#import "MDNightMode.h"
#import "MDTheme.h"
#import "MDUtil.h"

// sections: 0 Чтение · 1 Контент · 2 Данные · 3 Ночной режим (rows depend on mode)
enum { kSheetLanguage = 1, kSheetNight = 3 };
enum { kNightMode = 0, kNightIntensity = 1, kNightStart = 2, kNightEnd = 3 };

@implementation MDSettingsViewController

- (id)init { self = [super initWithStyle:UITableViewStyleGrouped]; self.title = @"Настройки"; return self; }
- (void)viewDidLoad { [super viewDidLoad]; [MDTheme styleTable:self.tableView]; }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self.tableView reloadData]; }

- (NSArray *)nightRows {
    switch ([MDSettings nightMode]) {
        case 1:  return @[@(kNightMode), @(kNightIntensity)];
        case 2:  return @[@(kNightMode), @(kNightIntensity), @(kNightStart), @(kNightEnd)];
        default: return @[@(kNightMode)];
    }
}
- (NSString *)timeString:(NSInteger)m { return [NSString stringWithFormat:@"%02ld:%02ld", (long)(m / 60), (long)(m % 60)]; }
- (NSArray *)nightModeNames { return @[@"Выкл", @"Всегда", @"По времени"]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 4; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return s == 0 ? 1 : s == 1 ? 2 : s == 2 ? 4 : (NSInteger)[self nightRows].count;
}

- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s {
    return [MDTheme sectionHeader:@[@"Чтение", @"Контент", @"Данные", @"Ночной режим"][s]];
}
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return 34; }
- (UIView *)tableView:(UITableView *)t viewForFooterInSection:(NSInteger)s {
    NSString *text = s == 1 ? @"Контент 18+ включает категории erotica и pornographic"
                   : s == 3 ? @"Тёплый оттенок включается только пока открыта глава в ридере" : nil;
    if (!text) return nil;
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 4, 280, 30)]; l.numberOfLines = 0;
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth; l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont systemFontOfSize:13]; l.textColor = [MDTheme secondaryText]; l.text = text;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 40)]; [v addSubview:l]; return v;
}
- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s { return (s == 1 || s == 3) ? 40 : 8; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    NSInteger s = ip.section, r = ip.row;

    if (s == 3) {
        switch ([[self nightRows][r] integerValue]) {
            case kNightMode:
                c.textLabel.text = @"Режим"; c.detailTextLabel.text = [self nightModeNames][[MDSettings nightMode]];
                c.selectionStyle = UITableViewCellSelectionStyleBlue; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; break;
            case kNightIntensity: {
                c.textLabel.text = @"Интенсивность";
                UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 150, 30)];
                sl.minimumValue = 0.05; sl.maximumValue = 0.40; sl.value = [MDSettings nightIntensity];
                sl.minimumTrackTintColor = [MDTheme accent];
                [sl addTarget:self action:@selector(intensityChanged:) forControlEvents:UIControlEventValueChanged];
                [sl addTarget:self action:@selector(intensityDown:) forControlEvents:UIControlEventTouchDown];
                [sl addTarget:self action:@selector(intensityUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
                c.accessoryView = sl; break; }
            case kNightStart:
                c.textLabel.text = @"С"; c.detailTextLabel.text = [self timeString:[MDSettings nightStart]];
                c.selectionStyle = UITableViewCellSelectionStyleBlue; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; break;
            case kNightEnd:
                c.textLabel.text = @"До"; c.detailTextLabel.text = [self timeString:[MDSettings nightEnd]];
                c.selectionStyle = UITableViewCellSelectionStyleBlue; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; break;
        }
        return c;
    }
    if (s == 0 || (s == 1 && r == 0)) {
        NSArray *names = @[@"Экономия трафика", @"Показывать 18+"];
        NSInteger k = s == 0 ? 0 : 1;
        BOOL on = k == 0 ? [MDSettings dataSaver] : [MDSettings showAdult];
        c.textLabel.text = names[k];
        UISwitch *sw = [UISwitch new]; sw.on = on; sw.tag = k; sw.onTintColor = [MDTheme accent];
        [sw addTarget:self action:@selector(switched:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
    } else if (s == 1) {
        c.textLabel.text = @"Язык глав"; c.detailTextLabel.text = [MDSettings nameForLanguage:[MDSettings language]];
        c.selectionStyle = UITableViewCellSelectionStyleBlue; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        c.selectionStyle = UITableViewCellSelectionStyleBlue;
        if (r == 0)      { c.textLabel.text = @"Очистить кэш картинок"; c.detailTextLabel.text = [MDUtil humanSize:[MDImageLoader diskUsage]]; }
        else if (r == 1) { c.textLabel.text = @"Очистить историю"; }
        else if (r == 2) { c.textLabel.text = @"Удалить все загрузки"; c.detailTextLabel.text = [MDUtil humanSize:[MDDownloads totalSize]]; }
        else             { c.textLabel.text = @"Ошибка картинок"; c.detailTextLabel.text = [MDImageLoader lastError] ? @"есть" : @"нет"; }
    }
    return c;
}
- (void)tableView:(UITableView *)t willDisplayCell:(UITableViewCell *)c forRowAtIndexPath:(NSIndexPath *)ip { [MDTheme styleCell:c]; }

#pragma mark - Controls
- (void)switched:(UISwitch *)sw {
    switch (sw.tag) {
        case 0: [MDSettings setDataSaver:sw.on]; break;
        case 1: [MDSettings setShowAdult:sw.on]; break;
    }
}
- (void)intensityChanged:(UISlider *)sl { [MDSettings setNightIntensity:sl.value]; [MDNightMode setPreview:YES]; }
- (void)intensityDown:(UISlider *)sl { [MDNightMode setPreview:YES]; }
- (void)intensityUp:(UISlider *)sl { [MDNightMode setPreview:NO]; }

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 3) {
        switch ([[self nightRows][ip.row] integerValue]) {
            case kNightMode: {
                UIActionSheet *a = [[UIActionSheet alloc] initWithTitle:@"Ночной режим (только в ридере)" delegate:self cancelButtonTitle:nil
                                                 destructiveButtonTitle:nil otherButtonTitles:nil];
                a.actionSheetStyle = UIActionSheetStyleBlackOpaque; a.tag = kSheetNight;
                for (NSString *n in [self nightModeNames]) [a addButtonWithTitle:n];
                a.cancelButtonIndex = [a addButtonWithTitle:@"Отмена"];
                [a showInView:self.view.window]; break; }
            case kNightStart: {
                MDTimePickerViewController *p = [[MDTimePickerViewController alloc] initWithTitle:@"Начало" minutes:[MDSettings nightStart]
                    onChange:^(NSInteger m) { [MDSettings setNightStart:m]; }];
                [self.navigationController pushViewController:p animated:YES]; break; }
            case kNightEnd: {
                MDTimePickerViewController *p = [[MDTimePickerViewController alloc] initWithTitle:@"Конец" minutes:[MDSettings nightEnd]
                    onChange:^(NSInteger m) { [MDSettings setNightEnd:m]; }];
                [self.navigationController pushViewController:p animated:YES]; break; }
        }
        return;
    }
    if (ip.section == 1 && ip.row == 1) {
        UIActionSheet *a = [[UIActionSheet alloc] initWithTitle:@"Язык глав по умолчанию" delegate:self cancelButtonTitle:nil
                                         destructiveButtonTitle:nil otherButtonTitles:nil];
        a.actionSheetStyle = UIActionSheetStyleBlackOpaque; a.tag = kSheetLanguage;
        for (NSString *c in [MDSettings languageCodes]) [a addButtonWithTitle:[MDSettings nameForLanguage:c]];
        a.cancelButtonIndex = [a addButtonWithTitle:@"Отмена"];
        [a showInView:self.view.window];
    } else if (ip.section == 2 && ip.row == 0) {
        [MDImageLoader clearDisk]; [MDImageLoader trimMemory]; [t reloadData];
    } else if (ip.section == 2 && ip.row == 1) {
        [MDLibrary clearHistory];
    } else if (ip.section == 2 && ip.row == 2) {
        UIAlertView *al = [[UIAlertView alloc] initWithTitle:@"Удалить все загрузки?" message:@"Загруженные главы будут удалены с устройства."
                                                    delegate:self cancelButtonTitle:@"Отмена" otherButtonTitles:@"Удалить", nil];
        al.tag = 2; [al show];
    } else if (ip.section == 2 && ip.row == 3) {
        [MDUtil showMessage:[MDImageLoader lastError] ?: @"Ошибок не было" title:@"Последняя ошибка картинки"]; [t reloadData];
    }
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    if (a.tag == 2 && i != a.cancelButtonIndex) { [MDDownloads deleteAll]; [self.tableView reloadData]; }
}
- (void)actionSheet:(UIActionSheet *)a clickedButtonAtIndex:(NSInteger)i {
    if (i == a.cancelButtonIndex) return;
    if (a.tag == kSheetNight) {
        if (i < 3) { [MDSettings setNightMode:i]; [self.tableView reloadData]; }      // rows appear/disappear with the mode
        return;
    }
    NSArray *codes = [MDSettings languageCodes];
    if (i >= (NSInteger)codes.count) return;
    [MDSettings setLanguage:codes[i]]; [self.tableView reloadData];
}
@end
