#import "DeepEnd.h"
#import "DeepEnd-Private.h"
#import "DESFriend.h"
#import "Messenger.h"

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
        _contexts = [[NSMutableArray alloc] initWithCapacity:8];
    }
    return self;
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

- (void) CALLS_INTO_CORE_FUNCTIONS addFriendWithAddress:(NSString *)theKey message:(NSString *)theMessage {
    theKey = [theKey uppercaseString];
    if ([self friendWithPublicKey:[theKey substringToIndex:DESPublicKeySize * 2]]) {
        return;
    }
    DESFriend *existentRequest = nil;
    @synchronized(self) {
        for (DESFriend *theRequest in _requests) {
            if ([theRequest.friendAddress isEqualToString:theKey]) {
                existentRequest = theRequest;
                break;
            }
        }
    }
    if (existentRequest) {
        [self acceptRequestFromFriend:existentRequest];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DESFriendRequestArrayDidChangeNotification object:self];
        });
        return;
    }
    uint8_t *buffer = malloc(DESFriendAddressSize);
    DESConvertFriendAddressToData(theKey, buffer);
    int friendNumber = 0;
    @synchronized(self) {
        friendNumber = m_addfriend(self.connection.m, buffer, (uint8_t*)[theMessage UTF8String], [theMessage lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
        if (friendNumber > -1) {
            DESFriend *newFriend = [[DESFriend alloc] initWithNumber:friendNumber owner:self];
            newFriend.status = DESFriendStatusRequestSent;
            [_friends addObject:newFriend];
            dispatch_sync(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DESFriendArrayDidChangeNotification object:self];
            });
        }
    }
    free(buffer);
}

- (void)removeFriend:(DESFriend *)theFriend {
    @synchronized(self) {
        if ([_requests containsObject:theFriend]) {
            [_requests removeObject:theFriend];
        }
    }
    dispatch_sync(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DESFriendRequestArrayDidChangeNotification object:self];
    });
    if ([_friends containsObject:theFriend]) {
        @synchronized(self) {
            m_delfriend(self.connection.m, theFriend.friendNumber);
            [_friends removeObject:theFriend];
        }
        dispatch_sync(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DESFriendArrayDidChangeNotification object:self];
        });
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
        int friendID = m_addfriend_norequest(self.connection.m, buffer);
        if ([_requests containsObject:theFriend]) {
            [_requests removeObject:theFriend];
        }
        [_friends addObject:[theFriend initWithNumber:friendID owner:self]];
    }
    dispatch_sync(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DESFriendRequestArrayDidChangeNotification object:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:DESFriendArrayDidChangeNotification object:self];
    });
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
    dispatch_sync(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DESFriendRequestArrayDidChangeNotification object:self];
    });
}

- (DESFriend *)friendWithPublicKey:(NSString *)theKey {
    uint8_t *buffer = malloc(crypto_box_PUBLICKEYBYTES);
    DESConvertPublicKeyToData(theKey, buffer);
    int friendID = DESFriendInvalid;
    @synchronized(self) {
        friendID = getfriend_id(self.connection.m, buffer);
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
    return theFriend.chatContext;
}

- (NSArray *)chatContextsContainingFriend:(DESFriend *)theFriend {
    @synchronized(self) {
        return [_contexts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(DESChatContext *evaluatedObject, NSDictionary *bindings) {
            return [evaluatedObject.participants containsObject:theFriend];
        }]];
    }
}

- (void)addContext:(DESChatContext *)context {
    @synchronized(self) {
        context.friendManager = self;
        [_contexts addObject:context];
    }
}

- (void)didReceiveNewRequestWithAddress:(NSString *)theKey message:(NSString *)thePayload {
    DESFriend *newFriend = [DESFriend friendRequestWithAddress:theKey message:thePayload owner:self];
    [_requests addObject:newFriend];
    dispatch_sync(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DESFriendRequestArrayDidChangeNotification object:self];
    });
}

@end
