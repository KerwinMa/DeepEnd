#import "DeepEnd.h"

@interface DESMessage : NSObject

@property (assign) DESFriend *sender;
@property (readonly) DESMessageType type;
@property (strong, readonly) NSString *content;
@property (strong, readonly) NSString *oldAttribute;
@property (strong, readonly, getter=theNewAttribute) NSString *newAttribute;
@property (readonly) NSInteger oldValue;
@property (readonly) NSInteger newValue;
@property (readonly) NSDate *dateReceived;
@property (readonly) BOOL read;
@property (readonly) BOOL failed;
@property (readonly) NSInteger messageID;

+ (instancetype)messageFromSender:(DESFriend *)aFriend content:(NSString *)aString messageID:(NSInteger)mid;
+ (instancetype)actionFromSender:(DESFriend *)aFriend content:(NSString *)aString;
+ (instancetype)nickChangeFromSender:(DESFriend *)aFriend newNick:(NSString *)aString;
+ (instancetype)userStatusChangeFromSender:(DESFriend *)aFriend newStatus:(NSString *)aString;
+ (instancetype)userStatusTypeChangeFromSender:(DESFriend *)aFriend newStatusType:(DESStatusType)type;
+ (instancetype)statusChangeFromSender:(DESFriend *)aFriend newStatus:(DESFriendStatus)status;
+ (instancetype)systemMessageWithSeverity:(DESSystemMessageType)type content:(NSString *)errorString;

@end
