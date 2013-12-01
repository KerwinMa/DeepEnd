#import "DESGroupPeer.h"
#import "DESGroupChatContext.h"
#import "DeepEnd-Private.h"

#define DES_GROUP_CHAT_PUBLIC_KEY_DEFAULT @"1337133713371337133713371337133713371337133713371337133713371337"

@implementation DESGroupPeer {
    uint8_t *_peername;
}

- (instancetype)initWithNumber:(int)friendNumber inGroupChat:(DESGroupChatContext *)ctx {
    self = [super init];
    if (self) {
        self.chatContext = ctx;
        _friendNumber = friendNumber;
        _peername = calloc(TOX_MAX_NAME_LENGTH, 1);
        _userStatus = @"";
        _publicKey = DES_GROUP_CHAT_PUBLIC_KEY_DEFAULT;
    }
    return self;
}

- (NSString *)displayName {
    tox_group_peername(self.owner.connection.m, ((DESGroupChatContext*)self.chatContext).groupNumber, _friendNumber, _peername);
    return [NSString stringWithCString:(const char*)_peername encoding:NSUTF8StringEncoding];
}

- (DESFriendStatus)status {
    return DESFriendStatusOnline;
}

- (DESFriendManager *)owner {
    return self.chatContext.friendManager;
}

- (void)dealloc {
    free(_peername);
    DESDebug(@"DESFriend %@ deallocated!", self.displayName);
    self.chatContext = nil;
}

@end
