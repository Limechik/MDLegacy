#import "MDMangaViewController.h"
#import "MDReaderViewController.h"
#import "MDApi.h"
#import "MDLibrary.h"
#import "MDSettings.h"
#import "MDImageLoader.h"
#import "MDDownloads.h"
#import "MDTheme.h"
#import "MDUtil.h"

enum { kSheetLanguage = 1, kSheetManga = 2, kSheetChapter = 3 };

@implementation MDMangaViewController {
    MDManga *_manga; NSArray *_chapters;      // ascending
    NSString *_lang; NSArray *_langChoices;
    UIView *_header; UIImageView *_cover; UILabel *_titleL, *_metaL, *_sumL; UIButton *_readBtn;
    UIBarButtonItem *_favBtn; UILabel *_notice; BOOL _offline;
    NSArray *_sheetKeys; NSInteger _sheetChapter;
}

- (id)initWithManga:(MDManga *)m {
    self = [super initWithStyle:UITableViewStylePlain];
    _manga = m; self.title = m.title; _chapters = @[];
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (NSString *)pickLanguage {
    NSString *pref = [MDSettings language]; NSArray *av = _manga.languages;
    if (!av.count || [av containsObject:pref]) return pref;
    return [av containsObject:@"en"] ? @"en" : av[0];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [MDTheme styleTable:self.tableView];
    _header = [[UIView alloc] init];
    _cover = [[UIImageView alloc] init]; _cover.contentMode = UIViewContentModeScaleAspectFill; _cover.clipsToBounds = YES;
    _cover.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    _titleL = [[UILabel alloc] init]; _titleL.font = [UIFont boldSystemFontOfSize:18]; _titleL.numberOfLines = 0; _titleL.textColor = [MDTheme text];
    _metaL = [[UILabel alloc] init]; _metaL.font = [UIFont systemFontOfSize:13]; _metaL.textColor = [MDTheme secondaryText]; _metaL.numberOfLines = 0;
    _sumL = [[UILabel alloc] init]; _sumL.font = [UIFont systemFontOfSize:14]; _sumL.numberOfLines = 0; _sumL.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    for (UILabel *l in @[_titleL, _metaL, _sumL]) l.backgroundColor = [UIColor clearColor];
    _readBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_readBtn addTarget:self action:@selector(readTapped) forControlEvents:UIControlEventTouchUpInside];
    for (UIView *v in @[_cover, _titleL, _metaL, _readBtn, _sumL]) [_header addSubview:v];

    _favBtn = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStyleBordered target:self action:@selector(toggleFavorite)];
    UIBarButtonItem *menu = [[UIBarButtonItem alloc] initWithTitle:@"Меню" style:UIBarButtonItemStyleBordered target:self action:@selector(showMenu)];
    self.navigationItem.rightBarButtonItems = @[menu, _favBtn];

    _notice = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 60)];
    _notice.textAlignment = NSTextAlignmentCenter; _notice.textColor = [MDTheme secondaryText]; _notice.numberOfLines = 0;
    _notice.font = [UIFont systemFontOfSize:14]; _notice.backgroundColor = [UIColor clearColor];

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [self.tableView addGestureRecognizer:lp];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadsChanged) name:MDDownloadsChangedNotification object:nil];

    self.tableView.rowHeight = 56;
    [self fillHeader]; [self updateFavoriteButton];
    _lang = [self pickLanguage];
    [self loadDetails];
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self updateReadButton]; [self.tableView reloadData]; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; [self layoutHeader]; }

