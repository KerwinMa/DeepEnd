#import "DeepEnd.h"
#import "DESChatContext.h"

NSString *const DESDidPushMessageToContextNotification = @"DESDidPushMessageToContextNotification";

@implementation DESChatContext

- (instancetype)initWithPartner:(DESFriend *)aFriend {
    [[NSException exceptionWithName:@"DESAbstractClassException" reason:@"You cannot use the abstract class DESChatContext." userInfo:nil] raise];
    return nil;
}

- (instancetype)initWithParticipants:(NSArray *)participants {
    [[NSException exceptionWithName:@"DESAbstractClassException" reason:@"You cannot use the abstract class DESChatContext." userInfo:nil] raise];
    return nil;
}

- (void)addParticipant:(DESFriend *)theFriend {
    [[NSException exceptionWithName:@"DESAbstractClassException" reason:@"You cannot use the abstract class DESChatContext." userInfo:nil] raise];
    return;
}

- (void)removeParticipant:(DESFriend *)theFriend {
    [[NSException exceptionWithName:@"DESAbstractClassException" reason:@"You cannot use the abstract class DESChatContext." userInfo:nil] raise];
    return;
}

- (void)sendMessage:(NSString *)message {
    [[NSException exceptionWithName:@"DESAbstractClassException" reason:@"You cannot use the abstract class DESChatContext." userInfo:nil] raise];
    return;
}

@end
