//
//  SDUtils.m
//  davsync
//
//  Created by August Mueller on 5/25/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import "SDUtils.h"
#import <CommonCrypto/CommonDigest.h>


@implementation SDUtils

+ (NSString*)md5ForData:(NSData*)data {
    
	const char *cStr = [data bytes];
	unsigned char digest[CC_MD5_DIGEST_LENGTH];
    
	CC_MD5( cStr, [data length], digest );
	
    NSString* s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
				   digest[0], digest[1], 
				   digest[2], digest[3],
				   digest[4], digest[5],
				   digest[6], digest[7],
				   digest[8], digest[9],
				   digest[10], digest[11],
				   digest[12], digest[13],
				   digest[14], digest[15]];
	
    return s;
	
}

+ (NSString*)stringValueFromHeaders:(NSDictionary*)headers forKey:(NSString*)inKey {
    
    inKey = [inKey lowercaseString];
    
    NSString *ret = 0x00;
    
    for (NSString *key in [headers allKeys]) {
        
        NSString *fixedKey = [key lowercaseString];
        
        if ([fixedKey isEqualToString:inKey]) {
            ret = [headers valueForKey:key];
            break;
        }
    }
    
    return ret;
}

+ (NSString*)makeStrongEtag:(NSString*)etag {
    
    if ([etag hasPrefix:@"W/"]) {
        return [etag substringFromIndex:2];
    }
    
    return etag;
}

+ (NSString*)computerName {
    return [(id)CSCopyMachineName() autorelease];
}

@end
