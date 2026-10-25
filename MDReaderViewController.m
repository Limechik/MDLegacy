#import "MDReaderViewController.h"
#import "MDApi.h"
#import "MDLibrary.h"
#import "MDSettings.h"
#import "MDImageLoader.h"
#import "MDUtil.h"
#import "MDDownloads.h"
#import "MDTheme.h"
#import "MDNightMode.h"

#pragma mark - Page view (zoomable)
@interface MDPageView : UIScrollView <UIScrollViewDelegate>
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, strong) UITapGestureRecognizer *doubleTapGR;
@property (nonatomic, copy) void (^onRetry)(MDPageView *);
- (void)showSpinner; - (void)showImage:(UIImage *)i; - (void)showFailure;
@end

@implementation MDPageView {
    UIActivityIndicatorView *_spin; UILabel *_fail;
}
- (id)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    self.delegate = self; self.minimumZoomScale = 1; self.maximumZoomScale = 3;
    self.showsHorizontalScrollIndicator = self.showsVerticalScrollIndicator = NO;
    _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
    _imageView.contentMode = UIViewContentModeScaleAspectFit; [self addSubview:_imageView];
    _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _spin.hidesWhenStopped = YES; [self addSubview:_spin];
    _fail = [[UILabel alloc] init]; _fail.textColor = [UIColor lightGrayColor]; _fail.textAlignment = NSTextAlignmentCenter;
    _fail.numberOfLines = 0; _fail.backgroundColor = [UIColor clearColor]; _fail.hidden = YES;
    _fail.text = @"Не удалось загрузить страницу.\nНажмите, чтобы повторить";
    [self addSubview:_fail];
    UITapGestureRecognizer *retry = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(retryTapped)];
    [self addGestureRecognizer:retry];
    _doubleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    _doubleTapGR.numberOfTapsRequired = 2; [self addGestureRecognizer:_doubleTapGR];
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.zoomScale == 1) _imageView.frame = self.bounds;
    _spin.center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    _fail.frame = CGRectMake(20, self.bounds.size.height / 2 - 40, self.bounds.size.width - 40, 80);
}
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)s { return _imageView; }
- (void)doubleTap:(UITapGestureRecognizer *)g {
    if (self.zoomScale > 1.01) { [self setZoomScale:1 animated:YES]; return; }
    CGPoint p = [g locationInView:_imageView]; CGSize s = self.bounds.size;
    [self zoomToRect:CGRectMake(p.x - s.width / 5, p.y - s.height / 5, s.width * 0.4, s.height * 0.4) animated:YES];
}
- (void)retryTapped { if (!_fail.hidden && _onRetry) _onRetry(self); }
- (void)showSpinner { _fail.hidden = YES; _imageView.image = nil; [_spin startAnimating]; }
- (void)showImage:(UIImage *)i { [_spin stopAnimating]; _fail.hidden = YES; _imageView.image = i; }
- (void)showFailure { [_spin stopAnimating]; _fail.hidden = NO; }
@end

#pragma mark - Reader
@implementation MDReaderViewController {
    MDManga *_manga; NSArray *_chapters; NSInteger _index;
    NSArray *_pages; NSInteger _cur, _gen; BOOL _chromeHidden;
    UIScrollView *_scroll; NSMutableDictionary *_views;
    UIToolbar *_bar; UIBarButtonItem *_counter; UIActivityIndicatorView *_busy; UILabel *_notice;
    UITapGestureRecognizer *_tap;
}

- (id)initWithManga:(MDManga *)m chapters:(NSArray *)chapters index:(NSInteger)idx {
    self = [super initWithNibName:nil bundle:nil];
    _manga = m; _chapters = chapters; _index = idx; _views = [NSMutableDictionary dictionary];
    self.hidesBottomBarWhenPushed = YES; self.wantsFullScreenLayout = YES;
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return YES; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    _scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scroll.pagingEnabled = YES; _scroll.delegate = self; _scroll.backgroundColor = [UIColor blackColor];
    _scroll.showsHorizontalScrollIndicator = NO; [self.view addSubview:_scroll];

    _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleChrome)];
    [self.view addGestureRecognizer:_tap];

    _bar = [[UIToolbar alloc] init]; _bar.barStyle = UIBarStyleBlackTranslucent;
    _counter = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    _counter.enabled = NO;
    UIBarButtonItem *prev = [[UIBarButtonItem alloc] initWithTitle:@"‹ Пред." style:UIBarButtonItemStyleBordered target:self action:@selector(prevChapter)];
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"След. ›" style:UIBarButtonItemStyleBordered target:self action:@selector(nextChapter)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    _bar.items = @[prev, flex, _counter, flex, next];
    [self.view addSubview:_bar];

    _busy = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _busy.hidesWhenStopped = YES; [self.view addSubview:_busy];
    _notice = [[UILabel alloc] init]; _notice.textColor = [UIColor lightGrayColor]; _notice.textAlignment = NSTextAlignmentCenter;
    _notice.numberOfLines = 0; _notice.backgroundColor = [UIColor clearColor]; [self.view addSubview:_notice];

    [self loadPages];
}

- (void)viewWillAppear:(BOOL)a {
    [super viewWillAppear:a];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
    [MDNightMode start];
}
- (void)viewWillDisappear:(BOOL)a {
    [super viewWillDisappear:a];
    [MDNightMode stop];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    self.navigationController.navigationBar.barStyle = [MDTheme barStyle];
    [self remember];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    _scroll.frame = b;
    _bar.frame = CGRectMake(0, b.size.height - 44, b.size.width, 44);
    _busy.center = CGPointMake(b.size.width / 2, b.size.height / 2);
    _notice.frame = CGRectMake(20, b.size.height / 2 - 40, b.size.width - 40, 80);
    [self layoutPages];
}

