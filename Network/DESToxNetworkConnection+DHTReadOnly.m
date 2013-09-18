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
    uint8_t family = cld->ip_port.ip.family;
    char *addr = NULL;
    if (family == AF_INET) {
        addr = malloc(INET_ADDRSTRLEN);
        inet_ntop(AF_INET, &cld->ip_port.ip.ip4.uint8, addr, INET_ADDRSTRLEN);
    } else {
        addr = malloc(INET6_ADDRSTRLEN);
        inet_ntop(AF_INET6, &cld->ip_port.ip.ip6.uint8, addr, INET6_ADDRSTRLEN);
    }
    NSString *address = [NSString stringWithCString:addr encoding:NSASCIIStringEncoding];
    free(addr);
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
            uint8_t fam = df->client_list[i].ip_port.ip.family;
            if (fam == AF_INET || fam == AF_INET6) {
                [ret addObject:[self createClientInfoDictionaryWithCorePointer:&(df->client_list[i]) source:ind]];
            }
        }
    });
    return ret;
}

@end
