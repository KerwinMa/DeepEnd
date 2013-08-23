#import "DeepEnd.h"
#import "DeepEnd-Private.h"
#import "DESFriend.h"
#import "tox.h"

NSString *const DESFriendRequestArrayDidChangeNotification = @"DESFriendRequestArrayDidChangeNotification";
NSString *const DESFriendArrayDidChangeNotification = @"DESFriendArrayDidChangeNotification";

NSString *const DESArrayOperationKey = @"operation";
NSString *const DESArrayFriendKey = @"friend";

NSString *const DESArrayOperationTypeAdd = @"add";
NSString *const DESArrayOperationTypeRemove = @"remove";

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
        return;
    }
    uint8_t *buffer = malloc(DESFriendAddressSize);
    DESConvertFriendAddressToData(theKey, buffer);
    int friendNumber = 0;
    @synchronized(self) {
        friendNumber = tox_addfriend(self.connection.m, buffer, (uint8_t*)[theMessage UTF8String], [theMessage lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
        if (friendNumber > -1) {
            DESFriend *newFriend = [[DESFriend alloc] initWithNumber:friendNumber owner:self];
            newFriend.status = DESFriendStatusRequestSent;
            [_friends addObject:newFriend];
            NSNotification *theNotification = [NSNotification notificationWithName:DESFriendArrayDidChangeNotification object:self userInfo:@{DESArrayOperationKey: DESArrayOperationTypeAdd, DESArrayFriendKey: newFriend}];
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:theNotification waitUntilDone:YES];
        }
    }
    free(buffer);
}

- (void)removeFriend:(DESFriend *)theFriend {
    if ([_requests containsObject:theFriend]) {
        @synchronized(self) {
            [_requests removeObject:theFriend];
        }
        NSNotification *theNotification = [NSNotification notificationWithName:DESFriendRequestArrayDidChangeNotification object:self userInfo:@{DESArrayOperationKey: DESArrayOperationTypeRemove, DESArrayFriendKey: theFriend}];
        [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:theNotification waitUntilDone:YES];
    }
    if ([_friends containsObject:theFriend]) {
        @synchronized(self) {
            tox_delfriend(self.connection.m, theFriend.friendNumber);
            [_friends removeObject:theFriend];
        }
        NSNotification *theNotification = [NSNotification notificationWithName:DESFriendArrayDidChangeNotification object:self userInfo:@{DESArrayOperationKey: DESArrayOperationTypeRemove, DESArrayFriendKey: theFriend}];
        [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:theNotification waitUntilDone:YES];
        [_contexts filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            if ([((id<DESChatContext>)evaluatedObject).participants containsObject:theFriend]) {
                [evaluatedObject removeParticipant:theFriend];
                return [((id<DESChatContext>)evaluatedObject).participants count] != 0;
            }
            return YES;
        }]];
    }
}

- (void)acceptRequestFromFriend:(DESFriend *)theFriend {
    if (theFriend.status != DESFriendStatusRequestReceived)
        return; /* We can't accept this because it is not a request. */
    uint8_t *buffer = malloc(DESPublicKeySize);
    DESConvertPublicKeyToData(theFriend.publicKey, buffer);
    @synchronized(self) {
        int friendID = tox_addfriend_norequest(self.connection.m, buffer);
        if ([_requests containsObject:theFriend]) {
            [_requests removeObject:theFriend];
        }
        [_friends addObject:[theFriend initWithNumber:friendID owner:self]];
    }
    NSNotification *theNotification = [NSNotification notificationWithName:DESFriendRequestArrayDidChangeNotification object:self userInfo:@{DESArrayOperationKey: DESArrayOperationTypeRemove, DESArrayFriendKey: theFriend}];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:theNotification waitUntilDone:YES];
    theNotification = [NSNotification notificationWithName:DESFriendArrayDidChangeNotification object:self userInfo:@{DESArrayOperationKey: DESArrayOperationTypeAdd, DESArrayFriendKey: theFriend}];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:theNotification waitUntilDone:YES];
    free(buffer);
}

- (void)rejectRequestFromFriend:(DESFriend *)theFriend {
    if (theFriend.status != DESFriendStatusRequestReceived)
        return; /* We can't accept this because it is not a request. */
    if ([_requests containsObject:theFriend]) {
        @synchronized(self) {
            [_requests removeObject:theFriend];
        }
        NSNotification *theNotification = [NSNotification notificationWithName:DESFriendRequestArrayDidChangeNotification object:self userInfo:@{DESArrayOperationKey: DESArrayOperationTypeRemove, DESArrayFriendKey: theFriend}];
        [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:theNotification waitUntilDone:YES];
    }
}

- (DESFriend *)friendWithPublicKey:(NSString *)theKey {
    uint8_t *buffer = malloc(DESPublicKeySize);
    DESConvertPublicKeyToData(theKey, buffer);
    int friendID = DESFriendInvalid;
    @synchronized(self) {
        friendID = tox_getfriend_id(self.connection.m, buffer);
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

- (id<DESChatContext>)chatContextForFriend:(DESFriend *)theFriend {
    return theFriend.chatContext;
}

- (NSArray *)chatContextsContainingFriend:(DESFriend *)theFriend {
    @synchronized(self) {
        return [_contexts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id<DESChatContext> evaluatedObject, NSDictionary *bindings) {
            return [evaluatedObject.participants containsObject:theFriend];
        }]];
    }
}

- (void)addContext:(id<DESChatContext>)context {
    @synchronized(self) {
        context.friendManager = self;
        [_contexts addObject:context];
    }
}

- (void)didReceiveNewRequestWithAddress:(NSString *)theKey message:(NSString *)thePayload {
    DESFriend *newFriend = [DESFriend friendRequestWithAddress:theKey message:thePayload owner:self];
    [_requests addObject:newFriend];
    NSNotification *theNotification = [NSNotification notificationWithName:DESFriendRequestArrayDidChangeNotification object:self userInfo:@{DESArrayOperationKey: DESArrayOperationTypeAdd, DESArrayFriendKey: newFriend}];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:theNotification waitUntilDone:YES];
}

@end
