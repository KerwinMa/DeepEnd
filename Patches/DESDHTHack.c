#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"
#include "DHT.c"
#pragma clang diagnostic pop

uint16_t __DESReallyGetNumberOfConnectedNodes(DHT *dht) {
    uint32_t i;
    uint16_t count = 0;
    for(i = 0; i < LCLIENT_LIST; ++i) {
        if (!is_timeout(dht->close_clientlist[i].assoc6.timestamp, BAD_NODE_TIMEOUT)) {
            ++count;
            continue;
        } else if (!is_timeout(dht->close_clientlist[i].assoc4.timestamp, BAD_NODE_TIMEOUT)) {
            ++count;
        }
    }
    return count;
}

void __DESEnumerateCloseDHTNodesWithBlock(DHT *dht, void(^block)(int ind, Client_data *cld, int ipv6)) {
    int realindex = 0;
    for (int i = 0; i < LCLIENT_LIST; ++i) {
        uint8_t fam = dht->close_clientlist[i].assoc6.ip_port.ip.family;
        if (fam == AF_INET6) {
            block(realindex++, &(dht->close_clientlist[i]), 1);
        } else {
            /* Try IPv4 */
            fam = dht->close_clientlist[i].assoc4.ip_port.ip.family;
            if (fam == AF_INET) {
                block(realindex++, &(dht->close_clientlist[i]), 0);
            }
        }
    }
}

void __DESEnumerateDHTFriendListWithBlock(DHT *dht, void(^block)(int ind, DHT_Friend *df)) {
    int realindex = 0;
    for (int i = 0; i < dht->num_friends; ++i) {
        block(realindex++, &(dht->friends_list[i]));
    }
}