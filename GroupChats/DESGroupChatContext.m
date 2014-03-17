#import "DESGroupChatContext.h"
#import "DESGroupPeer.h"
#import "DeepEnd-Private.h"

@implementation DESGroupChatContext {
    NSMutableSet *_participants;
    NSMutableArray *_backlog;
}

@synthesize maximumBacklogSize = _maximumBacklogSize;
@synthesize friendManager;
@synthesize uuid;
@synthesize name;

- (DESContextType)type {
    return DESContextTypeGroupChat;
}

- (instancetype)initWithParticipants:(NSArray *)participants groupNumber:(NSInteger)gcn {
    self = [super init];
    if (self) {
        _participants = [[NSMutableSet alloc] initWithArray:participants];
        _groupNumber = (int)gcn;
        _maximumBacklogSize = 1000;
        _backlog = [[NSMutableArray alloc] initWithCapacity:self.maximumBacklogSize];
        /* NSUUID is only available in 10.8+, so we must use CF functions
         * to maintain compatibility with 10.6. */
        CFUUIDRef theUUID = CFUUIDCreate(kCFAllocatorDefault);
        CFStringRef s = CFUUIDCreateString(kCFAllocatorDefault, theUUID);
        uuid = [(__bridge NSString*)s copy];
        name = [NSString stringWithFormat:@"Group chat #%li", (long)gcn];
        CFRelease(s);
        CFRelease(theUUID);
    }
    return self;
}

- (NSSet *)participants {
    return [_participants copy];
}

- (NSArray *)backlog {
    return (NSArray*)_backlog;
}

- (void)setMaximumBacklogSize:(NSUInteger)maximumBacklogSize {
    _maximumBacklogSize = maximumBacklogSize;
    _backlog = (NSMutableArray *)[_backlog subarrayWithRange:NSMakeRange(_backlog.count - _maximumBacklogSize, _maximumBacklogSize)];
}

- (void)addParticipant:(DESFriend *)theFriend {
    if (![theFriend isMemberOfClass:[DESFriend class]])
        return;
    tox_invite_friend(self.friendManager.connection.m, theFriend.friendNumber, self.groupNumber);
    DESDebug(@"Inviting %@ to GC %i.", theFriend.displayName, self.groupNumber);
}

- (void)removeParticipant:(DESFriend *)theFriend {
    if (![_participants containsObject:theFriend]) {
        NSLog(@"*** WARNING: You tried to remove %@ from the participant list, but it was never in the participant list.", theFriend);
    }
    [_participants removeObject:theFriend];
}

- (void) CALLS_INTO_CORE_FUNCTIONS sendMessage:(NSString *)message {
    DESFriend *sender = [DESSelf selfWithConnection:self.friendManager.connection];
    int ret = tox_group_message_send(self.friendManager.connection.m, (int)self.groupNumber, (uint8_t*)[message UTF8String], (uint32_t)[message lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
    if (ret != 0) {
        [self pushMessage:[DESMessage messageFromSender:sender content:message messageID:-1]];
    }
}

- (void) CALLS_INTO_CORE_FUNCTIONS sendAction:(NSString *)message {
    DESFriend *sender = [DESSelf selfWithConnection:self.friendManager.connection];
    int ret = tox_group_action_send(self.friendManager.connection.m, (int)self.groupNumber, (uint8_t*)[message UTF8String], (uint32_t)[message lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
    if (ret != 0) {
        [self pushMessage:[DESMessage actionFromSender:sender content:message]];
    }
}

/* Put a message into this context. */
- (void)pushMessage:(DESMessage *)aMessage {
    @synchronized (self) {
        if (_backlog.count > self.maximumBacklogSize - 1) {
            [_backlog removeObjectAtIndex:0];
        }
        NSLog(@"ChatContext pushed message %@.", aMessage);
        [_backlog addObject:aMessage];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DESDidPushMessageToContextNotification object:self userInfo:@{@"message":aMessage}];
    });
}

- (DESGroupPeer *)peerWithID:(int)peernum {
    for (DESGroupPeer *i in _participants) {
        if (i.friendNumber == peernum) {
            return i;
        }
    }
    DESGroupPeer *peer = [[DESGroupPeer alloc] initWithNumber:peernum inGroupChat:self];
    [_participants addObject:peer];
    return peer;
}

- (void)killParticipants {
    [_participants removeAllObjects];
}

- (void)dealloc {
    DESDebug(@"GroupChatContext deallocated!");
}

@end
