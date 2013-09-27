#import <Foundation/Foundation.h>
#import "DeepEnd.h"

@class DESMessage;
@protocol DESChatContext <NSObject>

@required
/* A set of DESFriend objects assigned to this context. */
@property (readonly) NSSet *participants;
/* Messages received so far. */
@property (readonly) NSArray *backlog;
/* The maximum size of the backlog array. Oldest messages will be deleted if it
 * gets larger than this. */
@property NSUInteger maximumBacklogSize;
@property (assign) DESFriendManager *friendManager;
/* A string that uniquely identifies this chat context in its friend manager.
 * Even though the property is named UUID, implementors do not need to use an
 * actual UUID. */
@property (readonly) NSString *uuid;
/* A human-readable name for this chat context, suitable for display on UI.
 * For example, the name of a DESOneToOneChatContext is the friend's name. */
@property (readonly) NSString *name;

- (DESContextType)type;
/* Add a friend to this chat context. Currently Tox only supports 1-1 chat,
 * but this will be useful once group chat is implemented. */
- (void)addParticipant:(DESFriend *)theFriend;
- (void)removeParticipant:(DESFriend *)theFriend;

- (void)sendMessage:(NSString *)message;
- (void)sendAction:(NSString *)message;
- (void)pushMessage:(DESMessage *)aMessage;

@end
