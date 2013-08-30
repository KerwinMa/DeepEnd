#include "DHT.c"

uint16_t __DESReallyGetNumberOfConnectedNodes(DHT *dht) {
    uint32_t i;
    uint64_t temp_time = unix_time();
    uint16_t count = 0;
    for(i = 0; i < LCLIENT_LIST; ++i) {
        if(!is_timeout(temp_time, dht->close_clientlist[i].timestamp, BAD_NODE_TIMEOUT))
            ++count;
    }
    return count;
}

void __DESEnumerateCloseDHTNodesWithBlock(DHT *dht, void(^block)(int ind, Client_data *cld)) {
    int realindex = 0;
    for (int i = 0; i < LCLIENT_LIST; ++i) {
        /* Check if the IP is zero. If it is, then the node is a blank entry and can be skipped. */
        if (dht->close_clientlist[i].ip_port.ip.i != 0) {
            block(realindex++, &(dht->close_clientlist[i]));
        }
    }
}

void __DESEnumerateDHTFriendListWithBlock(DHT *dht, void(^block)(int ind, DHT_Friend *df)) {
    int realindex = 0;
    for (int i = 0; i < dht->num_friends; ++i) {
        /* Check if the IP is zero. If it is, then the node is a blank entry and can be skipped. */
        block(realindex++, &(dht->friends_list[i]));
    }
}