#pragma mark - Chapter loading
- (MDChapter *)chapter { return _chapters[_index]; }

- (void)loadPages {
    _gen++; NSInteger gen = _gen;
    for (MDPageView *v in _views.allValues) [v removeFromSuperview];
    [_views removeAllObjects]; _pages = nil; _cur = 0; _scroll.contentSize = CGSizeZero;
    self.title = [[self chapter] displayName]; _notice.text = nil; [_busy startAnimating]; [self updateCounter];
    NSString *cid = [self chapter].identifier; BOOL saver = [MDSettings dataSaver];
    NSArray *local = [MDDownloads localPagesForChapter:cid];          // downloaded → read from disk, no network
    if (local.count) {
        [_busy stopAnimating]; _pages = local;
        _cur = MIN([MDLibrary pageOfChapter:cid], (NSInteger)local.count - 1);
        [self layoutPages]; [self refreshVisible]; [self updateCounter]; [self remember];
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *e = nil; NSArray *urls = [MDApi pagesOfChapter:cid saver:saver error:&e];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (gen != _gen) return;
            [_busy stopAnimating];
            if (!urls) { _notice.text = [NSString stringWithFormat:@"Ошибка: %@", e.localizedDescription]; return; }
            _pages = urls;
            _cur = MIN([MDLibrary pageOfChapter:cid], (NSInteger)urls.count - 1);
            [self layoutPages]; [self refreshVisible]; [self updateCounter]; [self remember];
        });
    });
}

- (void)switchChapter:(NSInteger)d {
    NSInteger ni = _index + d;
    if (ni < 0 || ni >= (NSInteger)_chapters.count) { [MDUtil showMessage:d > 0 ? @"Это последняя глава" : @"Это первая глава" title:@""]; return; }
    [self remember]; _index = ni; [self loadPages];
}
- (void)prevChapter { [self switchChapter:-1]; }
- (void)nextChapter { [self switchChapter:+1]; }

#pragma mark - Pages
- (NSInteger)slotForPage:(NSInteger)p { return p; }
- (CGRect)frameForPage:(NSInteger)p {
    CGSize s = _scroll.bounds.size; return CGRectMake([self slotForPage:p] * s.width, 0, s.width, s.height);
}
- (void)layoutPages {
    if (!_pages.count) return;
    CGSize s = _scroll.bounds.size;
    _scroll.contentSize = CGSizeMake(s.width * _pages.count, s.height);
    for (NSNumber *k in _views) ((MDPageView *)_views[k]).frame = [self frameForPage:k.integerValue];
    _scroll.contentOffset = CGPointMake([self slotForPage:_cur] * s.width, 0);
}

- (void)refreshVisible {
    NSInteger n = _pages.count;
    for (NSNumber *k in [_views allKeys]) if (labs(k.integerValue - _cur) > 1) {
        [(MDPageView *)_views[k] removeFromSuperview]; [_views removeObjectForKey:k];
    }
    for (NSInteger i = MAX(0, _cur - 1); i <= MIN(n - 1, _cur + 1); i++) {
        if (_views[@(i)]) continue;
        MDPageView *v = [[MDPageView alloc] initWithFrame:[self frameForPage:i]];
        [_tap requireGestureRecognizerToFail:v.doubleTapGR];
        _views[@(i)] = v; [_scroll addSubview:v];
        [self loadPageView:v index:i];
    }
}

- (void)loadPageView:(MDPageView *)v index:(NSInteger)i {
    NSString *url = _pages[i]; v.url = url; [v showSpinner];
    __weak MDReaderViewController *ws = self; __weak MDPageView *wv = v;
    v.onRetry = ^(MDPageView *p) { [ws loadPageView:p index:i]; };
    [MDImageLoader loadURL:url maxPixel:1600 completion:^(UIImage *img) {
        MDPageView *s = wv; if (!s || ![s.url isEqualToString:url]) return;
        if (img) [s showImage:img]; else [s showFailure];
    }];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)sv { [self settle]; }
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)sv { [self settle]; }
- (void)settle {
    CGFloat w = _scroll.bounds.size.width; NSInteger n = _pages.count;
    if (w < 1 || !n) return;
    NSInteger slot = MAX(0, MIN(n - 1, (NSInteger)floor(_scroll.contentOffset.x / w + 0.5)));
    NSInteger p = slot;
    if (p == _cur) return;
    _cur = p; [self refreshVisible]; [self updateCounter]; [self remember];
}

- (void)updateCounter {
    _counter.title = _pages.count ? [NSString stringWithFormat:@"%ld / %lu", (long)_cur + 1, (unsigned long)_pages.count] : @"";
}
- (void)remember {
    if (_pages.count) [MDLibrary recordManga:_manga chapter:[self chapter] page:_cur total:_pages.count];
}

- (void)toggleChrome {
    _chromeHidden = !_chromeHidden;
    [self.navigationController setNavigationBarHidden:_chromeHidden animated:YES];
    [[UIApplication sharedApplication] setStatusBarHidden:_chromeHidden withAnimation:UIStatusBarAnimationFade];
    [UIView animateWithDuration:0.25 animations:^{ _bar.alpha = _chromeHidden ? 0 : 1; }];
}
@end
