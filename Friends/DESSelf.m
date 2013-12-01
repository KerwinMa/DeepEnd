#import "DeepEnd.h"
#import "DeepEnd-Private.h"
#import "DESSelf.h"
#import "tox.h"
#import "Messenger.h"

@implementation DESSelf

+ (DESFriend *)self {
    return [[DESToxNetworkConnection sharedConnection] me];
}

+ (DESFriend *)selfWithConnection:(DESToxNetworkConnection *)connection {
    return [connection me];
}

- (NSString *)friendAddress {
    uint8_t *theData = malloc(DESFriendAddressSize);
    tox_get_address(self.owner.connection.m, theData);
    NSString *theString = DESConvertFriendAddressToString(theData);
    free(theData);
    return theString;
}

- (NSString *)publicKey {
    uint8_t *theData = malloc(DESPublicKeySize);
    memcpy(theData, ((Messenger*)self.owner.connection.m)->net_crypto->self_public_key, crypto_box_PUBLICKEYBYTES);
    NSString *theString = DESConvertPublicKeyToString(theData);
    free(theData);
    return theString;
}

- (NSString *)privateKey {
    uint8_t *theData = malloc(DESPrivateKeySize);
    memcpy(theData, ((Messenger*)self.owner.connection.m)->net_crypto->self_secret_key, crypto_box_SECRETKEYBYTES);
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

- (BOOL)isOnline {
    return YES;
}

- (NSUInteger)sendMessage:(NSString *)theMessage {
    return NO; /* We cannot send messages to ourself. */
}

- (void)setUserStatus:(NSString *)userStatus kind:(DESStatusType)kind {
    [self setUserStatus:userStatus];
    [self setStatusType:kind];
}

- (void) CALLS_INTO_CORE_FUNCTIONS setDisplayName:(NSString *)displayName {
    [self willChangeValueForKey:@"displayName"];
    int fail = tox_set_name(self.owner.connection.m, (uint8_t*)[displayName UTF8String], [displayName lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
    if (!fail) {
        _displayName = displayName;
        [self didChangeValueForKey:@"displayName"];
    }
}

- (void) CALLS_INTO_CORE_FUNCTIONS setUserStatus:(NSString *)userStatus {
    [self willChangeValueForKey:@"userStatus"];
    int fail = tox_set_status_message(self.owner.connection.m, (uint8_t*)[userStatus UTF8String], [userStatus lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
    if (!fail) {
        _userStatus = userStatus;
        [self didChangeValueForKey:@"userStatus"];
    }
}

- (void) CALLS_INTO_CORE_FUNCTIONS setStatusType:(DESStatusType)statusType {
    [self willChangeValueForKey:@"statusType"];
    int fail = tox_set_userstatus(self.owner.connection.m, (TOX_USERSTATUS)statusType);
    if (!fail) {
        _statusType = statusType;
        [self didChangeValueForKey:@"statusType"];
    }
}

@end
