#include "Messenger.c"

/* Yes. */

int __DESSetNameOfFriend(int friendnumber, uint8_t *name) {
    return setfriendname(friendnumber, name);
}

int __DESSetUserStatusOfFriend(int friendnumber, uint8_t *status, uint16_t length) {
    return set_friend_userstatus(friendnumber, status, length);
}