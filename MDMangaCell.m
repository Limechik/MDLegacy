#import "MDMangaCell.h"
#import "MDImageLoader.h"
#import "MDTheme.h"

@implementation MDMangaCell {
    UIImageView *_cover; UILabel *_title, *_sub; NSString *_coverURL;
}
- (id)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
    _cover = [[UIImageView alloc] init];
    _cover.contentMode = UIViewContentModeScaleAspectFill; _cover.clipsToBounds = YES;
    _cover.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    _title = [[UILabel alloc] init]; _title.font = [UIFont boldSystemFontOfSize:16]; _title.numberOfLines = 2;
    _title.backgroundColor = [UIColor clearColor]; _title.textColor = [MDTheme text];
    _sub = [[UILabel alloc] init]; _sub.font = [UIFont systemFontOfSize:13]; _sub.numberOfLines = 2;
    _sub.textColor = [MDTheme secondaryText]; _sub.backgroundColor = [UIColor clearColor];
    [self.contentView addSubview:_cover]; [self.contentView addSubview:_title]; [self.contentView addSubview:_sub];
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    _cover.frame = CGRectMake(10, 6, 60, 84);
    _title.frame = CGRectMake(80, 8, w - 90, 40);
    _sub.frame = CGRectMake(80, 50, w - 90, 38);
}
- (void)prepareForReuse { [super prepareForReuse]; _coverURL = nil; _cover.image = nil; }

- (void)setManga:(MDManga *)m subtitle:(NSString *)sub {
    _title.text = m.title; _sub.text = sub; _cover.image = nil;
    NSString *url = [m coverUrlForPixelWidth:256];
    _coverURL = url;
    if (!url) return;
    [MDImageLoader loadURL:url maxPixel:256 completion:^(UIImage *img) {
        if (img && [_coverURL isEqualToString:url]) _cover.image = img;
    }];
}
@end
