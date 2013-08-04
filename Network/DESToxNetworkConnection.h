#import <Foundation/Foundation.h>

@class DESFriendManager, DESFriend, DESSelf;
@interface DESToxNetworkConnection : NSObject

/* Returns the shared instance of DESToxNetworkConnection */
+ (instancetype)sharedConnection;

@property (strong, readonly) DESSelf *me;

/* Gets the instance of DESFriendManager associated with this connection. */
@property (strong, readonly) DESFriendManager *friendManager;

/* Whether the bootstrap is complete (the client can use the network) */
@property (readonly) BOOL connected;

/* Set the public and private keys. They must be a valid pair or things will break. */
- (void)setPrivateKey:(NSString *)thePrivateKey publicKey:(NSString *)thePublicKey;

/* Connect without bootstrapping. */
- (void)connect;

/* Equivalent to a call to -connect, then a call to -bootstrapWithAddress:port:publicKey:. */
- (void)connectWithBootstrapAddress:(NSString *)theAddress port:(NSInteger)thePort publicKey:(NSString *)theKey;

/* Perform a DHT bootstrap to the chosen node. */
- (void)bootstrapWithAddress:(NSString *)theAddress port:(NSInteger)thePort publicKey:(NSString *)theKey;

/* Disconnect. */
- (void)disconnect;

@end
