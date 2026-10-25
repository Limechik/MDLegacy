#import "MDCoverCell.h"
#import "MDImageLoader.h"
#import <QuartzCore/QuartzCore.h>
#import "MDTheme.h"

@implementation MDCoverCell {
    UIImageView *_cover; UILabel *_title; NSString *_url;
}
- (id)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    _cover = [[UIImageView alloc] init];
    _cover.contentMode = UIViewContentModeScaleAspectFill; _cover.clipsToBounds = YES;
    _cover.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    _cover.layer.cornerRadius = 4;
    _title = [[UILabel alloc] init];
    _title.font = [UIFont systemFontOfSize:12]; _title.numberOfLines = 2;
    _title.backgroundColor = [UIColor clearColor]; _title.textColor = [MDTheme text];
    [self.contentView addSubview:_cover]; [self.contentView addSubview:_title];
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    _cover.frame = CGRectMake(0, 0, w, floor(w * 1.5));
    _title.frame = CGRectMake(1, CGRectGetMaxY(_cover.frame) + 3, w - 2, 32);
}
- (void)prepareForReuse { [super prepareForReuse]; _url = nil; _cover.image = nil; }

- (void)setManga:(MDManga *)m {
    _title.text = m.title; _cover.image = nil;
    NSString *url = [m coverUrlForPixelWidth:256];
    _url = url;
    if (!url) return;
    [MDImageLoader loadURL:url maxPixel:256 completion:^(UIImage *img) {
        if (img && [_url isEqualToString:url]) _cover.image = img;
    }];
}
@end
