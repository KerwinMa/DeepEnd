#import "DeepEnd.h"
#import "DeepEnd-Private.h"
#import "DESToxNetworkConnection.h"
#import "DESFriendManager.h"
#import "DESSelf.h"
#import "DESGroupChatContext.h"
#import "DESGroupPeer.h"
#import "tox.h"
#import "Messenger.h"
#include <netinet/in.h>

#ifndef DISPATCH_TIMER_STRICT
#define DISPATCH_TIMER_STRICT 0x1
#endif

static DESToxNetworkConnection *sharedInstance = nil;

/* Declaration of constants in DeepEnd.h. */

NSString *const DESConnectionDidInitNotification = @"DESConnectionDidInitNotification";
NSString *const DESConnectionDidConnectNotification = @"DESConnectionDidConnectNotification";
NSString *const DESConnectionDidFailNotification = @"DESConnectionDidFailNotification";
NSString *const DESConnectionDidTerminateNotification = @"DESConnectionDidTerminateNotification";

/* This one is related to the DESChatContext protocol. */
NSString *const DESDidPushMessageToContextNotification = @"DESDidPushMessageToContextNotification";

DESFriendStatus __DESCoreStatusToDESStatus(int theStatus) {
    switch (theStatus) {
        case FRIEND_ONLINE:
            return DESFriendStatusOnline;
        case FRIEND_CONFIRMED:
            return DESFriendStatusConfirmed;
        case FRIEND_REQUESTED:
            return DESFriendStatusRequestSent;
        case FRIEND_ADDED:
            return DESFriendStatusRequestSent;
        default:
            return DESFriendStatusOffline;
    }
}

@implementation DESToxNetworkConnection {
    #ifndef DES_USES_EXPERIMENTAL_RUN_LOOP
    dispatch_source_t messengerTick;
    #endif
    DESFriendManager *_friendManager;
    DESSelf *_currentUser;
    NSDate *bootstrapStartTime;
    BOOL wasConnected;
}

- (instancetype) CALLS_INTO_CORE_FUNCTIONS init {
    self = [super init];
    if (self) {
        _messengerQueue = dispatch_queue_create("ca.kirara.DESRunLoop", NULL);
        _runLoopSpeed = DEFAULT_MESSENGER_TICK_RATE;
        wasConnected = NO;
        #ifndef DES_USES_EXPERIMENTAL_RUN_LOOP
        if (!messengerTick)
            [self createTick];
        #endif
    }
    return self;
}

- (void)createTick {
    if (NSFoundationVersionNumber > 993.00)
        messengerTick = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, DISPATCH_TIMER_STRICT, _messengerQueue);
    else
        messengerTick = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _messengerQueue);
    dispatch_source_set_timer(messengerTick, dispatch_walltime(NULL, 0), DEFAULT_MESSENGER_TICK_RATE * NSEC_PER_SEC, (1.0 / 10.0) * NSEC_PER_SEC);
    dispatch_source_set_event_handler(messengerTick, ^{
        tox_do(self.m);
        if (!wasConnected && [self connected]) {
            /* DHT bootstrap succeeded... */
            dispatch_sync(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DESConnectionDidConnectNotification object:self];
            });
        } else if (![self connected] && floor([bootstrapStartTime timeIntervalSinceNow] * -1.0) > 5.0) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DESConnectionDidFailNotification object:self];
            });
        }
        NSInteger cn = __DESGetNumberOfConnectedNodes(self.m);
        if (cn != [_connectedNodeCount integerValue]) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self willChangeValueForKey:@"connectedNodeCount"];
                _connectedNodeCount = [NSNumber numberWithInteger:cn];
                [self didChangeValueForKey:@"connectedNodeCount"];
            });
        }
        __DESEnumerateFriendStatusesUsingBlock(self.m, ^(int idx, int status, char *stop) {
            DESFriend *theFriend = [self.friendManager friendWithNumber:idx];
            if (theFriend.status != __DESCoreStatusToDESStatus(status)) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    theFriend.status = __DESCoreStatusToDESStatus(status);
                });
            }
        });
    });
}

