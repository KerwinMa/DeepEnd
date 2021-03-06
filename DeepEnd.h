#import <Foundation/Foundation.h>
#import "tox.h"
/* Older OS X and iOS SDKs. */
#ifndef NS_ENUM
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif

#ifdef DES_DEBUG
#define DESDebug(fmt, ...) NSLog(@"[DeepEnd] in %s, line %i: " fmt, __func__, __LINE__, ##__VA_ARGS__)
#else
#define DESDebug(fmt, ...)
#endif

/**** CONSTANTS ****/

/* Because Core changes every so often, this denotes a method/function that uses
 * it, so we can easily find what needs to be fixed when Core changes. */
#define CALLS_INTO_CORE_FUNCTIONS
/* Adjust to make doMessenger run more or less. Lower second number = slower loop.
 * May help performance of slow systems. */
/* This can now be set at runtime, using -[DESToxNetworkConnection setRunLoopSpeed:]. */
#define DEFAULT_MESSENGER_TICK_RATE (1.0 / 100.0)
/* FIXME: Find out where that symbol went. */
#define MAX_MESSAGE_LENGTH (65535 - 21)

/* Assigned in DESFriend.m */
FOUNDATION_EXPORT const size_t DESFriendAddressSize;
FOUNDATION_EXPORT const int DESFriendInvalid;
FOUNDATION_EXPORT const int DESFriendSelf;

/* Assigned in DESKeyFunctions.m */
FOUNDATION_EXPORT const size_t DESPublicKeySize;
FOUNDATION_EXPORT const size_t DESPrivateKeySize;

/* Notifications posted by DESToxNetworkConection. */
FOUNDATION_EXPORT NSString *const DESConnectionDidInitNotification;
FOUNDATION_EXPORT NSString *const DESConnectionDidConnectNotification;
FOUNDATION_EXPORT NSString *const DESConnectionDidFailNotification;
FOUNDATION_EXPORT NSString *const DESConnectionDidTerminateNotification;

/* Notification posted by classes implementing DESChatContext protocol. */
FOUNDATION_EXPORT NSString *const DESDidPushMessageToContextNotification;

/* Used in -userInfo of the above notifications. */
FOUNDATION_EXPORT NSString *const DESMessageKey;

/* Assigned in DESFriendManager.h */
FOUNDATION_EXPORT NSString *const DESFriendAddErrorDomain;
FOUNDATION_EXPORT NSString *const DESFriendRequestArrayDidChangeNotification;
FOUNDATION_EXPORT NSString *const DESFriendArrayDidChangeNotification;
FOUNDATION_EXPORT NSString *const DESChatContextArrayDidChangeNotification;
FOUNDATION_EXPORT NSString *const DESGroupRequestArrayDidChangeNotification;

/* Used in -userInfo of the above notifications. */
FOUNDATION_EXPORT NSString *const DESArrayOperationKey;
FOUNDATION_EXPORT NSString *const DESArrayOperationTypeAdd;
FOUNDATION_EXPORT NSString *const DESArrayOperationTypeRemove;
FOUNDATION_EXPORT NSString *const DESArrayObjectKey;

#define DESArrayFriendKey DESArrayObjectKey
#define DESArrayChatContextKey DESArrayObjectKey

/* Status enum used by DESFriend. */
typedef NS_ENUM(NSInteger, DESFriendStatus) {
    DESFriendStatusOffline, /* This friend is offline (not on the network) */
    DESFriendStatusOnline, /* This friend is confirmed and sendMessage: will not fail. */
    DESFriendStatusRequestReceived, /* This friend sent us a request. */
    DESFriendStatusRequestSent, /* We sent this friend a request. */
    DESFriendStatusConfirmed, /* We accepted the request, but first nickname/status packets were not received. */
    DESFriendStatusSelf, /* This friend is us. Always and only returned by DESSelf. */
};

/* Equivalent to TOX_USERSTATUS_KIND of tox.h */

typedef NS_ENUM(NSInteger, DESStatusType) {
    DESStatusTypeOnline = TOX_USERSTATUS_NONE,
    DESStatusTypeAway = TOX_USERSTATUS_AWAY,
    DESStatusTypeBusy = TOX_USERSTATUS_BUSY,
    DESStatusTypeInvalid = TOX_USERSTATUS_INVALID,
};

typedef NS_ENUM(NSInteger, DESMessageType) {
    DESMessageTypeChat,
    DESMessageTypeAction,
    DESMessageTypeNicknameChange,
    DESMessageTypeStatusChange,
    DESMessageTypeUserStatusChange,
    DESMessageTypeStatusTypeChange,
    DESMessageTypeSystem,
};

typedef NS_ENUM(NSInteger, DESSystemMessageType) {
    DESSystemMessageInfo,
    DESSystemMessageWarning,
    DESSystemMessageError,
    DESSystemMessageCritical,
};

typedef NS_ENUM(NSInteger, DESFriendAddResultCode) {
    DESFriendAddResultMessageTooLong = TOX_FAERR_TOOLONG,
    DESFriendAddResultNoMessage = TOX_FAERR_NOMESSAGE,
    DESFriendAddResultOwnKey = TOX_FAERR_OWNKEY,
    DESFriendAddResultAlreadySent = TOX_FAERR_ALREADYSENT,
    DESFriendAddResultUnknown = TOX_FAERR_UNKNOWN,
    DESFriendAddResultBadChecksum = TOX_FAERR_BADCHECKSUM,
    DESFriendAddResultBadNospam = TOX_FAERR_SETNEWNOSPAM,
    DESFriendAddResultMemoryError = TOX_FAERR_NOMEM,
};

typedef NS_ENUM(NSInteger, DESContextType) {
    DESContextTypeGroupChat,
    DESContextTypeOneToOne,
};

/**** DEEPEND CORE CLASSES ****/

#import "DESToxNetworkConnection.h"
#import "DESToxNetworkConnection+DHTReadOnly.h"
#import "DESFriendManager.h"
#import "DESFriend.h"
#import "DESSelf.h"
#import "DESChatContext.h"
#import "DESMessage.h"
#import "DESGroupChat.h"

/**** KEY FUNCTIONS (DESKeyFunctions.m) ****/

/* Verify whether a string is a 64-character hex string suitable for passing into
 * DeepEndConvertPublicKeyString. */
BOOL DESPublicKeyIsValid(NSString *theKey);
BOOL DESPrivateKeyIsValid(NSString *theKey);
BOOL DESFriendAddressIsValid(NSString *theAddr);

/* Convert a 64-character hex string into bytes, and place it into theOutput.
 * theOutput will be at least crypto_box_PUBLICKEYSIZE in size.
 */
void DESConvertPublicKeyToData(NSString *theString, uint8_t *theOutput);

/* Convert a ??-character hex string into bytes, and place it into theOutput.
 * theOutput will be at least crypto_box_SECRETKEYSIZE in size.
 */
void DESConvertPrivateKeyToData(NSString *theString, uint8_t *theOutput);
void DESConvertFriendAddressToData(NSString *theString, uint8_t *theOutput);

/* Convert a Tox public key from Core to its 64-character hex representation. */
NSString *DESConvertPublicKeyToString(const uint8_t *theData);

/* Convert a Tox private key from Core to its 64-character hex representation. */
NSString *DESConvertPrivateKeyToString(const uint8_t *theData);
NSString *DESConvertFriendAddressToString(const uint8_t *theData);

BOOL DESValidateKeyPair(const uint8_t *privateKey, const uint8_t *publicKey);

BOOL DESIsDebugBuild(void);