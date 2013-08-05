#include "DHT.c"

uint16_t __DESGetNumberOfConnectedNodes(void) {
    uint32_t i;
    uint64_t temp_time = unix_time();
    uint16_t count = 0;
    for(i = 0; i < LCLIENT_LIST; ++i) {
        if(!is_timeout(temp_time, close_clientlist[i].timestamp, BAD_NODE_TIMEOUT))
            ++count;
    }
    return count;
}