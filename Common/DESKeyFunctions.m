#import "DeepEnd.h"
#import "DeepEnd-Private.h"
#import "net_crypto.h"
#import <sodium/crypto_box.h>

/* Declaration of constants in DeepEnd.h */
const size_t DESPublicKeySize = crypto_box_PUBLICKEYBYTES;
const size_t DESPrivateKeySize = crypto_box_SECRETKEYBYTES;

BOOL DESPublicKeyIsValid(NSString *theKey) {
    if ([theKey length] != DESPublicKeySize * 2) {
        return NO;
    } else {
        return DESHexStringIsValid(theKey);
    }
    return YES;
}

BOOL DESPrivateKeyIsValid(NSString *theKey) {
    if ([theKey length] != DESPrivateKeySize * 2) {
        return NO;
    } else {
        return DESHexStringIsValid(theKey);
    }
    return YES;
}

BOOL DESFriendAddressIsValid(NSString *theAddr) {
    if ([theAddr length] != DESFriendAddressSize * 2) {
        return NO;
    } else {
        return DESHexStringIsValid(theAddr);
    }
    return YES;
}

BOOL DESHexStringIsValid(NSString *hex) {
    NSCharacterSet *validSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF1234567890"];
    int i = 0;
    while(i < [hex length]) {
        if (![validSet characterIsMember:[hex characterAtIndex:i]]) {
            return NO;
        }
        i++;
    }
    return YES;
}

void DESConvertPublicKeyToData(NSString *theString, uint8_t *theOutput) {
    const char *chars = [theString UTF8String];
    int i = 0, j = 0;
    NSUInteger len = [theString length];
    if (!DESPublicKeyIsValid(theString)) {
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
    if (!DESPrivateKeyIsValid(theString)) {
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

void DESConvertFriendAddressToData(NSString *theString, uint8_t *theOutput) {
    const char *chars = [theString UTF8String];
    int i = 0, j = 0;
    NSUInteger len = [theString length];
    if (!DESFriendAddressIsValid(theString)) {
        [[[NSException alloc] initWithName:NSInvalidArgumentException reason:@"Malformed friend address" userInfo:nil] raise];
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

NSString *DESConvertFriendAddressToString(const uint8_t *theData) {
    NSMutableString *theString = [NSMutableString stringWithCapacity:DESFriendAddressSize * 2];
    for (NSInteger idx = 0; idx < DESFriendAddressSize; ++idx) {
        [theString appendFormat:@"%02X", theData[idx]];
    }
    return (NSString*)theString;
}

BOOL DESValidateKeyPair(const uint8_t *privateKey, const uint8_t *publicKey) {
    /* This function is a bit... expensive. */
    uint8_t *temp_pub = malloc(DESPublicKeySize);
    uint8_t *temp_priv = malloc(DESPrivateKeySize);
    int success = crypto_box_keypair(temp_pub, temp_priv);
    if (success != 0) {
        free(temp_priv);
        free(temp_pub);
        return NO;
    }
    uint8_t *nonce = malloc(crypto_box_NONCEBYTES);
    random_nonce(nonce);
    NSString *challenge = @"DESKeyIsValid-af893fhwoeg8u"; /* Maybe generate a random string instead. */
    size_t mlen = crypto_box_ZEROBYTES + [challenge lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    uint8_t *encrypted = calloc(mlen, 1);
    uint8_t *message = calloc(mlen, 1);
    memcpy(message + crypto_box_ZEROBYTES, [challenge UTF8String], [challenge lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    crypto_box(encrypted, message, mlen, nonce, publicKey, temp_priv);
    memset(message, 0, mlen);
    crypto_box_open(message, encrypted, mlen, nonce, temp_pub, privateKey);
    NSString *verify = [[NSString alloc] initWithBytes:message + crypto_box_ZEROBYTES length:mlen - crypto_box_ZEROBYTES encoding:NSUTF8StringEncoding];
    free(temp_priv);
    free(temp_pub);
    free(message);
    free(encrypted);
    free(nonce);
    if ([verify isEqualToString:challenge])
        return YES;
    else
        return NO;
}
