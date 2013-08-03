#import "DeepEnd.h"
#import "DESFriend.h"

@interface DESSelf : DESFriend

/* Our private key. [DESToxNetworkConnection setPrivateKey:publicKey:] to set it. */
@property (strong, readonly) NSString *privateKey;

@end
