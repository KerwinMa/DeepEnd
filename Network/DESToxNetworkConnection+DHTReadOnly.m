#import "DESToxNetworkConnection+DHTReadOnly.h"
#import "DeepEnd-Private.h"
#import "Messenger.h"
#import <arpa/inet.h>

NSString *const DESDHTNodeSourceKey = @"DESDHTNodeSourceKey";
NSString *const DESDHTNodeIPAddressKey = @"DESDHTNodeIPAddressKey";
NSString *const DESDHTNodePortKey = @"DESDHTNodePortKey";
NSString *const DESDHTNodePublicKey = @"DESDHTNodePublicKey";
NSString *const DESDHTNodeTimestampKey = @"DESDHTNodeTimestampKey";

@implementation DESToxNetworkConnection (DHTReadOnly)

- (NSDictionary *)createClientInfoDictionaryWithCorePointer:(Client_data *)cld {
    return [self createClientInfoDictionaryWithCorePointer:cld source:-1];
}

- (NSDictionary *)createClientInfoDictionaryWithCorePointer:(Client_data *)cld source:(NSInteger)source {
    NSString *publicKey = DESConvertPublicKeyToString(cld->client_id);
    NSMutableArray *addr = [[NSMutableArray alloc] initWithCapacity:4];
    uint8_t *c = cld->ip_port.ip.uint8;
    for (int i = 0; i < 4; i++) {
        [addr addObject:[NSString stringWithFormat:@"%i", c[i]]];
    }
    NSString *address = [addr componentsJoinedByString:@"."];
    NSNumber *port = @(cld->ip_port.port);
    NSNumber *timestamp = @(cld->timestamp);
    return @{
        DESDHTNodeSourceKey: @(source),
        DESDHTNodeIPAddressKey: address,
        DESDHTNodePortKey: port,
        DESDHTNodePublicKey: publicKey,
        DESDHTNodeTimestampKey: timestamp,
    };
}

- (NSArray *)closeNodes {
    NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:LCLIENT_LIST];
    __DESEnumerateCloseDHTNodesWithBlock(((Messenger*)self.m)->dht, ^(int ind, Client_data *cld) {
        [ret addObject:[self createClientInfoDictionaryWithCorePointer:cld]];
    });
    return ret;
}

- (NSArray *)knownClients {
    NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:((Messenger*)self.m)->dht->num_friends * MAX_FRIEND_CLIENTS];
    __DESEnumerateDHTFriendListWithBlock(((Messenger*)self.m)->dht, ^(int ind, DHT_Friend *df) {
        for (int i = 0; i < MAX_FRIEND_CLIENTS; ++i) {
            if (df->client_list[i].ip_port.ip.uint32 != 0) {
                [ret addObject:[self createClientInfoDictionaryWithCorePointer:&(df->client_list[i]) source:ind]];
            }
        }
    });
    return ret;
}

@end
