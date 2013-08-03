#import "DeepEnd.h"
#import "DESFriend.h"
#import "Messenger.h"

@interface DESFriend (PrivateSetters)

/* Implemented in DESFriend.m */
- (void)setDisplayName:(NSString *)displayName;
- (void)setUserStatus:(NSString *)userStatus;
- (void)setStatus:(DESFriendStatus)status;

@end

@implementation DESFriendManager {
    NSMutableArray *_friends;
    NSMutableArray *_blockedKeys;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _friends = [[NSMutableArray alloc] initWithCapacity:8];
        _blockedKeys = [[NSMutableArray alloc] initWithCapacity:8];
    }
    return self;
}

#pragma mark - NSCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        NSArray *friendArray = [aDecoder decodeObjectOfClass:[NSArray class] forKey:@"friends"];
        _friends = (NSMutableArray*)friendArray;
        NSArray *blockedKeys = [aDecoder decodeObjectOfClass:[NSArray class] forKey:@"blocked"];
        _blockedKeys = (NSMutableArray*)blockedKeys;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:(NSArray*)_friends forKey:@"friends"];
    [aCoder encodeObject:(NSArray*)_blockedKeys forKey:@"blocked"];
}

- (NSArray *)friends {
    /* An array of all friends who we have accepted the friend request for */
    return [_friends filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        switch (((DESFriend*)evaluatedObject).status) {
            case DESFriendStatusConfirmed: return YES;
            case DESFriendStatusOnline: return YES;
            case DESFriendStatusOffline: return YES;
            default: return NO;
        }
    }]];
}

- (NSArray *)requests {
    /* An array of all friends who are not yet confirmed (by us or them) */
    return [_friends filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        switch (((DESFriend*)evaluatedObject).status) {
            case DESFriendStatusRequestReceived: return YES;
            case DESFriendStatusRequestSent: return YES;
            default: return NO;
        }
    }]];
}

- (NSArray *)blockedKeys {
    return (NSArray*)[_blockedKeys copy];
}

- (void)addFriendWithPublicKey:(NSString *)theKey message:(NSString *)theMessage {
    if ([self friendWithPublicKey:theKey]) {
        return;
    }
    uint8_t *buffer = malloc(crypto_box_PUBLICKEYBYTES);
    DESConvertPublicKeyToData(theKey, buffer);
    int friendNumber = m_addfriend(buffer, (uint8_t*)[theMessage UTF8String], [theMessage lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    free(buffer);
    if (friendNumber > 0) {
        DESFriend *newFriend = [[DESFriend alloc] initWithNumber:friendNumber];
        newFriend.status = DESFriendStatusRequestSent;
        [_friends addObject:newFriend];
    }
}

- (void)removeFriend:(DESFriend *)theFriend {
    if ([_friends containsObject:theFriend]) {
        m_delfriend(theFriend.friendNumber);
    }
    [_friends removeObject:theFriend];
}

- (void)acceptRequestFromFriend:(DESFriend *)theFriend {
    uint8_t *buffer = malloc(crypto_box_PUBLICKEYBYTES);
    DESConvertPublicKeyToData(theFriend.publicKey, buffer);
    m_addfriend_norequest(buffer);
    theFriend.status = DESFriendStatusConfirmed;
    free(buffer);
}

- (DESFriend *)friendWithPublicKey:(NSString *)theKey {
    uint8_t *buffer = malloc(crypto_box_PUBLICKEYBYTES);
    DESConvertPublicKeyToData(theKey, buffer);
    int friendID = getfriend_id(buffer);
    free(buffer);
    return [self friendWithNumber:friendID];
}

- (DESFriend *)friendWithNumber:(int)theNumber {
    for (DESFriend *theFriend in self.friends) {
        if (theFriend.friendNumber == theNumber) {
            return theFriend;
        }
    }
    return nil;
}

@end
