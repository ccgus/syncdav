//
//  FMKeychain.h
//  VPxcode
//
//  Created by August Mueller on Fri May 28 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

@interface FMKeychainItem : NSObject {
    NSString *serviceName;
    NSString *accountName;
    NSString *password;
    
    SecKeychainItemRef skItem;
    
}

- (NSString *)serviceName;
- (void)setServiceName:(NSString *)newServiceName;

- (NSString *)accountName;
- (void)setAccountName:(NSString *)newAccountName;

- (NSString *)password;
- (void)setPassword:(NSString *)newPassword;

- (NSString*) genericPassword;
- (void)addGenericPassword:(NSString*)thePassword;

- (void)deletePassword;

+ (id) keychainItemWithService:(NSString *)theServiceName forAccount:(NSString*)theAccountName;
+ (id) keychainItemWithService:(NSString *)theServiceName;

@end
