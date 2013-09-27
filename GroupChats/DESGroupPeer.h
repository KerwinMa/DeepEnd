#import <Foundation/Foundation.h>
#import "DeepEnd.h"

@class DESGroupChatContext;
@interface DESGroupPeer : DESFriend

- (instancetype)initWithNumber:(int)friendNumber inGroupChat:(DESGroupChatContext *)ctx;

@end
