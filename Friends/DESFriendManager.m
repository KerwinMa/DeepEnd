#import "DeepEnd.h"
#import "DeepEnd-Private.h"
#import "DESFriend.h"
#import "Messenger.h"

NSString *const DESDidReceiveMessageFromFriendNotification = @"DESDidReceiveMessageFromFriendNotification";
NSString *const DESFriendRequestArrayDidChangeNotification = @"DESFriendRequestArrayDidChangeNotification";
NSString *const DESFriendArrayDidChangeNotification = @"DESFriendArrayDidChangeNotification";

@implementation DESFriendManager {
    NSMutableArray *_friends;
    NSMutableArray *_requests;
    NSMutableArray *_blockedKeys;
    NSMutableArray *_contexts;
}

- (instancetype)init {
    self = [self initWithConnection:[DESToxNetworkConnection sharedConnection]];
    return self;
}

- (instancetype)initWithConnection:(DESToxNetworkConnection *)aConnection {
    self = [super init];
    if (self) {
        _connection = aConnection;
        _friends = [[NSMutableArray alloc] initWithCapacity:8];
        _requests = [[NSMutableArray alloc] initWithCapacity:8];
        _blockedKeys = [[NSMutableArray alloc] initWithCapacity:8];
    }
    return self;
}

#pragma mark - NSCoding
/* Warning: NSCoding methods are outdated, and not all data is saved.
 * Someday they may be updated, but for now, consider serializing data
 * yourself, or use Kudryavka.framework. */

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
    return (NSArray*)_friends;
}

- (NSArray *)requests {
    return (NSArray*)_requests;
}

- (NSArray *)blockedKeys {
    return (NSArray*)[_blockedKeys copy];
}

- (void) CALLS_INTO_CORE_FUNCTIONS addFriendWithPublicKey:(NSString *)theKey message:(NSString *)theMessage {
    if ([self friendWithPublicKey:theKey]) {
        return;
    }
    uint8_t *buffer = malloc(crypto_box_PUBLICKEYBYTES);
    DESConvertPublicKeyToData(theKey, buffer);
    int friendNumber = 0;
    @synchronized(self) {
        friendNumber = m_addfriend(buffer, (uint8_t*)[theMessage UTF8String], [theMessage lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
        if (friendNumber > 0) {
            DESFriend *newFriend = [[DESFriend alloc] initWithNumber:friendNumber owner:self];
            newFriend.status = DESFriendStatusRequestSent;
            [_friends addObject:newFriend];
        }
    }
    free(buffer);
}

- (void)removeFriend:(DESFriend *)theFriend {
    if ([_friends containsObject:theFriend]) {
        @synchronized(self) {
            m_delfriend(theFriend.friendNumber);
            [_friends removeObject:theFriend];
        }
        [_contexts filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            if ([((DESChatContext*)evaluatedObject).participants containsObject:theFriend]) {
                [evaluatedObject removeParticipant:theFriend];
                return [((DESChatContext*)evaluatedObject).participants count] != 0;
            }
            return YES;
        }]];
    }
}

- (void)acceptRequestFromFriend:(DESFriend *)theFriend {
    if (theFriend.status != DESFriendStatusRequestReceived)
        return; /* We can't accept this because it is not a request. */
    uint8_t *buffer = malloc(crypto_box_PUBLICKEYBYTES);
    DESConvertPublicKeyToData(theFriend.publicKey, buffer);
    @synchronized(self) {
        int friendID = m_addfriend_norequest(buffer);
        if ([_requests containsObject:theFriend]) {
            [_requests removeObject:theFriend];
        }
        [_friends addObject:[theFriend initWithNumber:friendID owner:self]];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:DESFriendRequestArrayDidChangeNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:DESFriendArrayDidChangeNotification object:self];
    free(buffer);
}

- (void)rejectRequestFromFriend:(DESFriend *)theFriend {
    if (theFriend.status != DESFriendStatusRequestReceived)
        return; /* We can't accept this because it is not a request. */
    @synchronized(self) {
        if ([_requests containsObject:theFriend]) {
            [_requests removeObject:theFriend];
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:DESFriendRequestArrayDidChangeNotification object:self];
}

- (DESFriend *)friendWithPublicKey:(NSString *)theKey {
    uint8_t *buffer = malloc(crypto_box_PUBLICKEYBYTES);
    DESConvertPublicKeyToData(theKey, buffer);
    int friendID = DESFriendInvalid;
    @synchronized(self) {
        friendID = getfriend_id(buffer);
    }
    free(buffer);
    return [self friendWithNumber:friendID];
}

- (DESFriend *)friendWithNumber:(int)theNumber {
    if (theNumber == DESFriendInvalid)
        return nil;
    if (theNumber == DESFriendSelf)
        return [DESSelf selfWithConnection:self.connection];
    @synchronized(self) {
        for (DESFriend *theFriend in _friends) {
            if (theFriend.friendNumber == theNumber) {
                return theFriend;
            }
        }
        return nil;
    }
}

- (DESChatContext *)chatContextForFriend:(DESFriend *)theFriend {
    DESChatContext *ctx = nil;
    @synchronized(self) {
        for (DESChatContext *actx in _contexts) {
            if (ctx.isPersonalChatContext && [actx.participants containsObject:theFriend]) {
                ctx = actx;
                break;
            }
        }
    }
    return ctx;
}

- (NSArray *)chatContextsContainingFriend:(DESFriend *)theFriend {
    @synchronized(self) {
        return [_contexts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(DESChatContext *evaluatedObject, NSDictionary *bindings) {
            return [evaluatedObject.participants containsObject:theFriend];
        }]];
    }
}

- (void)didReceiveNewRequestWithKey:(NSString *)theKey message:(NSString *)thePayload {
    DESFriend *newFriend = [DESFriend friendRequestWithKey:theKey message:thePayload owner:self];
    [_requests addObject:newFriend];
    [[NSNotificationCenter defaultCenter] postNotificationName:DESFriendRequestArrayDidChangeNotification object:self];
}

@end
