#import "MDCatalogViewController.h"
#import "MDMangaViewController.h"
#import "MDCoverCell.h"
#import "MDApi.h"
#import "MDTheme.h"

static NSString *const kCell = @"cover", *const kHeader = @"search";

@interface MDSearchHeader : UICollectionReusableView @end
@implementation MDSearchHeader @end

@implementation MDCatalogViewController {
    NSMutableArray *_items; NSInteger _total, _mode, _gen; NSString *_query; BOOL _loading;
    UISegmentedControl *_seg; UISearchBar *_bar; UILabel *_notice; UIRefreshControl *_refresh;
}

- (id)init {
    UICollectionViewFlowLayout *l = [[UICollectionViewFlowLayout alloc] init];
    l.minimumInteritemSpacing = 8; l.minimumLineSpacing = 10;
    l.sectionInset = UIEdgeInsetsMake(8, 8, 8, 8);
    l.headerReferenceSize = CGSizeMake(320, 44);
    self = [super initWithCollectionViewLayout:l];
    self.title = @"Каталог"; _items = [NSMutableArray array];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UICollectionView *cv = self.collectionView;
    cv.backgroundColor = [MDTheme background]; cv.alwaysBounceVertical = YES;
    [cv registerClass:[MDCoverCell class] forCellWithReuseIdentifier:kCell];
    [cv registerClass:[MDSearchHeader class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:kHeader];

    _seg = [[UISegmentedControl alloc] initWithItems:@[@"Популярное", @"Новое"]];
    _seg.segmentedControlStyle = UISegmentedControlStyleBar; _seg.selectedSegmentIndex = 0;
    _seg.frame = CGRectMake(0, 0, 200, 30);
    [_seg addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = _seg;

    _bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    _bar.delegate = self; _bar.placeholder = @"Поиск по названию"; _bar.barStyle = UIBarStyleBlack;

    UIView *bg = [[UIView alloc] init]; cv.backgroundView = bg;
    _notice = [[UILabel alloc] initWithFrame:CGRectMake(20, 110, 280, 80)];
    _notice.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _notice.textAlignment = NSTextAlignmentCenter; _notice.textColor = [UIColor grayColor];
    _notice.numberOfLines = 0; _notice.font = [UIFont systemFontOfSize:14]; _notice.backgroundColor = [UIColor clearColor];
    [bg addSubview:_notice];

    _refresh = [UIRefreshControl new]; _refresh.tintColor = [UIColor lightGrayColor];
    [_refresh addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    [cv addSubview:_refresh];
    [self reload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return YES; }
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)o duration:(NSTimeInterval)d {
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)modeChanged { _mode = _seg.selectedSegmentIndex; _query = nil; _bar.text = @""; [self reload]; }
- (void)setNotice:(NSString *)t { _notice.text = t; }

- (void)reload {
    _gen++; _loading = NO; _total = 0; [_items removeAllObjects];
    [self setNotice:nil]; [self.collectionView reloadData];
    [self loadMore];
}

- (void)loadMore {
    if (_loading) return;
    if (_items.count && _items.count >= _total) return;
    _loading = YES;
    NSInteger gen = _gen, mode = _mode, off = _items.count; NSString *q = _query;
    if (!_items.count && !_refresh.refreshing) [self setNotice:@"Загрузка…"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *e = nil; NSInteger total = 0; NSArray *list;
        if (q.length)       list = [MDApi searchTitle:q offset:off total:&total error:&e];
        else if (mode == 1) list = [MDApi latestWithOffset:off total:&total error:&e];
        else                list = [MDApi popularWithOffset:off total:&total error:&e];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (gen != _gen) return;
            _loading = NO; [_refresh endRefreshing];
            if (!list) { [self setNotice:[NSString stringWithFormat:@"Ошибка: %@\nПотяните вниз, чтобы повторить", e.localizedDescription]]; return; }
            _total = total; [_items addObjectsFromArray:list];
            [self setNotice:_items.count ? nil : @"Ничего не найдено"];
            [self.collectionView reloadData];
        });
    });
}

#pragma mark - Search
- (void)searchBarTextDidBeginEditing:(UISearchBar *)b { b.showsCancelButton = YES; }
- (void)searchBarCancelButtonClicked:(UISearchBar *)b {
    b.showsCancelButton = NO; b.text = @""; [b resignFirstResponder];
    if (_query) { _query = nil; [self reload]; }
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)b {
    [b resignFirstResponder]; _query = [b.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!_query.length) _query = nil;
    [self reload];
}
- (void)searchBar:(UISearchBar *)b textDidChange:(NSString *)t {
    if (!t.length && _query) { _query = nil; [self reload]; }
}

#pragma mark - Grid
- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s { return _items.count; }

- (CGSize)collectionView:(UICollectionView *)cv layout:(UICollectionViewLayout *)l sizeForItemAtIndexPath:(NSIndexPath *)ip {
    CGFloat w = cv.bounds.size.width;
    NSInteger cols = MAX(2, (NSInteger)floor((w - 8) / 100));        // 3 on iPhone portrait, 5 landscape
    CGFloat iw = floor((w - 8 * (cols + 1)) / cols);
    return CGSizeMake(iw, floor(iw * 1.5) + 38);
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)cv viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)ip {
    UICollectionReusableView *h = [cv dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kHeader forIndexPath:ip];
    [_bar removeFromSuperview];
    _bar.frame = h.bounds; _bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [h addSubview:_bar];
    return h;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    MDCoverCell *c = [cv dequeueReusableCellWithReuseIdentifier:kCell forIndexPath:ip];
    [c setManga:_items[ip.item]];
    if (ip.item >= (NSInteger)_items.count - 6) [self loadMore];
    return c;
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip {
    [self.navigationController pushViewController:[[MDMangaViewController alloc] initWithManga:_items[ip.item]] animated:YES];
}
@end
