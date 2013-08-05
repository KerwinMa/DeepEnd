#import "DeepEnd.h"

@interface DESFriend (PrivateSetters)

/* Implemented in DESFriend.m */
- (void)setDisplayName:(NSString *)displayName;
- (void)setUserStatus:(NSString *)userStatus;
- (void)setStatus:(DESFriendStatus)status;
- (void)setStatusType:(DESStatusType)kind;

@end

/* Private functions implemented in DESMessengerHack.c. */
int __DESSetNameOfFriend(int friendnumber, uint8_t * name);
//int __DESSetUserStatusOfFriend(int friendnumber, USERSTATUS_KIND kind, uint8_t * status, uint16_t length);
int __DESSetUserStatusOfFriend(int friendnumber, uint8_t * status, uint16_t length);
/* Private function implemented in DESDHTHack.c. */
uint16_t __DESGetNumberOfConnectedNodes(void);
/* Private function implemented in DESMessengerHack.c. */
void __DESEnumerateFriendStatusesUsingBlock(void(^block)(int idx, int status, char *stop));
/* Private function implemented in DESToxNetworkConnection.m. */
DESFriendStatus __DESCoreStatusToDESStatus(int theStatus);