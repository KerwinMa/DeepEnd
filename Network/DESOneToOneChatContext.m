#import "DESOneToOneChatContext.h"
#import "DeepEnd-Private.h"

@implementation DESOneToOneChatContext {
    DESFriend *partner;
    NSMutableArray *_backlog;
}

@synthesize maximumBacklogSize = _maximumBacklogSize;
@synthesize backlog;
@synthesize friendManager;
@synthesize uuid;

- (instancetype)initWithParticipants:(NSArray *)participants {
    return [self initWithPartner:participants[0]];
}

- (instancetype)initWithPartner:(DESFriend *)aFriend {
    self = [super init];
    if (self) {
        partner = aFriend;
        _maximumBacklogSize = 1000;
        _backlog = [[NSMutableArray alloc] initWithCapacity:self.maximumBacklogSize];
        /* NSUUID is only available in 10.8+, so we must use CF functions
         * to maintain compatibility with 10.6. */
        CFUUIDRef theUUID = CFUUIDCreateFromString(kCFAllocatorDefault, (__bridge CFStringRef)aFriend.publicKey);
        CFStringRef s = CFUUIDCreateString(kCFAllocatorDefault, theUUID);
        uuid = [(__bridge NSString*)s copy];
        CFRelease(s);
        CFRelease(theUUID);
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

- (void) CALLS_INTO_CORE_FUNCTIONS sendMessage:(NSString *)message {
    DESFriend *sender = [DESSelf selfWithConnection:self.friendManager.connection];
    if (partner.status != DESFriendStatusOnline) {
        return;
    }
    int ret = tox_sendmessage(self.friendManager.connection.m, partner.friendNumber, (uint8_t*)[message UTF8String], (uint32_t)[message lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
    if (ret) {
        [self pushMessage:[DESMessage messageFromSender:sender content:message messageID:-1]];
    }
}

- (void) CALLS_INTO_CORE_FUNCTIONS sendAction:(NSString *)message {
    DESFriend *sender = [DESSelf selfWithConnection:self.friendManager.connection];
    if (partner.status != DESFriendStatusOnline) {
        return;
    }
    int ret = tox_sendaction(self.friendManager.connection.m, partner.friendNumber, (uint8_t*)[message UTF8String], (uint32_t)[message lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
    if (ret) {
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

- (void)dealloc {
    DESDebug(@"O2OChatContext deallocated!");
}

@end
