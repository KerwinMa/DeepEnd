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

- (NSDictionary *)createClientInfoDictionaryWithCorePointer:(Client_data *)cld usingIPv6:(int)v6 {
    return [self createClientInfoDictionaryWithCorePointer:cld usingIPv6:v6 source:-1];
}

- (NSDictionary *)createClientInfoDictionaryWithCorePointer:(Client_data *)cld usingIPv6:(int)v6 source:(NSInteger)source {
    NSString *publicKey = DESConvertPublicKeyToString(cld->client_id);
    NSNumber *port = nil;
    NSNumber *timestamp = nil;
    char *addr = NULL;
    if (v6) {
        uint8_t family = cld->assoc6.ip_port.ip.family;
        if (family == AF_INET) {
            addr = malloc(INET_ADDRSTRLEN);
            inet_ntop(AF_INET, &cld->assoc6.ip_port.ip.ip4.uint8, addr, INET_ADDRSTRLEN);
        } else {
            addr = malloc(INET6_ADDRSTRLEN);
            inet_ntop(AF_INET6, &cld->assoc6.ip_port.ip.ip6.uint8, addr, INET6_ADDRSTRLEN);
        }
        port = @(ntohs(cld->assoc6.ip_port.port));
        timestamp = @(cld->assoc6.timestamp);
    } else {
        uint8_t family = cld->assoc4.ip_port.ip.family;
        if (family == AF_INET) {
            addr = malloc(INET_ADDRSTRLEN);
            inet_ntop(AF_INET, &cld->assoc4.ip_port.ip.ip4.uint8, addr, INET_ADDRSTRLEN);
        } else {
            addr = malloc(INET6_ADDRSTRLEN);
            inet_ntop(AF_INET6, &cld->assoc4.ip_port.ip.ip6.uint8, addr, INET6_ADDRSTRLEN);
        }
        port = @(ntohs(cld->assoc4.ip_port.port));
        timestamp = @(cld->assoc4.timestamp);
    }
    NSString *address = [NSString stringWithCString:addr encoding:NSASCIIStringEncoding];
    free(addr);
    
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
    __DESEnumerateCloseDHTNodesWithBlock(((Messenger*)self.m)->dht, ^(int ind, Client_data *cld, int ipv6) {
        [ret addObject:[self createClientInfoDictionaryWithCorePointer:cld usingIPv6:ipv6]];
    });
    return ret;
}

- (NSArray *)knownClients {
    NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:((Messenger*)self.m)->dht->num_friends * MAX_FRIEND_CLIENTS];
    __DESEnumerateDHTFriendListWithBlock(((Messenger*)self.m)->dht, ^(int ind, DHT_Friend *df) {
        for (int i = 0; i < MAX_FRIEND_CLIENTS; ++i) {
            uint8_t fam = df->client_list[i].assoc6.ip_port.ip.family;
            if (fam == AF_INET || fam == AF_INET6) {
                [ret addObject:[self createClientInfoDictionaryWithCorePointer:&(df->client_list[i]) usingIPv6:1 source:ind]];
            } else {
                fam = df->client_list[i].assoc4.ip_port.ip.family;
                if (fam == AF_INET || fam == AF_INET6) {
                    [ret addObject:[self createClientInfoDictionaryWithCorePointer:&(df->client_list[i]) usingIPv6:0 source:ind]];
                }
            }
        }
    });
    return ret;
}

@end
