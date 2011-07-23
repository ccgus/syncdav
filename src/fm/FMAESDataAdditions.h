
#import <Foundation/Foundation.h>

@interface NSData (FMAESDataAdditions)

- (NSData*)AESEncryptWithKey:(NSString *)passKey;
- (NSData*)AESDecryptWithKey:(NSString *)passKey;

@end
