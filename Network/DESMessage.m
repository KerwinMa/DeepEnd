#import "DESMessage.h"

@implementation DESMessage

+ (instancetype)messageFromSender:(DESFriend *)aFriend content:(NSString *)aString messageID:(NSInteger)mid {
    return [[DESMessage alloc] initWithSender:aFriend messageType:DESMessageTypeChat payload:aString messageID:mid];
}

+ (instancetype)actionFromSender:(DESFriend *)aFriend content:(NSString *)aString {
    return [[DESMessage alloc] initWithSender:aFriend messageType:DESMessageTypeAction payload:aString messageID:-1];
}

+ (instancetype)nickChangeFromSender:(DESFriend *)aFriend newNick:(NSString *)aString {
    return [[DESMessage alloc] initWithSender:aFriend messageType:DESMessageTypeNicknameChange oldAttr:aFriend.displayName newAttr:aString];
}

+ (instancetype)userStatusChangeFromSender:(DESFriend *)aFriend newStatus:(NSString *)aString {
    return [[DESMessage alloc] initWithSender:aFriend messageType:DESMessageTypeUserStatusChange oldAttr:aFriend.userStatus newAttr:aString];
}

+ (instancetype)userStatusTypeChangeFromSender:(DESFriend *)aFriend newStatusType:(DESStatusType)type {
    return [[DESMessage alloc] initWithSender:aFriend messageType:DESMessageTypeStatusTypeChange userStatusType:type];
}

+ (instancetype)statusChangeFromSender:(DESFriend *)aFriend newStatus:(DESFriendStatus)status {
    return [[DESMessage alloc] initWithSender:aFriend messageType:DESMessageTypeStatusChange friendStatus:status];
}

+ (instancetype)systemMessageWithSeverity:(DESSystemMessageType)type content:(NSString *)errorString {
    return [[DESMessage alloc] initWithSeverity:type content:errorString];
}

- (instancetype)initWithSender:(DESFriend *)aFriend messageType:(DESMessageType)type oldAttr:(NSString *)aString newAttr:(NSString *)anotherString {
    self = [super init];
    if (self) {
        _sender = aFriend;
        _oldAttribute = aString;
        _newAttribute = anotherString;
        _type = type;
        _dateReceived = [NSDate date];
    }
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
        _oldValue = aFriend.statusType;
        _newValue = aStatus;
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
        _oldValue = aFriend.status;
        _newValue = aStatus;
        _type = type;
        _messageID = -1;
        _dateReceived = [NSDate date];
    }
    return self;
}

- (instancetype)initWithSeverity:(DESSystemMessageType)type content:(NSString *)aString {
    self = [super init];
    if (self) {
        _content = aString;
        _type = DESMessageTypeSystem;
        _newValue = type;
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

- (void)dealloc {
    DESDebug(@"DESMessage deallocated!");
}

@end
