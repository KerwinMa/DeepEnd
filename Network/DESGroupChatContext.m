#import "DESGroupChatContext.h"
#import "DeepEnd-Private.h"

@implementation DESGroupChatContext {
    NSMutableSet *_participants;
    NSMutableArray *_backlog;
    NSInteger groupNumber;
}

@synthesize maximumBacklogSize = _maximumBacklogSize;
@synthesize backlog;
@synthesize friendManager;
@synthesize uuid;
@synthesize name;

- (instancetype)initWithParticipants:(NSArray *)participants {
    [[NSException exceptionWithName:@"" reason:@"" userInfo:nil] raise];
    return nil;
}

- (instancetype)initWithParticipants:(NSArray *)participants groupNumber:(NSInteger)gcn {
    self = [super init];
    if (self) {
        _participants = [[NSMutableSet alloc] initWithArray:participants];
        groupNumber = gcn;
        _maximumBacklogSize = 1000;
        _backlog = [[NSMutableArray alloc] initWithCapacity:self.maximumBacklogSize];
        /* NSUUID is only available in 10.8+, so we must use CF functions
         * to maintain compatibility with 10.6. */
        CFUUIDRef theUUID = CFUUIDCreate(kCFAllocatorDefault);
        CFStringRef s = CFUUIDCreateString(kCFAllocatorDefault, theUUID);
        uuid = [(__bridge NSString*)s copy];
        CFRelease(s);
        CFRelease(theUUID);
    }
    return self;
}

- (instancetype)initWithPartner:(DESFriend *)aFriend {
    return [self initWithParticipants:@[aFriend]];
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
    [_participants addObject:theFriend];
}

- (void)removeParticipant:(DESFriend *)theFriend {
    if (![_participants containsObject:theFriend]) {
        NSLog(@"*** WARNING: You tried to remove %@ from the participant list, but it was never in the participant list.", theFriend);
    }
    [_participants removeObject:theFriend];
}

- (void) CALLS_INTO_CORE_FUNCTIONS sendMessage:(NSString *)message {
    DESFriend *sender = [DESSelf selfWithConnection:self.friendManager.connection];
    int ret = tox_group_message_send(self.friendManager.connection.m, (int)groupNumber, (uint8_t*)[message UTF8String], (uint32_t)[message lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
    if (ret != 0) {
        [self pushMessage:[DESMessage messageFromSender:sender content:message messageID:-1]];
    }
}

- (void) CALLS_INTO_CORE_FUNCTIONS sendAction:(NSString *)message {
    return; /* FIXME: no implementation */
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

- (void)dealloc {
    DESDebug(@"GroupChatContext deallocated!");
}

@end
