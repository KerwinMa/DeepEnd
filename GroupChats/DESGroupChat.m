#import "DESGroupChat.h"

@implementation DESGroupChat

- (instancetype)initWithInvitingFriend:(DESFriend *)inviter owner:(DESFriendManager *)owner publicKey:(NSString *)publicKey {
    self = [super init];
    if (self) {
        _inviter = inviter;
        _owner = owner;
        _publicKey = publicKey;
    }
    return self;
}

- (void)invalidate {
    _inviter = nil;
    _owner = nil;
}

@end
