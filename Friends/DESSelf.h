#import "DeepEnd.h"
#import "DESFriend.h"

@interface DESSelf : DESFriend

+ (DESFriend *)self;

@property (strong, readwrite) NSString *displayName;
@property (strong, readwrite) NSString *userStatus;
@property (readwrite) DESStatusType statusType;

@end
