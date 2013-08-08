#import <Foundation/Foundation.h>
#import "Messenger.h"
/* Older OS X and iOS SDKs. */
#ifndef NS_ENUM
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif

/**** CONSTANTS ****/

/* Because Core changes every so often, this denotes a method/function that uses
 * it, so we can easily find what needs to be fixed when Core changes. */
#define CALLS_INTO_CORE_FUNCTIONS
/* Adjust to make doMessenger run more or less. Lower second number = slower loop.
 * May help performance of slow systems. */
#define MESSENGER_TICK_RATE (1.0 / 100.0)
#define MAX_MESSAGE_LENGTH (MAX_DATA_SIZE - 17)
#define DES_FRIEND_INVALID -1
/* Alternatively: DES_FRIEND_VERY_INVALID */
#define DES_FRIEND_SELF -2

FOUNDATION_EXPORT const int DESFriendInvalid;
FOUNDATION_EXPORT const int DESFriendSelf;

FOUNDATION_EXPORT const size_t DESPublicKeySize;
FOUNDATION_EXPORT const size_t DESPrivateKeySize;

/* Notifications posted by DESToxNetworkConection. */
FOUNDATION_EXPORT NSString *const DESConnectionDidInitNotification;
FOUNDATION_EXPORT NSString *const DESConnectionDidConnectNotification;
FOUNDATION_EXPORT NSString *const DESConnectionDidFailNotification;
FOUNDATION_EXPORT NSString *const DESConnectionDidTerminateNotification;

FOUNDATION_EXPORT NSString *const DESDidReceiveMessageFromFriendNotification;
FOUNDATION_EXPORT NSString *const DESFriendRequestArrayDidChangeNotification;
FOUNDATION_EXPORT NSString *const DESFriendArrayDidChangeNotification;

/* Status enum used by DESFriend. */
typedef NS_ENUM(NSInteger, DESFriendStatus) {
    DESFriendStatusOffline, /* This friend is offline (not on the network) */
    DESFriendStatusOnline, /* This friend is confirmed and sendMessage: will not fail. */
    DESFriendStatusRequestReceived, /* This friend sent us a request. */
    DESFriendStatusRequestSent, /* We sent this friend a request. */
    DESFriendStatusConfirmed, /* We accepted the request, but first nickname/status packets were not received. */
    DESFriendStatusSelf, /* This friend is us. Always and only returned by DESSelf. */
};

/* Equivalent to USERSTATUS_KIND of Messenger.h
 **/

typedef NS_ENUM(USERSTATUS_KIND, DESStatusType) {
    DESStatusTypeOnline = USERSTATUS_KIND_ONLINE,
    DESStatusTypeAway = USERSTATUS_KIND_AWAY,
    DESStatusTypeBusy = USERSTATUS_KIND_BUSY,
    DESStatusTypeOffline = USERSTATUS_KIND_OFFLINE,
    DESStatusTypeRetain = USERSTATUS_KIND_RETAIN,
    DESStatusTypeInvalid = USERSTATUS_KIND_INVALID,
};

/**** DEEPEND CORE CLASSES ****/

#import <DeepEnd/DESToxNetworkConnection.h>
#import <DeepEnd/DESFriendManager.h>
#import <DeepEnd/DESFriend.h>
#import <DeepEnd/DESSelf.h>
#import <DeepEnd/DESChatContext.h>

/**** KEY FUNCTIONS (DESKeyFunctions.m) ****/

/* Verify whether a string is a 64-character hex string suitable for passing into
 * DeepEndConvertPublicKeyString. */
BOOL DESPublicKeyIsValid(NSString *theKey);
BOOL DESPrivateKeyIsValid(NSString *theKey);

/* Convert a 64-character hex string into bytes, and place it into theOutput.
 * theOutput will be at least crypto_box_PUBLICKEYSIZE in size.
 */
void DESConvertPublicKeyToData(NSString *theString, uint8_t *theOutput);

/* Convert a ??-character hex string into bytes, and place it into theOutput.
 * theOutput will be at least crypto_box_SECRETKEYSIZE in size.
 */
void DESConvertPrivateKeyToData(NSString *theString, uint8_t *theOutput);

/* Convert a Tox public key from Core to its 64-character hex representation. */
NSString *DESConvertPublicKeyToString(const uint8_t *theData);

/* Convert a Tox private key from Core to its 64-character hex representation. */
NSString *DESConvertPrivateKeyToString(const uint8_t *theData);
BOOL DESValidateKeyPair(const uint8_t *privateKey, const uint8_t *publicKey);

BOOL DESIsDebugBuild(void);