- (void)downloadsChanged {
    NSArray *vis = [self.tableView indexPathsForVisibleRows];
    if (vis.count) [self.tableView reloadRowsAtIndexPaths:vis withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Header
- (void)fillHeader {
    _titleL.text = _manga.title;
    NSMutableArray *p = [NSMutableArray array];
    if (_manga.author.length) [p addObject:_manga.author];
    if ([_manga statusName].length) [p addObject:[_manga statusName]];
    if (_manga.year) [p addObject:[NSString stringWithFormat:@"%ld", (long)_manga.year]];
    NSString *meta = [p componentsJoinedByString:@" · "];
    if (_manga.tags.count) meta = [meta stringByAppendingFormat:@"%@%@", meta.length ? @"\n" : @"", [_manga.tags componentsJoinedByString:@", "]];
    _metaL.text = meta;
    _sumL.text = [MDUtil plainFromMarkdown:_manga.summary];
    NSString *url = [_manga coverUrlForPixelWidth:512];
    if (url) [MDImageLoader loadURL:url maxPixel:512 completion:^(UIImage *i) { if (i) _cover.image = i; }];
    [self layoutHeader]; [self updateReadButton];
}

- (void)layoutHeader {
    CGFloat W = self.tableView.bounds.size.width, tx = 10 + 110 + 10, tw = W - tx - 10;
    _cover.frame = CGRectMake(10, 10, 110, 154);
    CGSize ts = [_titleL.text sizeWithFont:_titleL.font constrainedToSize:CGSizeMake(tw, 90)];
    _titleL.frame = CGRectMake(tx, 10, tw, ts.height);
    CGSize ms = [(_metaL.text ?: @"") sizeWithFont:_metaL.font constrainedToSize:CGSizeMake(tw, 70)];
    _metaL.frame = CGRectMake(tx, CGRectGetMaxY(_titleL.frame) + 4, tw, ms.height);
    _readBtn.frame = CGRectMake(tx, 164 - 36, tw, 36);
    CGSize ss = [(_sumL.text ?: @"") sizeWithFont:_sumL.font constrainedToSize:CGSizeMake(W - 20, 4000)];
    _sumL.frame = CGRectMake(10, 174, W - 20, ss.height);
    CGFloat h = CGRectGetMaxY(_sumL.frame) + 10;
    if (fabs(_header.frame.size.height - h) > 0.5 || _header.frame.size.width != W) {
        _header.frame = CGRectMake(0, 0, W, h); self.tableView.tableHeaderView = _header;
    }
}

- (void)updateFavoriteButton { _favBtn.title = [MDLibrary isFavorite:_manga.identifier] ? @"★" : @"☆"; }
- (void)toggleFavorite {
    if ([MDLibrary isFavorite:_manga.identifier]) [MDLibrary removeFavorite:_manga.identifier]; else [MDLibrary addFavorite:_manga];
    [self updateFavoriteButton];
}
- (void)updateReadButton {
    NSDictionary *last = [MDLibrary lastReadOfManga:_manga.identifier];
    [_readBtn setTitle:last ? @"Продолжить" : @"Читать" forState:UIControlStateNormal];
    _readBtn.enabled = _chapters.count > 0;
}

#pragma mark - Loading
- (void)loadDetails {
    NSString *ident = _manga.identifier;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *e = nil; MDManga *full = [MDApi manga:ident error:&e];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (full) {
                full.localCover = [MDDownloads coverPathForManga:ident];
                _manga = full; self.title = full.title; _lang = [self pickLanguage]; [self fillHeader]; [self updateFavoriteButton];
            }
            [self loadChapters];
        });
    });
}

- (void)loadChapters {
    NSString *ident = _manga.identifier, *lang = _lang;
    _notice.text = @"Загрузка глав…"; self.tableView.tableFooterView = _notice;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *e = nil; NSArray *list = [MDApi chaptersOfManga:ident language:lang error:&e];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![lang isEqualToString:_lang]) return;
            if (!list) {                                           // no network → offer what is on the device
                NSArray *off = [MDDownloads downloadedChaptersOfManga:ident];
                if (off.count) {
                    _chapters = off; _offline = YES; self.navigationItem.prompt = @"Нет сети — загруженные главы";
                    self.tableView.tableFooterView = nil; [self updateReadButton]; [self.tableView reloadData];
                } else _notice.text = [NSString stringWithFormat:@"Ошибка: %@", e.localizedDescription];
                return;
            }
            _offline = NO; self.navigationItem.prompt = nil;
            _chapters = list;
            _notice.text = list.count ? nil : [NSString stringWithFormat:@"Нет глав на языке «%@».\nВыберите другой язык: Меню → Язык глав.",
                                               [MDSettings nameForLanguage:lang]];
            self.tableView.tableFooterView = list.count ? nil : _notice;
            [self updateReadButton]; [self.tableView reloadData];
        });
    });
}

#pragma mark - Menus
- (void)presentSheet:(NSString *)title tag:(NSInteger)tag titles:(NSArray *)titles {
    UIActionSheet *s = [[UIActionSheet alloc] initWithTitle:title delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    s.actionSheetStyle = UIActionSheetStyleBlackOpaque; s.tag = tag;
    for (NSString *t in titles) [s addButtonWithTitle:t];
    s.cancelButtonIndex = [s addButtonWithTitle:@"Отмена"];
    [s showInView:self.view.window];
}

- (void)showMenu {
    NSMutableArray *keys = [NSMutableArray array], *titles = [NSMutableArray array];
    if (!_offline && _chapters.count) {
        [keys addObject:@"dlall"];    [titles addObject:[NSString stringWithFormat:@"Скачать все главы (%lu)", (unsigned long)_chapters.count]];
        [keys addObject:@"dlunread"]; [titles addObject:@"Скачать непрочитанные"];
    }
    [keys addObject:@"lang"]; [titles addObject:[NSString stringWithFormat:@"Язык глав: %@", [MDSettings nameForLanguage:_lang]]];
    if ([[MDDownloads downloadedChaptersOfManga:_manga.identifier] count]) { [keys addObject:@"rmall"]; [titles addObject:@"Удалить загруженное"]; }
    _sheetKeys = keys; [self presentSheet:nil tag:kSheetManga titles:titles];
}

- (MDChapter *)chapterAtRow:(NSInteger)row { return _chapters[_chapters.count - 1 - row]; }

- (void)longPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:[g locationInView:self.tableView]];
    if (!ip) return;
    _sheetChapter = ip.row; MDChapter *c = [self chapterAtRow:ip.row];
    NSString *st = [MDDownloads statusForChapter:c.identifier];
    NSMutableArray *keys = [NSMutableArray array], *titles = [NSMutableArray array];
    if ([st isEqual:@"офлайн"]) { [keys addObject:@"rm"]; [titles addObject:@"Удалить загрузку"]; }
    else if (st && ![st isEqual:@"ошибка загрузки"]) { [keys addObject:@"cancel"]; [titles addObject:@"Отменить загрузку"]; }
    else if (!_offline) {
        [keys addObject:@"dl"];     [titles addObject:@"Скачать главу"];
        [keys addObject:@"dlfrom"]; [titles addObject:@"Скачать эту и все новее"];
    }
    if (!keys.count) return;
    _sheetKeys = keys; [self presentSheet:[c displayName] tag:kSheetChapter titles:titles];
}

- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {
    if (i == s.cancelButtonIndex) return;
    if (s.tag == kSheetLanguage) {
        if (i >= (NSInteger)_langChoices.count) return;
        _lang = _langChoices[i]; [MDSettings setLanguage:_lang];
        _chapters = @[]; _offline = NO; [self.tableView reloadData]; [self loadChapters];
        return;
    }
    if (i >= (NSInteger)_sheetKeys.count) return;
    NSString *key = _sheetKeys[i];
    if (s.tag == kSheetManga) {
        if ([key isEqual:@"dlall"]) [MDDownloads enqueueChapters:_chapters manga:_manga];
        else if ([key isEqual:@"dlunread"]) {
            NSMutableArray *l = [NSMutableArray array];
            for (MDChapter *c in _chapters) if (![MDLibrary isChapterFinished:c.identifier]) [l addObject:c];
            [MDDownloads enqueueChapters:l manga:_manga];
        } else if ([key isEqual:@"lang"]) [self chooseLanguage];
        else if ([key isEqual:@"rmall"]) { [MDDownloads deleteManga:_manga.identifier]; if (_offline) { _chapters = @[]; [self.tableView reloadData]; [self.navigationController popViewControllerAnimated:YES]; } }
    } else if (s.tag == kSheetChapter) {
        MDChapter *c = [self chapterAtRow:_sheetChapter];
        if ([key isEqual:@"dl"]) [MDDownloads enqueueChapters:@[c] manga:_manga];
        else if ([key isEqual:@"dlfrom"]) {
            NSInteger idx = _chapters.count - 1 - _sheetChapter;                    // ascending index; "newer" = higher
            [MDDownloads enqueueChapters:[_chapters subarrayWithRange:NSMakeRange(idx, _chapters.count - idx)] manga:_manga];
        } else if ([key isEqual:@"rm"]) { [MDDownloads deleteChapter:c.identifier]; if (_offline) [self loadChapters]; }
        else if ([key isEqual:@"cancel"]) [MDDownloads cancelChapter:c.identifier];
    }
    [self.tableView reloadData];
}

- (void)chooseLanguage {
    _langChoices = _manga.languages.count ? _manga.languages : [MDSettings languageCodes];
    NSMutableArray *t = [NSMutableArray array];
    for (NSString *c in _langChoices) [t addObject:[MDSettings nameForLanguage:c]];
    [self presentSheet:@"Язык глав" tag:kSheetLanguage titles:t];
}

#pragma mark - Reading
- (void)openReaderAtIndex:(NSInteger)idx {
    MDReaderViewController *r = [[MDReaderViewController alloc] initWithManga:_manga chapters:_chapters index:idx];
    [self.navigationController pushViewController:r animated:YES];
}
- (void)readTapped {
    if (!_chapters.count) return;
    NSDictionary *last = [MDLibrary lastReadOfManga:_manga.identifier];
    NSInteger idx = 0;
    if (last) for (NSInteger i = 0; i < (NSInteger)_chapters.count; i++)
        if ([[_chapters[i] identifier] isEqual:last[@"chapterId"]]) { idx = i; break; }
    [self openReaderAtIndex:idx];
}

#pragma mark - Table (newest first)
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return _chapters.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"c"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
    MDChapter *ch = [self chapterAtRow:ip.row];
    c.textLabel.text = [ch displayName];
    NSString *sub = [ch subtitle], *st = [MDDownloads statusForChapter:ch.identifier];
    c.detailTextLabel.text = st ? (sub.length ? [NSString stringWithFormat:@"%@ · %@", sub, st] : st) : sub;
    c.accessoryType = [MDLibrary isChapterFinished:ch.identifier] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return c;
}
- (void)tableView:(UITableView *)t willDisplayCell:(UITableViewCell *)c forRowAtIndexPath:(NSIndexPath *)ip { [MDTheme styleCell:c]; }
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    [self openReaderAtIndex:_chapters.count - 1 - ip.row];
}
@end
