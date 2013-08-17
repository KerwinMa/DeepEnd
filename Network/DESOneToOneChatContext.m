#import "DESOneToOneChatContext.h"
#import "DeepEnd-Private.h"

@implementation DESOneToOneChatContext {
    DESFriend *partner;
    NSMutableArray *_backlog;
}

@synthesize maximumBacklogSize = _maximumBacklogSize;
@synthesize backlog;
@synthesize friendManager;

- (instancetype)initWithParticipants:(NSArray *)participants {
    return [self initWithPartner:participants[0]];
}

- (instancetype)initWithPartner:(DESFriend *)aFriend {
    self = [super init];
    if (self) {
        partner = aFriend;
        _maximumBacklogSize = 1000;
        _backlog = [[NSMutableArray alloc] initWithCapacity:self.maximumBacklogSize];
    }
    return self;
}

- (NSSet *)participants {
    return [[NSSet alloc] initWithObjects:partner, nil];
}

- (NSArray *)backlog {
    return (NSArray*)_backlog;
}

- (void)setMaximumBacklogSize:(NSUInteger)maximumBacklogSize {
    _maximumBacklogSize = maximumBacklogSize;
    _backlog = (NSMutableArray *)[_backlog subarrayWithRange:NSMakeRange(_backlog.count - _maximumBacklogSize, _maximumBacklogSize)];
}

- (void)addParticipant:(DESFriend *)theFriend {
    NSLog(@"WARNING: DESOneToOneChatContext does not support multiple participants. Calling addParticipant and removeParticipant will fail and print this warning.");
}

- (void)removeParticipant:(DESFriend *)theFriend {
    NSLog(@"WARNING: DESOneToOneChatContext does not support multiple participants. Calling addParticipant and removeParticipant will fail and print this warning.");
}

/* TODO: support languages where spaces aren't used to separate words (e.g. hanzi-based systems) */
- (void) CALLS_INTO_CORE_FUNCTIONS sendMessage:(NSString *)message {
    DESFriend *sender = [DESSelf selfWithConnection:self.friendManager.connection];
    if (partner.status != DESFriendStatusOnline) {
        return;
    }
    NSArray *messageWords = [message componentsSeparatedByString:@" "];
    NSMutableArray *partial = [[NSMutableArray alloc] initWithCapacity:[messageWords count]];
    NSUInteger messageLength = 0;
    for (NSString *word in messageWords) {
        if (messageLength + [word lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1 > MAX_MESSAGE_LENGTH) {
            NSString *payload = [partial componentsJoinedByString:@" "];
            uint32_t returnValue = m_sendmessage(self.friendManager.connection.m, partner.friendNumber, (uint8_t*)[payload UTF8String], (uint16_t)[payload lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
            DESMessage *constructed = [DESMessage messageFromSender:sender content:payload messageID:returnValue];
            [self pushMessage:constructed];
            [partial removeAllObjects];
        }
        [partial addObject:word];
        messageLength += [word lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
    }
    if ([partial count] != 0) {
        NSString *payload = [partial componentsJoinedByString:@" "];
        uint32_t returnValue = m_sendmessage(self.friendManager.connection.m, partner.friendNumber, (uint8_t*)[payload UTF8String], (uint16_t)[payload lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
        DESMessage *constructed = [DESMessage messageFromSender:sender content:payload messageID:returnValue];
        [self pushMessage:constructed];
        [partial removeAllObjects];
    }
}

/* Put a message into this context. */
- (void)pushMessage:(DESMessage *)aMessage {
    if (_backlog.count > self.maximumBacklogSize - 1) {
        [_backlog removeObjectAtIndex:0];
    }
    NSLog(@"ChatContext pushed message %@.", aMessage);
    [_backlog addObject:aMessage];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DESDidPushMessageToContextNotification object:self userInfo:@{@"message": aMessage}];
    });
}

@end
