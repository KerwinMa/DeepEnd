#import "DeepEnd.h"
#import "DESChatContext.h"

/*
 * The DESFriend class represents a user of the Tox network.
 * They can be in various states of contact, including request received,
 * request sent, confirmed, online, and offline.
 * See DESFriendStatus enum.
 * DESSelf is a subclass of DESFriend used to represent ourself.
 * You can get the singleton instance of it using [DESSelf self],
 * or [DESToxNetworkConnection me].
 * Most properties on DESFriend are KVO-observable.
 */

@interface DESFriend : NSObject {
    @public
    DESFriendManager *owner;
    @protected
    NSString *_displayName;
    NSString *_userStatus;
    NSString *_publicKey;
    int _friendNumber;
    DESFriendStatus _status;
    DESStatusType _statusType;
}

/* The friend number from Core. */
@property (readonly) int friendNumber;

/* The display name. */
@property (strong, readonly) NSString *displayName;

/* The user status. */
@property (strong, readonly) NSString *userStatus;
@property (readonly) DESStatusType statusType;

/* The public key. */
@property (strong, readonly) NSString *publicKey;

/* The private key. Only available on DESSelf, will return nil anywhere else. */
@property (strong, readonly) NSString *privateKey;

/* The friend address. */
@property (strong, readonly) NSString *friendAddress;

/* The friend's status. See DeepEnd.h for possible values. */
@property (readonly) DESFriendStatus status;

/* The date at which the request was received. Only valid when the friend object is a request. */
@property (readonly) NSDate *dateReceived;
@property (readonly) NSString *requestInfo;

@property (readonly) id<DESChatContext> chatContext;

- (instancetype)initWithNumber:(int)friendNumber;
- (instancetype)initWithNumber:(int)friendNumber owner:(DESFriendManager *)manager;

@end
