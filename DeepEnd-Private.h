#import "DeepEnd.h"

@interface DESToxNetworkConnection ()

@property (readonly) Messenger *m;

@end

@interface DESFriend ()

/* Implemented in DESFriend.m */
- (void)setDisplayName:(NSString *)displayName;
- (void)setUserStatus:(NSString *)userStatus;
- (void)setStatus:(DESFriendStatus)status;
- (void)setStatusType:(DESStatusType)kind;
+ (instancetype)friendRequestWithAddress:(NSString *)aKey message:(NSString *)theMessage owner:(DESFriendManager *)theOwner;

@end

@interface DESFriendManager ()

- (void)didReceiveNewRequestWithAddress:(NSString *)theKey message:(NSString *)thePayload;
- (void)addContext:(id<DESChatContext>)context;

@end

@interface DESMessage ()

- (void)setRead:(BOOL)read;
- (void)setSendFailure:(BOOL)fail;

@end

BOOL DESHexStringIsValid(NSString *hex);
/* Private functions implemented in DESMessengerHack.c. */
int __DESSetNameOfFriend(Messenger *m, int friendnumber, uint8_t * name);
//int __DESSetUserStatusOfFriend(int friendnumber, USERSTATUS_KIND kind, uint8_t * status, uint16_t length);
int __DESSetUserStatusOfFriend(Messenger *m, int friendnumber, uint8_t * status, uint16_t length);
/* Private function implemented in DESDHTHack.c. */
uint16_t __DESGetNumberOfConnectedNodes(void);
/* Private function implemented in DESMessengerHack.c. */
void __DESEnumerateFriendStatusesUsingBlock(Messenger *m, void(^block)(int idx, int status, char *stop));
/* Private function implemented in DESToxNetworkConnection.m. */
DESFriendStatus __DESCoreStatusToDESStatus(int theStatus);
/* Private callbacks implemented in DESToxNetworkConnection.m */
void __DESCallbackFriendRequest(uint8_t *publicKey, uint8_t *payload, uint16_t length, void *context);
void __DESCallbackNameChange(Messenger *m, int friend, uint8_t *payload, uint16_t length, void *context);
void __DESCallbackUserStatusKind(Messenger *m, int friend, USERSTATUS kind, void *context);
void __DESCallbackUserStatus(Messenger *m, int friend, uint8_t *payload, uint16_t length, void *context);
void __DESCallbackMessage(Messenger *m, int friend, uint8_t *payload, uint16_t length, void *context);
void __DESCallbackAction(Messenger *m, int friend, uint8_t *payload, uint16_t length, void *context);
void __DESCallbackFriendStatus(Messenger *m, int friend, uint8_t newstatus, void *context);
void __DESCallbackReadReceipt(Messenger *m, int friend, uint32_t theid, void *context);
