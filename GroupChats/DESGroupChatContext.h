#import "DeepEnd.h"

@class DESGroupPeer;
@interface DESGroupChatContext : NSObject <DESChatContext>

@property (readonly) int groupNumber;

- (instancetype)initWithParticipants:(NSArray *)participants groupNumber:(NSInteger)gcn;
- (DESGroupPeer *)peerWithID:(int)peernum;
/* Empty the participant array. */
- (void)killParticipants;

@end
