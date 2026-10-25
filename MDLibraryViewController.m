#import "MDLibraryViewController.h"
#import "MDMangaViewController.h"
#import "MDMangaCell.h"
#import "MDLibrary.h"
#import "MDDownloads.h"
#import "MDTheme.h"
#import "MDUtil.h"

@implementation MDLibraryViewController {
    UISegmentedControl *_seg; NSArray *_rows;
}
- (id)init { self = [super initWithStyle:UITableViewStylePlain]; self.title = @"Библиотека"; return self; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    [MDTheme styleTable:self.tableView];
    _seg = [[UISegmentedControl alloc] initWithItems:@[@"Избранное", @"История", @"Загрузки"]];
    _seg.segmentedControlStyle = UISegmentedControlStyleBar; _seg.selectedSegmentIndex = 0;
    _seg.frame = CGRectMake(0, 0, 250, 30);
    [_seg addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = _seg;
    self.tableView.rowHeight = 96;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadsChanged) name:MDDownloadsChangedNotification object:nil];
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self refresh]; }
- (void)downloadsChanged { if (_seg.selectedSegmentIndex == 2) [self refresh]; }

- (void)refresh {
    NSInteger mode = _seg.selectedSegmentIndex;
    _rows = mode == 1 ? [MDLibrary history] : mode == 2 ? [MDDownloads downloadedMangas] : [MDLibrary favorites];
    self.navigationItem.rightBarButtonItem = mode == 1 && _rows.count
        ? [[UIBarButtonItem alloc] initWithTitle:@"Очистить" style:UIBarButtonItemStyleBordered target:self action:@selector(clearHistory)] : nil;
    [self.tableView reloadData];
}
- (void)clearHistory { [MDLibrary clearHistory]; [self refresh]; }

- (MDManga *)mangaForRow:(NSDictionary *)d {
    MDManga *m = [MDManga new]; m.identifier = d[@"mangaId"]; m.title = d[@"title"]; m.coverFile = d[@"coverFile"];
    if ([d[@"author"] length]) m.author = d[@"author"];
    m.localCover = [MDDownloads coverPathForManga:m.identifier];            // works without network
    return m;
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return _rows.count; }
- (UIView *)tableView:(UITableView *)t viewForFooterInSection:(NSInteger)s {
    if (_rows.count) return nil;
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 60)];
    l.textAlignment = NSTextAlignmentCenter; l.textColor = [MDTheme secondaryText]; l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont systemFontOfSize:14]; l.numberOfLines = 0;
    l.text = _seg.selectedSegmentIndex == 2 ? @"Нет загрузок.\nЗажмите главу или откройте Меню в манге." : @"Пока пусто";
    return l;
}
- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s { return _rows.count ? 0 : 80; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    MDMangaCell *c = [t dequeueReusableCellWithIdentifier:@"m"] ?: [[MDMangaCell alloc] initWithStyle:0 reuseIdentifier:@"m"];
    NSDictionary *d = _rows[ip.row]; MDManga *m = [self mangaForRow:d]; NSString *sub;
    NSInteger mode = _seg.selectedSegmentIndex;
    if (mode == 1)
        sub = [NSString stringWithFormat:@"%@ · стр. %ld · %@", d[@"chapterName"], (long)[d[@"page"] integerValue] + 1, [MDUtil ago:d[@"time"]]];
    else if (mode == 2) {
        sub = [NSString stringWithFormat:@"Глав офлайн: %@ · %@", d[@"count"], [MDUtil humanSize:[d[@"bytes"] unsignedLongLongValue]]];
        NSInteger pend = [MDDownloads pendingCountForManga:m.identifier];
        if (pend) sub = [sub stringByAppendingFormat:@"\nЗагружается: %ld", (long)pend];
    } else {
        NSDictionary *last = [MDLibrary lastReadOfManga:m.identifier];
        sub = last ? [NSString stringWithFormat:@"Продолжить: %@", last[@"chapterName"]] : @"Не читалось";
    }
    [c setManga:m subtitle:sub];
    return c;
}
- (void)tableView:(UITableView *)t willDisplayCell:(UITableViewCell *)c forRowAtIndexPath:(NSIndexPath *)ip { [MDTheme styleCell:c]; }

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    [self.navigationController pushViewController:[[MDMangaViewController alloc] initWithManga:[self mangaForRow:_rows[ip.row]]] animated:YES];
}
- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)ip { return _seg.selectedSegmentIndex != 1; }
- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)st forRowAtIndexPath:(NSIndexPath *)ip {
    NSString *mid = _rows[ip.row][@"mangaId"];
    if (_seg.selectedSegmentIndex == 2) [MDDownloads deleteManga:mid]; else [MDLibrary removeFavorite:mid];
    [self refresh];
}
@end
