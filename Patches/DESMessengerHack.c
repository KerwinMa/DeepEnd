#include "Messenger.c"

/* Yes. */

int __DESSetNameOfFriend(Messenger *m, int friendnumber, uint8_t *name, uint16_t length) {
    return setfriendname(m, friendnumber, name, length);
}

int __DESSetUserStatusOfFriend(Messenger *m, int friendnumber, uint8_t *status, uint16_t length) {
    return set_friend_statusmessage(m, friendnumber, status, length);
}

void __DESEnumerateFriendStatusesUsingBlock(Messenger *m, void(^block)(int idx, int status, char *stop)) {
    char stop = 0;
    for (int i = 0; i < m->numfriends; ++i) {
        block(i, m->friendlist[i].status, &stop);
        if (stop) break;
    }
}

uint16_t __DESChecksumAddress(uint8_t *address, uint32_t len) {
    return address_checksum(address, len);
}

/* Imp.: DESDHTHack.c. */
uint16_t __DESReallyGetNumberOfConnectedNodes(DHT *dht);
uint16_t __DESGetNumberOfConnectedNodes(void *tox) {
    Messenger *m = tox;
    return __DESReallyGetNumberOfConnectedNodes(m->dht);
}