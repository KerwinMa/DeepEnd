#import "DeepEnd.h"
#import "DeepEnd-Private.h"

@interface DESOneToOneChatContext : NSObject <DESChatContext>

- (instancetype)initWithPartner:(DESFriend *)aFriend;

@end
