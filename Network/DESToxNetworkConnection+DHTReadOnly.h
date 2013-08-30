#import "DESToxNetworkConnection.h"

/*
 * This file defines an API for reading information from Core's internal DHT.
 * WARNING: This is an experimental API that may break at any time, please do not
 * rely on it.
 * WARNING: Everything in this API must be run on the queue of the network connection.
 */

FOUNDATION_EXPORT NSString *const DESDHTNodeSourceKey;
FOUNDATION_EXPORT NSString *const DESDHTNodeIPAddressKey;
FOUNDATION_EXPORT NSString *const DESDHTNodePortKey;
FOUNDATION_EXPORT NSString *const DESDHTNodePublicKey;
FOUNDATION_EXPORT NSString *const DESDHTNodeTimestampKey;

@interface DESToxNetworkConnection (DHTReadOnly)

/* Returns the array of DHT nodes known to Core.
 * The following keys can be queried:
 * - DESDHTNodeIPAddressKey (NSString)
 * - DESDHTNodePortKey (NSNumber)
 * - DESDHTNodePublicKey (NSString)
 * - DESDHTNodeLastPingKey (NSDate) */
- (NSArray *)closeNodes;
- (NSArray *)knownClients;

@end
