#import "DeepEnd.h"
#import "DeepEnd-Private.h"
#import "DESFriend.h"
#import "Messenger.h"

/* Declaration of constants in DeepEnd.h */
const int DESFriendInvalid = -1;
const int DESFriendSelf = -2;

@implementation DESFriend

+ (instancetype)friendRequestWithKey:(NSString *)aKey message:(NSString *)theMessage owner:(DESFriendManager *)theOwner {
    DESFriend *req = [super alloc];
    req->owner = theOwner;
    req->_friendNumber = DESFriendInvalid;
    req->_status = DESFriendStatusRequestReceived;
    req->_publicKey = aKey;
    req->_displayName = @"";
    req->_userStatus = theMessage;
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
        uint8_t *theKey = malloc(crypto_box_PUBLICKEYBYTES);
        int isValidFriend = getclient_id(friendNumber, theKey);
        if (isValidFriend == -1) {
            free(theKey);
            [[[NSException alloc] initWithName:NSInvalidArgumentException reason:@"Invalid friend number" userInfo:nil] raise];
            return nil;
        }
        _publicKey = DESConvertPublicKeyToString(theKey);
        free(theKey);
        uint8_t *theName = malloc(MAX_NAME_LENGTH);
        getname(friendNumber, theName);
        _displayName = [NSString stringWithCString:(const char*)theName encoding:NSUTF8StringEncoding];
        free(theName);
        uint8_t *theStatus = malloc(m_get_userstatus_size(friendNumber));
        m_copy_userstatus(friendNumber, theStatus, m_get_userstatus_size(friendNumber));
        _userStatus = [NSString stringWithCString:(const char*)theStatus encoding:NSUTF8StringEncoding];
        free(theStatus);
        _dateReceived = nil;
    }
    return self;
}

#pragma mark - NSCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype) CALLS_INTO_CORE_FUNCTIONS initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        DESFriendStatus status = [aDecoder decodeIntegerForKey:@"friendStatus"];
        _status = status;
        NSString *publicKey = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"publicKey"];
        _publicKey = publicKey;
        NSString *displayName = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"displayName"];
        _displayName = displayName;
        NSString *userStatus = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"userStatus"];
        _userStatus = userStatus;
        BOOL didHaveCoreRef = [aDecoder decodeBoolForKey:@"isCoreFriend"];
        if (didHaveCoreRef) {
            uint8_t *buffer = malloc(crypto_box_PUBLICKEYBYTES);
            DESConvertPublicKeyToData(publicKey, buffer);
            int newNum = m_addfriend_norequest(buffer);
            free(buffer);
            if (displayName) {
                uint8_t *nameBuf = malloc(MAX_NAME_LENGTH);
                memcpy(nameBuf, [displayName UTF8String], [displayName lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
                __DESSetNameOfFriend(newNum, nameBuf);
                free(nameBuf);
            }
            if (userStatus) {
                __DESSetUserStatusOfFriend(newNum, (uint8_t*)[userStatus UTF8String], [userStatus lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
            }
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInteger:self.status forKey:@"friendStatus"];
    [aCoder encodeObject:self.publicKey forKey:@"publicKey"];
    [aCoder encodeObject:self.displayName forKey:@"displayName"];
    [aCoder encodeObject:self.userStatus forKey:@"userStatus"];
    [aCoder encodeBool:(self.friendNumber != DES_FRIEND_INVALID) forKey:@"isCoreFriend"];
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

- (NSUInteger) CALLS_INTO_CORE_FUNCTIONS sendMessage:(NSString *)message {
    if (self.status != DESFriendStatusOnline) {
        return NO;
    }
    NSArray *words = [message componentsSeparatedByString:@" "];
    NSUInteger len = 0;
    uint8_t *theBuffer = NULL;
    NSUInteger builtLength = 0;
    NSUInteger wordLength = 0;
    uint32_t receipt = 0;
    NSMutableArray *partialMessage = [[NSMutableArray alloc] initWithCapacity:[words count]];
    for (NSString *theWord in words) {
        wordLength = [theWord lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        if (builtLength + wordLength > MAX_MESSAGE_LENGTH) {
            NSString *thePayload = [[partialMessage componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            [partialMessage removeAllObjects];
            len = [thePayload lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
            theBuffer = malloc(len);
            memcpy(theBuffer, [thePayload UTF8String], len);
            receipt = m_sendmessage(self.friendNumber, theBuffer, (uint16_t)len);
            free(theBuffer);
            builtLength = 0;
            if (!receipt) return 0;
        }
        [partialMessage addObject:theWord];
        builtLength += wordLength + 1;
    }
    if ([partialMessage count]) {
        NSString *thePayload = [[partialMessage componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        [partialMessage removeAllObjects];
        len = [thePayload lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
        theBuffer = malloc(len);
        memcpy(theBuffer, [thePayload UTF8String], len);
        receipt = m_sendmessage(self.friendNumber, theBuffer, (uint16_t)len);
        free(theBuffer);
        if (!receipt) return 0;
    }
    return receipt;
}

@end

@implementation DESFriend (PrivateSetters)

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

@end
