#import "DeepEnd.h"
#import "DeepEnd-Private.h"
#import "DESFriend.h"
#import "tox.h"
#import "DESOneToOneChatContext.h"

/* Declaration of constants in DeepEnd.h */
const int DESFriendInvalid = -1;
const int DESFriendSelf = -2;
const size_t DESFriendAddressSize = TOX_FRIEND_ADDRESS_SIZE;

@implementation DESFriend

+ (instancetype)friendRequestWithAddress:(NSString *)aKey message:(NSString *)theMessage owner:(DESFriendManager *)theOwner {
    DESFriend *req = [super alloc];
    req->owner = theOwner;
    req->_friendNumber = DESFriendInvalid;
    req->_status = DESFriendStatusRequestReceived;
    req->_publicKey = aKey;
    req->_friendAddress = nil;
    req->_displayName = @"";
    req->_requestInfo = theMessage;
    req->_dateReceived = [NSDate date];
    return req;
}

- (instancetype)initWithNumber:(int)friendNumber {
    return [self initWithNumber:friendNumber owner:[DESToxNetworkConnection sharedConnection].friendManager];
}

- (instancetype) CALLS_INTO_CORE_FUNCTIONS initWithNumber:(int)friendNumber owner:(DESFriendManager *)manager {
    self = [super init];
    if (self) {
        owner = manager;
        _friendNumber = friendNumber;
        uint8_t *theKey = malloc(DESPublicKeySize);
        int isValidFriend = tox_getclient_id(owner.connection.m, friendNumber, theKey);
        if (isValidFriend == -1) {
            free(theKey);
            [[[NSException alloc] initWithName:NSInvalidArgumentException reason:@"Invalid friend number" userInfo:nil] raise];
            return nil;
        }
        _publicKey = DESConvertPublicKeyToString(theKey);
        free(theKey);
        uint8_t *theName = malloc(TOX_MAX_NAME_LENGTH);
        tox_getname(owner.connection.m, friendNumber, theName);
        _displayName = [NSString stringWithCString:(const char*)theName encoding:NSUTF8StringEncoding];
        free(theName);
        uint8_t *theStatus = malloc(tox_get_statusmessage_size(owner.connection.m, friendNumber));
        tox_copy_statusmessage(owner.connection.m, friendNumber, theStatus, tox_get_statusmessage_size(owner.connection.m, friendNumber));
        _userStatus = [NSString stringWithCString:(const char*)theStatus encoding:NSUTF8StringEncoding];
        free(theStatus);
        _dateReceived = nil;
        _requestInfo = nil;
        _chatContext = [[DESOneToOneChatContext alloc] initWithPartner:self];
        [owner addContext:_chatContext];
        
    }
    return self;
}

- (int)friendNumber {
    return _friendNumber;
}

- (NSString *)displayName {
    return _displayName;
}

- (NSString *)userStatus {
    return _userStatus;
}

- (NSString *)publicKey {
    return _publicKey;
}

- (NSString *)privateKey {
    return nil;
}

- (void)dealloc {
    DESDebug(@"DESFriend %@ deallocated!", self.displayName);
    _chatContext = nil;
    owner = nil;
}

- (void)setDisplayName:(NSString *)displayName {
    [self willChangeValueForKey:@"displayName"];
    _displayName = displayName;
    [self didChangeValueForKey:@"displayName"];
}

- (void)setUserStatus:(NSString *)userStatus {
    [self willChangeValueForKey:@"userStatus"];
    _userStatus = userStatus;
    [self didChangeValueForKey:@"userStatus"];
}

- (void)setStatus:(DESFriendStatus)status {
    [self willChangeValueForKey:@"status"];
    _status = status;
    [self didChangeValueForKey:@"status"];
}

- (void)setStatusType:(DESStatusType)kind {
    [self willChangeValueForKey:@"statusType"];
    _statusType = kind;
    [self didChangeValueForKey:@"statusType"];
}

- (void)setChatContext:(id<DESChatContext>)ctx {
    [self willChangeValueForKey:@"chatContext"];
    _chatContext = ctx;
    [self didChangeValueForKey:@"chatContext"];
}

@end
