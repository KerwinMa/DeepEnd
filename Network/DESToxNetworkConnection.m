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

#define FRIEND_ONLINE 4
#define FRIEND_CONFIRMED 3
#define FRIEND_REQUESTED 2
#define FRIEND_ADDED 1
#define NOFRIEND 0

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
    dispatch_queue_t messengerQueue;
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
        messengerQueue = dispatch_queue_create("ca.kirara.DESRunLoop", NULL);
        messengerTick = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, messengerQueue);
        dispatch_source_set_timer(messengerTick, dispatch_walltime(NULL, 0), MESSENGER_TICK_RATE * NSEC_PER_SEC, 0.5 * NSEC_PER_SEC);
        wasConnected = NO;
        _friendManager = [[DESFriendManager alloc] initWithConnection:self];
        dispatch_source_set_event_handler(messengerTick, ^{
            doMessenger();
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
            __DESEnumerateFriendStatusesUsingBlock(^(int idx, int status, char *stop) {
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
    dispatch_sync(messengerQueue, ^{
        [self willChangeValueForKey:@"privateKey"];
        [self willChangeValueForKey:@"publicKey"];
        DESConvertPrivateKeyToData(thePrivateKey, self_secret_key);
        DESConvertPublicKeyToData(thePublicKey, self_public_key);
        [self didChangeValueForKey:@"privateKey"];
        [self didChangeValueForKey:@"publicKey"];
    });
}

- (void) CALLS_INTO_CORE_FUNCTIONS connect {
    dispatch_sync(messengerQueue, ^{
        initMessenger();
        m_callback_friendmessage(__DESCallbackMessage);
        m_callback_friendrequest(__DESCallbackFriendRequest);
        m_callback_namechange(__DESCallbackNameChange);
        m_callback_userstatus(__DESCallbackUserStatus);
        _currentUser = [[DESSelf alloc] init];
    });
    [[NSNotificationCenter defaultCenter] postNotificationName:DESConnectionDidInitNotification object:self];
    dispatch_resume(messengerTick);
}

- (void) CALLS_INTO_CORE_FUNCTIONS bootstrapWithAddress:(NSString *)theAddress port:(NSInteger)thePort publicKey:(NSString *)theKey {
    dispatch_sync(messengerQueue, ^{
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

@end

/* Callbacks begin */

void __DESCallbackFriendRequest(uint8_t *publicKey, uint8_t *payload, uint16_t length) {
    NSString *theKey = DESConvertPublicKeyToString(publicKey);
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    [[DESToxNetworkConnection sharedConnection].friendManager didReceiveNewRequestWithKey:theKey message:thePayload];
}

void __DESCallbackNameChange(int friend, uint8_t *payload, uint16_t length) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESFriend *theFriend = [[DESToxNetworkConnection sharedConnection].friendManager friendWithNumber:friend];
    dispatch_sync(dispatch_get_main_queue(), ^{
        theFriend.displayName = thePayload;
    });
}

void __DESCallbackUserStatus(int friend, USERSTATUS_KIND kind, uint8_t *payload, uint16_t length) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESFriend *theFriend = [[DESToxNetworkConnection sharedConnection].friendManager friendWithNumber:friend];
    dispatch_sync(dispatch_get_main_queue(), ^{
        theFriend.userStatus = thePayload;
    });
}

void __DESCallbackMessage(int friend, uint8_t *payload, uint16_t length) {
    NSString *thePayload = [[[NSString alloc] initWithBytes:payload length:length encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0"]]; /* Tox encodes strings with NULs for some reason. */
    DESFriend *theFriend = [[DESToxNetworkConnection sharedConnection].friendManager friendWithNumber:friend];
    [[[DESToxNetworkConnection sharedConnection].friendManager chatContextForFriend:theFriend] pushMessage:thePayload fromParticipant:theFriend];
}

