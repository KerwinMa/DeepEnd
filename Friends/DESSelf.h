#import "DeepEnd.h"
#import "DESFriend.h"

@interface DESSelf : DESFriend

+ (DESFriend *)self;
+ (DESFriend *)selfWithConnection:(DESToxNetworkConnection *)connection;

@property (strong, readwrite, nonatomic) NSString *displayName;
@property (strong, readwrite, nonatomic) NSString *userStatus;
@property (readwrite, nonatomic) DESStatusType statusType;

- (void)setUserStatus:(NSString *)userStatus kind:(DESStatusType)kind;

@end
