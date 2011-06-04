//
//  SDUtils.h
//  davsync
//
//  Created by August Mueller on 5/25/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SDUtils : NSObject {

}

+ (NSString*)md5ForData:(NSData*)data;

+ (NSString*)stringValueFromHeaders:(NSDictionary*)headers forKey:(NSString*)key;

+ (NSString*)makeStrongEtag:(NSString*)etag;

+ (NSString*)computerName;

@end



