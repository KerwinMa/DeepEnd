#import "DeepEnd.h"
#import "net_crypto.h"

/* Declaration of constants in DeepEnd.h */
size_t DESPublicKeySize = crypto_box_PUBLICKEYBYTES;
size_t DESPrivateKeySize = crypto_box_SECRETKEYBYTES;

BOOL DESPublicKeyIsValid(NSString *theKey) {
    if ([theKey length] != 64) {
        return NO;
    } else {
        NSCharacterSet *validSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF1234567890"];
        int i = 0;
        while(i < [theKey length]) {
            if (![validSet characterIsMember:[theKey characterAtIndex:i]]) {
                return NO;
            }
            i++;
        }
    }
    return YES;
}

void DESConvertPublicKeyToData(NSString *theString, uint8_t *theOutput) {
    const char *chars = [theString UTF8String];
    int i = 0, j = 0;
    NSUInteger len = [theString length];
    if ([theString length] != DESPublicKeySize * 2) {
        [[[NSException alloc] initWithName:NSInvalidArgumentException reason:@"Malformed public key" userInfo:nil] raise];
    }
    char byteChars[3] = {'\0','\0','\0'};
    unsigned long wholeByte = 0;
    while (i < len) {
        byteChars[0] = chars[i++];
        byteChars[1] = chars[i++];
        wholeByte = strtoul(byteChars, NULL, 16);
        theOutput[j++] = wholeByte;
    }
}

void DESConvertPrivateKeyToData(NSString *theString, uint8_t *theOutput) {
    const char *chars = [theString UTF8String];
    int i = 0, j = 0;
    NSUInteger len = [theString length];
    if ([theString length] != DESPrivateKeySize * 2) {
        [[[NSException alloc] initWithName:NSInvalidArgumentException reason:@"Malformed private key" userInfo:nil] raise];
    }
    char byteChars[3] = {'\0','\0','\0'};
    unsigned long wholeByte = 0;
    while (i < len) {
        byteChars[0] = chars[i++];
        byteChars[1] = chars[i++];
        wholeByte = strtoul(byteChars, NULL, 16);
        theOutput[j++] = wholeByte;
    }
}

NSString *DESConvertPublicKeyToString(const uint8_t *theData) {
    NSMutableString *theString = [NSMutableString stringWithCapacity:DESPublicKeySize * 2];
    for (NSInteger idx = 0; idx < DESPublicKeySize; ++idx) {
        [theString appendFormat:@"%02X", theData[idx]];
    }
    return (NSString*)theString;
}

NSString *DESConvertPrivateKeyToString(const uint8_t *theData) {
    NSMutableString *theString = [NSMutableString stringWithCapacity:DESPrivateKeySize * 2];
    for (NSInteger idx = 0; idx < DESPrivateKeySize; ++idx) {
        [theString appendFormat:@"%02X", theData[idx]];
    }
    return (NSString*)theString;
}