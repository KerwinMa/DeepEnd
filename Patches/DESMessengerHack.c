#include "Messenger.c"

/* Yes. */

int __DESSetNameOfFriend(int friendnumber, uint8_t *name) {
    return setfriendname(friendnumber, name);
}

int __DESSetUserStatusOfFriend(int friendnumber, uint8_t *status, uint16_t length) {
    return set_friend_statusmessage(friendnumber, status, length);
}

void __DESEnumerateFriendStatusesUsingBlock(void(^block)(int idx, int status, char *stop)) {
    char stop = 0;
    for (int i = 0; i < numfriends; ++i) {
        block(i, friendlist[i].status, &stop);
        if (stop) break;
    }
}
