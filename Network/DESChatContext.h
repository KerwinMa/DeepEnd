#import <Foundation/Foundation.h>

@interface DESChatContext : NSObject

/* A set of DESFriend objects assigned to this context. */
@property (readonly) NSSet *participants;
/* Messages received so far. */
@property (readonly) NSArray *backlog;
/* The maximum size of the backlog array. Oldest messages will be deleted if it
 * gets larger than this. */
@property NSUInteger maximumBacklogSize;
@property (readonly) BOOL isPersonalChatContext;

- (instancetype)initWithParticipants:(NSArray *)participants;

/* Add a friend to this chat context. Currently Tox only supports 1-1 chat,
 * but this will be useful once group chat is implemented. */
- (void)addParticipant:(DESFriend *)theFriend;
- (void)removeParticipant:(DESFriend *)theFriend;

/* Return a subset of the backlog containing only messages newer than aDate. */
- (NSArray *)backlogStartingFromDate:(NSDate *)aDate;

/* Put a message into this context. */
- (void)pushMessage:(NSString *)aMessage fromParticipant:(DESFriend *)theFriend;

@end
