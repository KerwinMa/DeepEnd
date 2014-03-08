#import "DeepEnd.h"
#import "DESGroupChat.h"
#import "DHT.h"

@interface DESToxNetworkConnection ()

@property (readonly) Tox *m;

@end

@interface DESFriend ()

/* Implemented in DESFriend.m */
- (void)setDisplayName:(NSString *)displayName;
- (void)setUserStatus:(NSString *)userStatus;
- (void)setStatus:(DESFriendStatus)status;
- (void)setStatusType:(DESStatusType)kind;
- (void)setChatContext:(id<DESChatContext>)ctx;
- (void)setOwner:(DESFriendManager *)owner;
+ (instancetype)friendRequestWithAddress:(NSString *)aKey message:(NSString *)theMessage owner:(DESFriendManager *)theOwner;

@end

@interface DESFriendManager ()

- (void)didReceiveNewRequestWithAddress:(NSString *)theKey message:(NSString *)thePayload;
- (void)didReceiveNewGroupRequestWithKey:(NSString *)theKey inviter:(DESFriend *)inviter;
- (void)addContext:(id<DESChatContext>)context;
- (void)removeContext:(id<DESChatContext>)context;

@end

@interface DESMessage ()

- (void)setRead:(BOOL)read;
- (void)setSendFailure:(BOOL)fail;

@end

@interface DESGroupChat ()

- (instancetype)initWithInvitingFriend:(DESFriend *)inviter owner:(DESFriendManager *)owner publicKey:(NSString *)publicKey;
- (void)invalidate;

@end

BOOL DESHexStringIsValid(NSString *hex);
/* Private functions implemented in DESMessengerHack.c. */
int __DESSetNameOfFriend(Tox *m, int friendnumber, uint8_t *name, uint16_t length);
int __DESSetUserStatusOfFriend(Tox *m, int friendnumber, uint8_t *status, uint16_t length);
void __DESEnumerateFriendStatusesUsingBlock(Tox *m, void(^block)(int idx, int status, char *stop));
/* Private functions implemented in DESDHTHack.c. */
uint16_t __DESGetNumberOfConnectedNodes(Tox *tox);
/* Used in experimental DHTReadOnly API. */
void __DESEnumerateCloseDHTNodesWithBlock(DHT *dht, void(^block)(int ind, Client_data *cld, int ipv6));
void __DESEnumerateDHTFriendListWithBlock(DHT *dht, void(^block)(int ind, DHT_Friend *df));
/* Private function implemented in DESToxNetworkConnection.m. */
DESFriendStatus __DESCoreStatusToDESStatus(int theStatus);
/* Private callbacks implemented in DESToxNetworkConnection.m */
void __DESCallbackFriendRequest(uint8_t *publicKey, uint8_t *payload, uint16_t length, void *context);
void __DESCallbackNameChange(Tox *m, int friend, uint8_t *payload, uint16_t length, void *context);
void __DESCallbackUserStatusKind(Tox *m, int32_t friend, TOX_USERSTATUS kind, void *context);
void __DESCallbackUserStatus(Tox *m, int friend, uint8_t *payload, uint16_t length, void *context);
void __DESCallbackMessage(Tox *m, int friend, uint8_t *payload, uint16_t length, void *context);
void __DESCallbackAction(Tox *m, int friend, uint8_t *payload, uint16_t length, void *context);
void __DESCallbackFriendStatus(Tox *m, int friend, uint8_t newstatus, void *context);
void __DESCallbackReadReceipt(Tox *m, int friend, uint32_t theid, void *context);
void __DESCallbackGroupMessage(Tox *m, int groupnumber, int peernum, uint8_t *payload, uint16_t length, void *context);
void __DESCallbackGroupAction(Tox *tox, int groupnumber, int peernum, uint8_t *payload, uint16_t length, void *context);
void __DESCallbackGroupInvite(Tox *tox, int friend, uint8_t *group_public_key, void *context);