#ifdef DES_USES_EXPERIMENTAL_RUN_LOOP
- (void)runToxLoopIteration {
    struct timeval waitTime;
    waitTime.tv_sec = 0;
    waitTime.tv_usec = 50000.0;
    fd_set read_set;
    FD_ZERO(&read_set);
    FD_SET(((Messenger*)self.m)->net->sock, &read_set);
    int ret = select(((Messenger*)self.m)->net->sock + 1, &read_set, NULL, NULL, &waitTime);
    if (ret != -1) {
        dispatch_async(self.messengerQueue, ^{
            tox_do(self.m);
            if (!wasConnected && [self connected]) {
                /* DHT bootstrap succeeded... */
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DESConnectionDidConnectNotification object:self];
                });
            } else if (![self connected] && floor([bootstrapStartTime timeIntervalSinceNow] * -1.0) > 5.0) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DESConnectionDidFailNotification object:self];
                });
            }
            NSInteger cn = __DESGetNumberOfConnectedNodes(self.m);
            if (cn != [_connectedNodeCount integerValue]) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [self willChangeValueForKey:@"connectedNodeCount"];
                    _connectedNodeCount = [NSNumber numberWithInteger:cn];
                    [self didChangeValueForKey:@"connectedNodeCount"];
                });
            }
            __DESEnumerateFriendStatusesUsingBlock(self.m, ^(int idx, int status, char *stop) {
                DESFriend *theFriend = [self.friendManager friendWithNumber:idx];
                if (theFriend.status != __DESCoreStatusToDESStatus(status)) {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        theFriend.status = __DESCoreStatusToDESStatus(status);
                    });
                }
            });
        });
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self runToxLoopIteration];
    });
}
#endif

+ (instancetype)sharedConnection {
    if (!sharedInstance) {
        sharedInstance = [[DESToxNetworkConnection alloc] init];
    }
    return sharedInstance;
}

- (DESFriendManager *)friendManager {
    return _friendManager;
}

- (DESSelf *)me {
    return _currentUser;
}

- (BOOL)connected {
    return [self.connectedNodeCount integerValue] > 0;
}

- (void)setRunLoopSpeed:(double)runLoopSpeed {
    #ifndef DES_USES_EXPERIMENTAL_RUN_LOOP
    if (runLoopSpeed <= 0.0) {
        [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"The runloop speed cannot be less than zero. You tried to set it to %f.", runLoopSpeed] userInfo:@{@"offendingValue": @(runLoopSpeed)}];
        return;
    }
    _runLoopSpeed = runLoopSpeed;
    if (!messengerTick)
        [self createTick];
    dispatch_source_set_timer(messengerTick, dispatch_walltime(NULL, 0), runLoopSpeed * NSEC_PER_SEC, 0.5 * NSEC_PER_SEC);
    DESDebug(@"%@: new runLoopSpeed is %f.", self, runLoopSpeed);
    #else
    DESDebug(@"Using experimental run loop, so not setting runLoopSpeed.");
    #endif
}

- (void) CALLS_INTO_CORE_FUNCTIONS setPrivateKey:(NSString *)thePrivateKey publicKey:(NSString *)thePublicKey {
    dispatch_sync(_messengerQueue, ^{
        [self willChangeValueForKey:@"privateKey"];
        [self willChangeValueForKey:@"publicKey"];
        DESConvertPrivateKeyToData(thePrivateKey, ((Messenger*)self.m)->net_crypto->self_secret_key);
        DESConvertPublicKeyToData(thePublicKey, ((Messenger*)self.m)->net_crypto->self_public_key);
        [self didChangeValueForKey:@"privateKey"];
        [self didChangeValueForKey:@"publicKey"];
    });
}

