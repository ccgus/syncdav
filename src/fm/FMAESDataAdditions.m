#import "FMAESDataAdditions.h"

#import <CommonCrypto/CommonCryptor.h>

@implementation NSData (FMAESDataAdditions)

- (NSData*)AESEncryptWithKey:(NSString *)passKey {
    
    // http://iphonedevelopment.blogspot.com/2009/02/strong-encryption-for-cocoa-cocoa-touch.html
    
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyBuffer[kCCKeySizeAES128+1];    // room for terminator (unused)
    bzero(keyBuffer, sizeof(keyBuffer));   // fill with zeroes (for padding)
    
    [passKey getCString:keyBuffer maxLength:sizeof(keyBuffer) encoding:NSUTF8StringEncoding];
    
    size_t numBytesEncrypted = 0;
    #pragma message "FIXME: I think these values might be a bit off.  Shouldn't it be kCCKeySizeAES128?"
    size_t returnLength      = ([self length] + kCCKeySizeAES256) & ~(kCCKeySizeAES256 - 1);
    char   *returnBuffer     = malloc(returnLength * sizeof(uint8_t));
    
    CCCryptorStatus result = CCCrypt(kCCEncrypt, kCCAlgorithmAES128 , kCCOptionPKCS7Padding | kCCOptionECBMode,
                                     keyBuffer, kCCKeySizeAES128, nil,
                                     [self bytes], [self length], 
                                     returnBuffer, returnLength,
                                     &numBytesEncrypted);
    
    if (result == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:returnBuffer length:numBytesEncrypted freeWhenDone:YES];
    }
    else {
        NSLog(@"error encrypting: %d", result);
        return nil;
    }
}

- (NSData*)AESDecryptWithKey:(NSString *)passKey {
    
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyBuffer[kCCKeySizeAES128+1];    // room for terminator (unused)
    bzero(keyBuffer, sizeof(keyBuffer));   // fill with zeroes (for padding)
    
    [passKey getCString:keyBuffer maxLength:sizeof(keyBuffer) encoding:NSUTF8StringEncoding];
    
    size_t numBytesEncrypted = 0;
    size_t returnLength      = ([self length] + kCCKeySizeAES256) & ~(kCCKeySizeAES256 - 1);
    char   *returnBuffer     = malloc(returnLength * sizeof(uint8_t));
    
    CCCryptorStatus result = CCCrypt(kCCDecrypt, kCCAlgorithmAES128 , kCCOptionPKCS7Padding | kCCOptionECBMode,
                                     keyBuffer, kCCKeySizeAES128, nil,
                                     [self bytes], [self length], 
                                     returnBuffer, returnLength,
                                     &numBytesEncrypted);
    
    if (result == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:returnBuffer length:numBytesEncrypted freeWhenDone:YES];
    }
    else {
        NSLog(@"error decrypting: %d", result);
        return nil;
    }
}

@end








