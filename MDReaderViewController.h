#import <UIKit/UIKit.h>
#import "MDModels.h"
@interface MDReaderViewController : UIViewController <UIScrollViewDelegate>
- (id)initWithManga:(MDManga *)m chapters:(NSArray *)chapters index:(NSInteger)idx;   // chapters ascending
@end