- (void) CALLS_INTO_CORE_FUNCTIONS connect {
    if (!messengerTick)
        [self createTick];
    dispatch_sync(_messengerQueue, ^{
        _m = tox_new(TOX_ENABLE_IPV6_DEFAULT);
        tox_callback_friend_message(self.m, __DESCallbackMessage, (__bridge void*)self);
        tox_callback_friend_request(self.m, __DESCallbackFriendRequest, (__bridge void*)self);
        tox_callback_name_change(self.m, __DESCallbackNameChange, (__bridge void*)self);
        tox_callback_status_message(self.m, __DESCallbackUserStatus, (__bridge void*)self);
        tox_callback_user_status(self.m, __DESCallbackUserStatusKind, (__bridge void*)self);
        tox_callback_friend_action(self.m, __DESCallbackAction, (__bridge void*)self);
        tox_callback_group_message(self.m, __DESCallbackGroupMessage, (__bridge void*)self);
        tox_callback_group_action(self.m, __DESCallbackGroupAction, (__bridge void*)self);
        tox_callback_group_invite(self.m, __DESCallbackGroupInvite, (__bridge void*)self);
        _friendManager = [[DESFriendManager alloc] initWithConnection:self];
        _currentUser = [[DESSelf alloc] init];
        _currentUser.owner = self.friendManager;
    });
    [[NSNotificationCenter defaultCenter] postNotificationName:DESConnectionDidInitNotification object:self];
    #ifdef DES_USES_EXPERIMENTAL_RUN_LOOP
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self runToxLoopIteration];
    });
    #else
    dispatch_resume(messengerTick);
    #endif
}

- (void) CALLS_INTO_CORE_FUNCTIONS bootstrapWithAddress:(NSString *)theAddress port:(NSInteger)thePort publicKey:(NSString *)theKey {
    dispatch_async(_messengerQueue, ^{
        uint8_t *theData = malloc(DESPublicKeySize);
        DESConvertPublicKeyToData(theKey, theData);
        bootstrapStartTime = [NSDate date];
        tox_bootstrap_from_address(self.m, [theAddress UTF8String], 1, htons(thePort), theData);
        free(theData);
    });
}

- (void)connectWithBootstrapAddress:(NSString *)theAddress port:(NSInteger)thePort publicKey:(NSString *)theKey {
    [self connect];
    [self bootstrapWithAddress:theAddress port:thePort publicKey:theKey];
}

- (void)disconnect {
    #ifndef DES_USES_EXPERIMENTAL_RUN_LOOP
    dispatch_source_cancel(messengerTick);
    dispatch_release(messengerTick);
    messengerTick = nil;
    #endif
    [[self.friendManager.friends copy] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self.friendManager removeFriend:obj];
    }];
    [[self.friendManager.chatContexts copy] enumerateObjectsUsingBlock:^(id<DESChatContext> obj, NSUInteger idx, BOOL *stop) {
        if ([obj type] == DESContextTypeGroupChat) {
            [self.friendManager removeGroupChat:obj];
        }
    }];
    _friendManager = nil;
    _currentUser = nil;
    _connectedNodeCount = @(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DESConnectionDidTerminateNotification object:self];
    });
}

- (void)dealloc {
    #ifndef DES_USES_EXPERIMENTAL_RUN_LOOP
    dispatch_source_cancel(messengerTick);
    dispatch_release(messengerTick);
    #endif
    dispatch_release(_messengerQueue);
    tox_kill(_m);
}

@end

/* Callbacks begin */

void __DESCallbackFriendRequest(Tox *m, uint8_t *publicKey, uint8_t *payload, uint16_t length, void *context) {
    NSString *theKey = DESConvertPublicKeyToString(publicKey);
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    [((__bridge DESToxNetworkConnection*)context).friendManager didReceiveNewRequestWithAddress:theKey message:thePayload];
}

void __DESCallbackNameChange(Tox *m, int friend, uint8_t *payload, uint16_t length, void *context) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESFriend *theFriend = [((__bridge DESToxNetworkConnection*)context).friendManager friendWithNumber:friend];
    [theFriend.chatContext pushMessage:[DESMessage nickChangeFromSender:theFriend newNick:thePayload]];
    dispatch_sync(dispatch_get_main_queue(), ^{
        theFriend.displayName = thePayload;
    });
}

