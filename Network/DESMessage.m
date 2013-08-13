#import "DESMessage.h"

@implementation DESMessage

+ (instancetype)messageFromSender:(DESFriend *)aFriend content:(NSString *)aString messageID:(NSInteger)mid {
    return [[DESMessage alloc] initWithSender:aFriend messageType:DESMessageTypeChat payload:aString messageID:mid];
}

+ (instancetype)actionFromSender:(DESFriend *)aFriend content:(NSString *)aString {
    return [[DESMessage alloc] initWithSender:aFriend messageType:DESMessageTypeAction payload:aString];
}

+ (instancetype)nickChangeFromSender:(DESFriend *)aFriend newNick:(NSString *)aString {
    return [[DESMessage alloc] initWithSender:aFriend messageType:DESMessageTypeNicknameChange payload:aString];
}

+ (instancetype)userStatusChangeFromSender:(DESFriend *)aFriend newStatus:(NSString *)aString {
    return [[DESMessage alloc] initWithSender:aFriend messageType:DESMessageTypeUserStatusChange payload:aString];
}

+ (instancetype)userStatusTypeChangeFromSender:(DESFriend *)aFriend newStatusType:(DESStatusType)type {
    return [[DESMessage alloc] initWithSender:aFriend messageType:DESMessageTypeUserStatusChange userStatusType:type];
}

+ (instancetype)statusChangeFromSender:(DESFriend *)aFriend newStatus:(DESFriendStatus)status {
    return [[DESMessage alloc] initWithSender:aFriend messageType:DESMessageTypeStatusChange friendStatus:status];
}

- (instancetype)initWithSender:(DESFriend *)aFriend messageType:(DESMessageType)type payload:(NSString *)aString {
    self = [self initWithSender:aFriend messageType:type payload:aString messageID:-1];
    return self;
}

- (instancetype)initWithSender:(DESFriend *)aFriend messageType:(DESMessageType)type payload:(NSString *)aString messageID:(NSInteger)mid {
    self = [super init];
    if (self) {
        _sender = aFriend;
        _content = aString;
        _type = type;
        _messageID = mid;
        _dateReceived = [NSDate date];
    }
    return self;
}

- (instancetype)initWithSender:(DESFriend *)aFriend messageType:(DESMessageType)type userStatusType:(DESStatusType)aStatus {
    self = [super init];
    if (self) {
        _sender = aFriend;
        _statusType = aStatus;
        _type = type;
        _messageID = -1;
        _dateReceived = [NSDate date];
    }
    return self;
}

- (instancetype)initWithSender:(DESFriend *)aFriend messageType:(DESMessageType)type friendStatus:(DESFriendStatus)aStatus {
    self = [super init];
    if (self) {
        _sender = aFriend;
        _friendStatus = aStatus;
        _type = type;
        _messageID = -1;
        _dateReceived = [NSDate date];
    }
    return self;
}

- (void)setRead:(BOOL)read {
    [self willChangeValueForKey:@"read"];
    _read = read;
    [self didChangeValueForKey:@"read"];
}

- (void)setSendFailure:(BOOL)fail {
    [self willChangeValueForKey:@"failed"];
    _failed = fail;
    [self didChangeValueForKey:@"failed"];
}

@end
