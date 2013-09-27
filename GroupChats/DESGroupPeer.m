#import "DESGroupPeer.h"
#import "DESGroupChatContext.h"
#import "DeepEnd-Private.h"

#define DES_GROUP_CHAT_PUBLIC_KEY_DEFAULT @"1337133713371337133713371337133713371337133713371337133713371337"

@implementation DESGroupPeer

- (instancetype)initWithNumber:(int)friendNumber inGroupChat:(DESGroupChatContext *)ctx {
    self = [super init];
    if (self) {
        self.chatContext = ctx;
        _friendNumber = friendNumber;
        uint8_t *peername = calloc(TOX_MAX_NAME_LENGTH, 1);
        tox_group_peername(ctx.friendManager.connection.m, ctx.groupNumber, friendNumber, peername);
        _displayName = [NSString stringWithCString:(const char*)peername encoding:NSUTF8StringEncoding];
        free(peername);
        _userStatus = @"";
        _publicKey = DES_GROUP_CHAT_PUBLIC_KEY_DEFAULT;
    }
    return self;
}

- (DESFriendStatus)status {
    return DESFriendStatusOnline;
}

- (DESFriendManager *)owner {
    return self.chatContext.friendManager;
}

- (void)dealloc {
    DESDebug(@"DESFriend %@ deallocated!", self.displayName);
    self.chatContext = nil;
}

@end
