#import <Foundation/Foundation.h>

/* It holds data about a group chat invitation. */

@class DESFriendManager, DESFriend;
@interface DESGroupChat : NSObject

/* The owner of the GroupChat is the one you should call joinGroupChat: on.
 * While it is unsafe_unretained, it will hopefully be set to nil instead of
 * being left dangling. */
@property (readonly, unsafe_unretained) DESFriendManager *owner;
@property (readonly, unsafe_unretained) DESFriend *inviter;
@property (readonly, strong) NSString *publicKey;

@end
