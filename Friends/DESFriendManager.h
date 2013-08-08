#import <Foundation/Foundation.h>

@class DESToxNetworkConnection, DESFriend, DESChatContext;
@interface DESFriendManager : NSObject <NSSecureCoding>

/* Not thread-safe! Use a copy or methods that wrap these arrays below! */
@property (readonly) NSArray *friends;
@property (readonly) NSArray *requests;
@property (readonly) NSArray *blockedKeys;

/* The connection that owns this friend manager. */
@property (readonly) DESToxNetworkConnection *connection;

- (instancetype)initWithConnection:(DESToxNetworkConnection *)connection;

/* Send a friend request to the person who owns the public key theKey, with message theMessage.
 * If we have a pending request from that person, it is accepted, instead of sending
 * our own request. */
- (void)addFriendWithPublicKey:(NSString *)theKey message:(NSString *)theMessage;

/* Removes theFriend from the friend manager. Their personal chat context will also be
 * deleted. If we have a pending request from the friend, it will be declined. If
 * we sent a request, it is cancelled. */
- (void)removeFriend:(DESFriend *)theFriend;

- (void)acceptRequestFromFriend:(DESFriend *)theFriend;
- (void)rejectRequestFromFriend:(DESFriend *)theFriend;

/* Find the friend object with theKey. Returns nil on failure. 
 * If theKey belongs to us, return the DESSelf object. */
- (DESFriend *)friendWithPublicKey:(NSString *)theKey;

/* Find the friend object with theKey. Returns nil on failure. */
- (DESFriend *)friendWithNumber:(int)theNumber;

- (DESChatContext *)chatContextForFriend:(DESFriend *)theFriend;
- (NSArray *)chatContextsContainingFriend:(DESFriend *)theFriend;

@end
