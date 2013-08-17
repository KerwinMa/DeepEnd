#import "DeepEnd.h"
#import "DeepEnd-Private.h"
#import "DESToxNetworkConnection.h"
#import "DESFriendManager.h"
#import "DESSelf.h"
#import "Messenger.h"
#include <arpa/inet.h>

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
    dispatch_source_t messengerTick;
    DESFriendManager *_friendManager;
    DESSelf *_currentUser;
    NSDate *bootstrapStartTime;
    BOOL wasConnected;
}

+ (void)initialize {
    if (!sharedInstance) {
        sharedInstance = [[DESToxNetworkConnection alloc] init];
    }
}

- (instancetype) CALLS_INTO_CORE_FUNCTIONS init {
    self = [super init];
    if (self) {
        _messengerQueue = dispatch_queue_create("ca.kirara.DESRunLoop", NULL);
        messengerTick = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _messengerQueue);
        dispatch_source_set_timer(messengerTick, dispatch_walltime(NULL, 0), MESSENGER_TICK_RATE * NSEC_PER_SEC, 0.5 * NSEC_PER_SEC);
        wasConnected = NO;
        _friendManager = [[DESFriendManager alloc] initWithConnection:self];
        dispatch_source_set_event_handler(messengerTick, ^{
            doMessenger(self.m);
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
            NSInteger cn = __DESGetNumberOfConnectedNodes();
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
    return self;
}

+ (instancetype)sharedConnection {
    return sharedInstance;
}

- (DESFriendManager *)friendManager {
    return _friendManager;
}

- (DESSelf *)me {
    return _currentUser;
}

- (BOOL)connected {
    return DHT_isconnected();
}

- (void) CALLS_INTO_CORE_FUNCTIONS setPrivateKey:(NSString *)thePrivateKey publicKey:(NSString *)thePublicKey {
    dispatch_sync(_messengerQueue, ^{
        [self willChangeValueForKey:@"privateKey"];
        [self willChangeValueForKey:@"publicKey"];
        DESConvertPrivateKeyToData(thePrivateKey, self_secret_key);
        DESConvertPublicKeyToData(thePublicKey, self_public_key);
        [self didChangeValueForKey:@"privateKey"];
        [self didChangeValueForKey:@"publicKey"];
    });
}

- (void) CALLS_INTO_CORE_FUNCTIONS connect {
    dispatch_sync(_messengerQueue, ^{
        _m = initMessenger();
        m_callback_friendmessage(self.m, __DESCallbackMessage, (__bridge void*)self);
        m_callback_friendrequest(self.m, __DESCallbackFriendRequest, (__bridge void*)self);
        m_callback_namechange(self.m, __DESCallbackNameChange, (__bridge void*)self);
        m_callback_statusmessage(self.m, __DESCallbackUserStatus, (__bridge void*)self);
        m_callback_userstatus(self.m, __DESCallbackUserStatusKind, (__bridge void*)self);
        m_callback_connectionstatus(self.m, __DESCallbackFriendStatus, (__bridge void*)self);
        m_callback_action(self.m, __DESCallbackAction, (__bridge void*)self);
        _currentUser = [[DESSelf alloc] init];
        _currentUser->owner = self.friendManager;
    });
    [[NSNotificationCenter defaultCenter] postNotificationName:DESConnectionDidInitNotification object:self];
    dispatch_resume(messengerTick);
}

- (void) CALLS_INTO_CORE_FUNCTIONS bootstrapWithAddress:(NSString *)theAddress port:(NSInteger)thePort publicKey:(NSString *)theKey {
    dispatch_sync(_messengerQueue, ^{
        IP_Port bootstrapInfo;
        bootstrapInfo.ip.i = inet_addr([theAddress UTF8String]);
        bootstrapInfo.port = htons(thePort);
        bootstrapInfo.padding = 0;
        uint8_t *theData = malloc(crypto_box_PUBLICKEYBYTES);
        DESConvertPublicKeyToData(theKey, theData);
        bootstrapStartTime = [NSDate date];
        DHT_bootstrap(bootstrapInfo, theData);
        free(theData);
    });
}

- (void)connectWithBootstrapAddress:(NSString *)theAddress port:(NSInteger)thePort publicKey:(NSString *)theKey {
    [self connect];
    [self bootstrapWithAddress:theAddress port:thePort publicKey:theKey];
}

- (void)disconnect {
    dispatch_source_cancel(messengerTick);
    dispatch_sync(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DESConnectionDidTerminateNotification object:self];
    });
}

- (void)dealloc {
    cleanupMessenger(_m);
}

@end

/* Callbacks begin */

void __DESCallbackFriendRequest(uint8_t *publicKey, uint8_t *payload, uint16_t length, void *context) {
    NSString *theKey = DESConvertPublicKeyToString(publicKey);
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    [((__bridge DESToxNetworkConnection*)context).friendManager didReceiveNewRequestWithAddress:theKey message:thePayload];
}

void __DESCallbackNameChange(Messenger *m, int friend, uint8_t *payload, uint16_t length, void *context) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESFriend *theFriend = [((__bridge DESToxNetworkConnection*)context).friendManager friendWithNumber:friend];
    [theFriend.chatContext pushMessage:[DESMessage nickChangeFromSender:theFriend newNick:thePayload]];
    dispatch_sync(dispatch_get_main_queue(), ^{
        theFriend.displayName = thePayload;
    });
}

void __DESCallbackUserStatusKind(Messenger *m, int friend, USERSTATUS kind, void *context) {
    DESFriend *theFriend = [((__bridge DESToxNetworkConnection*)context).friendManager friendWithNumber:friend];
    [theFriend.chatContext pushMessage:[DESMessage userStatusTypeChangeFromSender:theFriend newStatusType:(DESStatusType)kind]];
    dispatch_sync(dispatch_get_main_queue(), ^{
        theFriend.statusType = (DESStatusType)kind;
    });
}

void __DESCallbackUserStatus(Messenger *m, int friend, uint8_t *payload, uint16_t length, void *context) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESFriend *theFriend = [((__bridge DESToxNetworkConnection*)context).friendManager friendWithNumber:friend];
    [theFriend.chatContext pushMessage:[DESMessage userStatusChangeFromSender:theFriend newStatus:thePayload]];
    dispatch_sync(dispatch_get_main_queue(), ^{
        theFriend.userStatus = thePayload;
    });
}

void __DESCallbackMessage(Messenger *m, int friend, uint8_t *payload, uint16_t length, void *context) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESFriend *theFriend = [((__bridge DESToxNetworkConnection*)context).friendManager friendWithNumber:friend];
    DESMessage *theMessage = [DESMessage messageFromSender:theFriend content:thePayload messageID:-1];
    [theFriend.chatContext pushMessage:theMessage];
}

void __DESCallbackAction(Messenger *m, int friend, uint8_t *payload, uint16_t length, void *context) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESFriend *theFriend = [((__bridge DESToxNetworkConnection*)context).friendManager friendWithNumber:friend];
    DESMessage *theMessage = [DESMessage actionFromSender:theFriend content:thePayload];
    [theFriend.chatContext pushMessage:theMessage];
}

void __DESCallbackFriendStatus(Messenger *m, int friend, uint8_t status, void *context) {
    
}