void __DESCallbackUserStatusKind(Tox *m, int32_t friend, uint8_t kind, void *context) {
    DESFriend *theFriend = [((__bridge DESToxNetworkConnection*)context).friendManager friendWithNumber:friend];
    [theFriend.chatContext pushMessage:[DESMessage userStatusTypeChangeFromSender:theFriend newStatusType:(DESStatusType)kind]];
    dispatch_sync(dispatch_get_main_queue(), ^{
        theFriend.statusType = (DESStatusType)kind;
    });
}

void __DESCallbackUserStatus(Tox *m, int friend, uint8_t *payload, uint16_t length, void *context) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESFriend *theFriend = [((__bridge DESToxNetworkConnection*)context).friendManager friendWithNumber:friend];
    [theFriend.chatContext pushMessage:[DESMessage userStatusChangeFromSender:theFriend newStatus:thePayload]];
    dispatch_sync(dispatch_get_main_queue(), ^{
        theFriend.userStatus = thePayload;
    });
}

void __DESCallbackMessage(Tox *m, int friend, uint8_t *payload, uint16_t length, void *context) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESFriend *theFriend = [((__bridge DESToxNetworkConnection*)context).friendManager friendWithNumber:friend];
    DESMessage *theMessage = [DESMessage messageFromSender:theFriend content:thePayload messageID:-1];
    [theFriend.chatContext pushMessage:theMessage];
}

void __DESCallbackAction(Tox *m, int friend, uint8_t *payload, uint16_t length, void *context) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESFriend *theFriend = [((__bridge DESToxNetworkConnection*)context).friendManager friendWithNumber:friend];
    DESMessage *theMessage = [DESMessage actionFromSender:theFriend content:thePayload];
    [theFriend.chatContext pushMessage:theMessage];
}

void __DESCallbackGroupMessage(Tox *m, int groupnumber, int peernum, uint8_t *payload, uint16_t length, void *context) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESGroupChatContext *theGroup = nil;
    for (id<DESChatContext> ctx in ((__bridge DESToxNetworkConnection*)context).friendManager.chatContexts) {
        if ([ctx isKindOfClass:[DESGroupChatContext class]] && ((DESGroupChatContext*)ctx).groupNumber == groupnumber) {
            theGroup = ctx;
            break;
        }
    }
    if (!theGroup)
        return;
    DESGroupPeer *friend = [theGroup peerWithID:peernum];
    DESMessage *theMessage = [DESMessage messageFromSender:friend content:thePayload messageID:-1];
    [theGroup pushMessage:theMessage];
}

void __DESCallbackGroupAction(Tox *tox, int groupnumber, int peernum, uint8_t *payload, uint16_t length, void *context) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESGroupChatContext *theGroup = nil;
    for (id<DESChatContext> ctx in ((__bridge DESToxNetworkConnection*)context).friendManager.chatContexts) {
        if ([ctx isKindOfClass:[DESGroupChatContext class]] && ((DESGroupChatContext*)ctx).groupNumber == groupnumber) {
            theGroup = ctx;
            break;
        }
    }
    if (!theGroup)
        return;
    DESGroupPeer *friend = [theGroup peerWithID:peernum];
    DESMessage *theMessage = [DESMessage actionFromSender:friend content:thePayload];
    [theGroup pushMessage:theMessage];
}

void __DESCallbackGroupInvite(Tox *tox, int friend, uint8_t *group_public_key, void *context) {
    NSString *theKey = DESConvertPublicKeyToString(group_public_key);
    DESFriendManager *fm = ((__bridge DESToxNetworkConnection*)context).friendManager;
    [fm didReceiveNewGroupRequestWithKey:theKey inviter:[fm friendWithNumber:friend]];
}
