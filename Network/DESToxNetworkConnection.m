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

- (instancetype)init {
    self = [super init];
    if (self) {
        messengerQueue = dispatch_queue_create("ca.kirara.DESRunLoop", NULL);
        messengerTick = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, messengerQueue);
        dispatch_source_set_timer(messengerTick, dispatch_walltime(NULL, 0), MESSENGER_TICK_RATE * NSEC_PER_SEC, 0.5 * NSEC_PER_SEC);
        wasConnected = NO;
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
                    theFriend.status = status;
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

- (void)setPrivateKey:(NSString *)thePrivateKey publicKey:(NSString *)thePublicKey {
    dispatch_sync(messengerQueue, ^{
        [self willChangeValueForKey:@"privateKey"];
        [self willChangeValueForKey:@"publicKey"];
        DESConvertPrivateKeyToData(thePrivateKey, self_secret_key);
        DESConvertPublicKeyToData(thePublicKey, self_public_key);
        [self didChangeValueForKey:@"privateKey"];
        [self didChangeValueForKey:@"publicKey"];
    });
}

- (void)connect {
    dispatch_sync(messengerQueue, ^{
        initMessenger();
        _currentUser = [[DESSelf alloc] init];
    });
    [[NSNotificationCenter defaultCenter] postNotificationName:DESConnectionDidInitNotification object:self];
    dispatch_resume(messengerTick);
}

- (void)bootstrapWithAddress:(NSString *)theAddress port:(NSInteger)thePort publicKey:(NSString *)theKey {
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
