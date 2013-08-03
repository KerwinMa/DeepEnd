#import "DeepEnd.h"

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

@interface DESFriend : NSObject <NSSecureCoding> {
    @protected
    NSString *_displayName;
    NSString *_userStatus;
    NSString *_publicKey;
    int _friendNumber;
    DESFriendStatus _status;
}

/* The friend number from Core. */
@property (readonly) int friendNumber;

/* The display name. */
@property (strong, readonly) NSString *displayName;

/* The user status. */
@property (strong, readonly) NSString *userStatus;

/* The public key. */
@property (strong, readonly) NSString *publicKey;

/* The friend's status. See DeepEnd.h for possible values. */
@property (readonly) DESFriendStatus status;

- (instancetype)initWithNumber:(int)friendNumber;

/* Send a message to this friend. Returns success or failure.
 * If the message is too long, it will be split up into multiple messages. */
- (BOOL)sendMessage:(NSString *)theMessage;
@end
