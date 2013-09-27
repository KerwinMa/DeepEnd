#import <Foundation/Foundation.h>
#import "DeepEnd.h"
#import "DESChatContext.h"

@class DESToxNetworkConnection, DESFriend, DESGroupChat;
@interface DESFriendManager : NSObject

/* Not thread-safe! Use a copy or methods that wrap these arrays below! */
@property (readonly) NSArray *friends;
@property (readonly) NSArray *requests;
@property (readonly) NSArray *chatContexts;
@property (readonly) NSArray *groupRequests;

/* The connection that owns this friend manager. */
@property (readonly) DESToxNetworkConnection *connection;

- (instancetype)initWithConnection:(DESToxNetworkConnection *)connection;

/* Send a friend request to the person who owns the public key theKey, with message theMessage.
 * If we have a pending request from that person, it is accepted, instead of sending
 * our own request. */
- (DESFriend *)addFriendWithAddress:(NSString *)theKey message:(NSString *)theMessage;
- (DESFriend *)addFriendWithAddress:(NSString *)theKey message:(NSString *)theMessage error:(NSError *__autoreleasing *)err;

/* Add a friend to the friends list without sending a request. It can be used, for example,
 * when restoring the friends list from a file.
 * Do not use this method to accept friend requests. Use acceptRequestFromFriend. */
- (DESFriend *)addFriendWithoutRequest:(NSString *)theKey;

/* Removes theFriend from the friend manager. Their personal chat context will also be
 * deleted. If we have a pending request from the friend, it will be declined. If
 * we sent a request, it is cancelled. */
- (void)removeFriend:(DESFriend *)theFriend;

- (DESFriend *)acceptRequestFromFriend:(DESFriend *)theFriend;
- (void)rejectRequestFromFriend:(DESFriend *)theFriend;

/* Find the friend object with theKey. Returns nil on failure. 
 * If theKey belongs to us, return the DESSelf object. */
- (DESFriend *)friendWithPublicKey:(NSString *)theKey;

/* Find the request object with theKey. Returns nil on failure. */
- (DESFriend *)requestWithPublicKey:(NSString *)theKey;

/* Find the friend object with theKey. Returns nil on failure. */
- (DESFriend *)friendWithNumber:(int)theNumber;

/* Return the first chat context with the UUID uuid. If it's not found, return nil. */
- (id<DESChatContext>)chatContextWithUUID:(NSString *)uuid;

/* Create a new group chat. name is unused for now. */
- (id<DESChatContext>)createGroupChatWithName:(NSString *)aName;

/* Join a group chat you were previously invited to.
 * On failure, it will return nil. */
- (id<DESChatContext>)joinGroupChat:(DESGroupChat *)grp;

/* Remove the group chat invitation from the manager's internal
 * storage. */
- (void)rejectGroupChatInvitation:(DESGroupChat *)grp;

/* Leave the group chat. */
- (void)removeGroupChat:(id<DESChatContext>)groupChat;

@end
