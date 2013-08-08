#import "DeepEnd.h"

@interface DESFriend (PrivateSetters)

/* Implemented in DESFriend.m */
- (void)setDisplayName:(NSString *)displayName;
- (void)setUserStatus:(NSString *)userStatus;
- (void)setStatus:(DESFriendStatus)status;
- (void)setStatusType:(DESStatusType)kind;

@end

@interface DESFriendManager ()

- (void)didReceiveNewRequestWithKey:(NSString *)theKey message:(NSString *)thePayload;

@end

@interface DESChatContext ()

- (void)setIsPersonal:(BOOL)isPersonal;

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
/* Private callbacks implemented in DESToxNetworkConnection.m */
void __DESCallbackFriendRequest(uint8_t *publicKey, uint8_t *payload, uint16_t length);
void __DESCallbackNameChange(int friend, uint8_t *payload, uint16_t length);
void __DESCallbackUserStatusKind(int friend, USERSTATUS kind);
void __DESCallbackUserStatus(int friend, uint8_t *payload, uint16_t length);
void __DESCallbackMessage(int friend, uint8_t *payload, uint16_t length);
/* Temporary: declare function missing from header file Messenger.h */
void m_callback_userstatus(void (*function)(int, USERSTATUS));

