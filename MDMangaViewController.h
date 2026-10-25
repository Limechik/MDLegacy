#import <UIKit/UIKit.h>
#import "MDModels.h"
@interface MDMangaViewController : UITableViewController <UIActionSheetDelegate>
- (id)initWithManga:(MDManga *)m;     // may be a stub (id/title/coverFile only)
@end
