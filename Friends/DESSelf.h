#import "DeepEnd.h"
#import "DESFriend.h"

@interface DESSelf : DESFriend

+ (DESFriend *)self;
+ (DESFriend *)selfWithConnection:(DESToxNetworkConnection *)connection;

@property (strong, readwrite) NSString *displayName;
@property (strong, readwrite) NSString *userStatus;
@property (readwrite) DESStatusType statusType;

- (void)setUserStatus:(NSString *)userStatus kind:(DESStatusType)kind;

@end
