#import "DeepEnd.h"
#import "DESSelf.h"
#import "Messenger.h"

@implementation DESSelf

+ (DESFriend *)self {
    return [[DESToxNetworkConnection sharedConnection] me];
}

- (NSString *)publicKey {
    uint8_t *theData = malloc(crypto_box_PUBLICKEYBYTES);
    memcpy(theData, self_public_key, crypto_box_PUBLICKEYBYTES);
    NSString *theString = DESConvertPublicKeyToString(theData);
    free(theData);
    return theString;
}

- (NSString *)privateKey {
    uint8_t *theData = malloc(crypto_box_SECRETKEYBYTES);
    memcpy(theData, self_secret_key, crypto_box_SECRETKEYBYTES);
    NSString *theString = DESConvertPrivateKeyToString(theData);
    free(theData);
    return theString;
}

- (DESFriendStatus)status {
    return DESFriendStatusSelf;
}

- (int)friendNumber {
    return DESFriendSelf;
}

- (BOOL)sendMessage:(NSString *)theMessage {
    return NO; /* We cannot send messages to ourself. */
}

- (void) CALLS_INTO_CORE_FUNCTIONS setDisplayName:(NSString *)displayName {
    [self willChangeValueForKey:@"displayName"];
    int fail = setname((uint8_t*)[displayName UTF8String], [displayName lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    if (!fail) {
        _displayName = displayName;
        [self didChangeValueForKey:@"displayName"];
    }
}

- (void)setUserStatus:(NSString *)userStatus {
    [self setUserStatus:userStatus kind:DESStatusTypeRetain];
}

- (void)setStatusType:(DESStatusType)statusType {
    [self setUserStatus:self.userStatus kind:statusType];
}

- (void) CALLS_INTO_CORE_FUNCTIONS setUserStatus:(NSString *)userStatus kind:(DESStatusType)kind {
    [self willChangeValueForKey:@"userStatus"];
    int fail = m_set_userstatus((USERSTATUS_KIND)kind, (uint8_t*)[userStatus UTF8String], [userStatus lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    if (!fail) {
        _userStatus = userStatus;
        [self didChangeValueForKey:@"userStatus"];
    }
    
    if (kind != DESStatusTypeRetain) {
        [self willChangeValueForKey:@"statusType"];
        fail = 0;
        if (!fail) {
            _statusType = kind;
            [self didChangeValueForKey:@"statusType"];
        }
    }
}

@end
