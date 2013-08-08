#import "DeepEnd.h"
#import "DESChatContext.h"

@implementation DESChatContext {
    NSMutableArray *_backlog;
    NSMutableSet *_participants;
    BOOL isPersonal;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _backlog = [[NSMutableArray alloc] initWithCapacity:100];
        _participants = [[NSMutableSet alloc] initWithCapacity:5];
    }
    return self;
}

- (instancetype)initWithParticipants:(NSArray *)participants {
    self = [super init];
    if (self) {
        _backlog = [[NSMutableArray alloc] initWithCapacity:100];
        _participants = [[NSMutableSet alloc] initWithArray:[participants filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            return [evaluatedObject isKindOfClass:[DESFriend class]];
        }]]];
    }
    return self;
}

- (void)setIsPersonal:(BOOL)aBool {
    isPersonal = aBool;
}

- (void)addParticipant:(DESFriend *)theFriend {
    @synchronized(self) {
        [_participants addObject:theFriend];
    }
}

- (void)removeParticipant:(DESFriend *)theFriend {
    @synchronized(self) {
        [_participants removeObject:theFriend];
        [_backlog enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if (obj[@"sender"] == theFriend) {
                obj[@"sender"] = nil;
            }
        }];
    }
}

- (NSArray *)backlogStartingFromDate:(NSDate *)aDate {
    return (NSArray*)_backlog;
}

- (void)pushMessage:(NSString *)aMessage fromParticipant:(DESFriend *)theFriend {
    @synchronized(self) {
        NSDate *theDate = [NSDate date];
        [_backlog addObject:@{@"date": theDate, @"sender": theFriend, @"context": aMessage}];
    }
}

@end
