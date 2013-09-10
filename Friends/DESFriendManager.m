#import "DeepEnd.h"
#import "DeepEnd-Private.h"
#import "DESFriend.h"
#import "tox.h"

NSString *const DESFriendAddErrorDomain = @"DESFriendAddErrorDomain";
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

- (DESFriend *)addFriendWithAddress:(NSString *)theKey message:(NSString *)theMessage {
    return [self addFriendWithAddress:theKey message:theMessage error:nil];
}

- (DESFriend *) CALLS_INTO_CORE_FUNCTIONS addFriendWithAddress:(NSString *)theKey message:(NSString *)theMessage error:(NSError *__autoreleasing *)err {
    theKey = [theKey uppercaseString];
    if ([self friendWithPublicKey:[theKey substringToIndex:DESPublicKeySize * 2]]) {
        if (err) {
            *err = [[NSError alloc] initWithDomain:DESFriendAddErrorDomain code:DESFriendAddResultAlreadySent userInfo:@{@"theKey": theKey}];
        }
        return nil;
    }
    @synchronized(self) {
        DESFriend *existentRequest = nil;
        for (DESFriend *theRequest in _requests) {
            if ([theRequest.publicKey isEqualToString:theKey]) {
                existentRequest = theRequest;
                break;
            }
        }
        if (existentRequest) {
            return [self acceptRequestFromFriend:existentRequest];
        }
    }
    uint8_t *buffer = malloc(DESFriendAddressSize);
    DESConvertFriendAddressToData(theKey, buffer);
    int friendNumber = 0;
    DESFriend *newFriend;
    @synchronized(self) {
        friendNumber = tox_addfriend(self.connection.m, buffer, (uint8_t*)[theMessage UTF8String], [theMessage lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
        if (friendNumber > -1) {
            newFriend = [[DESFriend alloc] initWithNumber:friendNumber owner:self];
            newFriend.status = DESFriendStatusRequestSent;
            [_friends addObject:newFriend];
            NSNotification *theNotification = [NSNotification notificationWithName:DESFriendArrayDidChangeNotification object:self userInfo:@{DESArrayOperationKey: DESArrayOperationTypeAdd, DESArrayFriendKey: newFriend}];
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:theNotification waitUntilDone:YES];
            if (err) {
                *err = nil;
            }
        } else {
            if (err) {
                *err = [[NSError alloc] initWithDomain:DESFriendAddErrorDomain code:friendNumber userInfo:@{@"theKey": theKey}];
            }
        }
    }
    free(buffer);
    return newFriend;
}

- (DESFriend *)addFriendWithoutRequest:(NSString *)theKey {
    if (!DESPublicKeyIsValid(theKey)) {
        return nil;
    }
    @synchronized(self) {
        DESFriend *existentRequest = nil;
        for (DESFriend *theRequest in _requests) {
            if ([theRequest.publicKey isEqualToString:theKey]) {
                existentRequest = theRequest;
                break;
            }
        }
        if (existentRequest) {
            return [self acceptRequestFromFriend:existentRequest];
        }
    }
    uint8_t *buffer = malloc(DESPublicKeySize);
    DESConvertPublicKeyToData(theKey, buffer);
    int success = tox_addfriend_norequest(self.connection.m, buffer);
    free(buffer);
    if (success < 0) {
        return nil;
    } else {
        DESFriend *newFriend = [[DESFriend alloc] initWithNumber:success owner:self];
        newFriend.status = DESFriendStatusOffline;
        [_friends addObject:newFriend];
        NSNotification *theNotification = [NSNotification notificationWithName:DESFriendArrayDidChangeNotification object:self userInfo:@{DESArrayOperationKey: DESArrayOperationTypeAdd, DESArrayFriendKey: newFriend}];
        [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:theNotification waitUntilDone:YES];
        return newFriend;
    }
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
            }
            return YES;
        }]];
        [_contexts removeObject:theFriend.chatContext];
        @synchronized(theFriend.chatContext) {
            for (DESMessage *m in theFriend.chatContext.backlog) {
                m.sender = nil;
            }
        }
        theFriend.chatContext = nil;
        theFriend.owner = nil;
    }
}

- (DESFriend *) CALLS_INTO_CORE_FUNCTIONS acceptRequestFromFriend:(DESFriend *)theFriend {
    if (theFriend.status != DESFriendStatusRequestReceived)
        return nil; /* We can't accept this because it is not a request. */
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
    return theFriend;
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

- (DESFriend *)requestWithPublicKey:(NSString *)theKey {
    if (!DESPublicKeyIsValid(theKey))
        return nil;
    @synchronized(self) {
        for (DESFriend *theRequest in _requests) {
            if ([theRequest.publicKey isEqualToString:theKey]) {
                return theRequest;
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

- (id<DESChatContext>)chatContextWithUUID:(NSString *)uuid {
    @synchronized(self) {
        for (id<DESChatContext> i in _contexts) {
            if ([i.uuid isEqualToString:uuid]) {
                return i;
            }
        }
    }
    return nil;
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
