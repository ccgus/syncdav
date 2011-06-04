//
//  FMKeychain.m
//  VPxcode
//
//  Created by August Mueller on Fri May 28 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "FMKeychainItem.h"


@implementation FMKeychainItem

+ (id) keychainItemWithService:(NSString *)theServiceName forAccount:(NSString*)theAccountName {
    FMKeychainItem *fk = [[[FMKeychainItem alloc] init] autorelease];
    
    [fk setServiceName:theServiceName];
    [fk setAccountName:theAccountName];
    
    return fk;
}

+ (id) keychainItemWithService:(NSString *)theServiceName {
    FMKeychainItem *fk = [[[FMKeychainItem alloc] init] autorelease];
    
    [fk setServiceName:theServiceName];
    [fk setAccountName:[NSHomeDirectory() lastPathComponent]];
    
    return fk;
}

- (void)dealloc {
    [serviceName autorelease];
    [accountName autorelease];
    [password autorelease];

    serviceName = nil;
    accountName = nil;
    password = nil;

    [super dealloc];
}



- (NSString *)serviceName {
    return serviceName; 
}

- (void)setServiceName:(NSString *)newServiceName {
    [newServiceName retain];
    [serviceName release];
    serviceName = newServiceName;
}


- (NSString *)accountName {
    return accountName; 
}

- (void)setAccountName:(NSString *)newAccountName {
    [newAccountName retain];
    [accountName release];
    accountName = newAccountName;
}


- (NSString *)password {
    return password; 
}

- (void)setPassword:(NSString *)newPassword {
    [newPassword retain];
    [password release];
    password = newPassword;
}



- (NSString*) genericPassword {
    
    UInt32 retrievedPasswordLength;
    void *retrievedPasswordData;
    OSStatus kcStatus;
    
    kcStatus =  SecKeychainFindGenericPassword( nil,
                                                strlen([serviceName UTF8String]),
                                                [serviceName UTF8String],
                                                strlen([accountName UTF8String]),
                                                [accountName UTF8String],
                                                &retrievedPasswordLength,
                                                &retrievedPasswordData,
                                                &skItem);
    
    // woot, password is there.
    if (kcStatus == 0) {
        NSString *junk = [[[NSString alloc] initWithBytes:retrievedPasswordData
                                                   length:retrievedPasswordLength
                                                 encoding:NSUTF8StringEncoding] autorelease];
        
        [self setPassword:junk];
        
        SecKeychainItemFreeContent(NULL, retrievedPasswordData);
        
    }
    else {
        [self setPassword:nil];
    }
    
    return [self password];
}

- (void) addGenericPassword:(NSString*)thePassword {
   
   if (!thePassword) {
       return;
   }
   
    OSStatus kcStatus;
    NSData *passwordData = [thePassword dataUsingEncoding:NSUTF8StringEncoding];
    
    kcStatus =  SecKeychainAddGenericPassword(  nil,
                                                strlen([serviceName UTF8String]),
                                                [serviceName UTF8String],
                                                strlen([accountName UTF8String]),
                                                [accountName UTF8String],
                                                [passwordData length],
                                                [passwordData bytes],
                                                &skItem);
    
    // woot, all is good
    if (kcStatus == 0) {
        [self setPassword:thePassword];
    }
    else if (kcStatus == errSecDuplicateItem) {
        
        // egads, it's already there.
        
        // skItem will be setup in genericPassword password, so we can use it to delete later on.
        NSString *currentPassword = [self genericPassword];
        if ([thePassword isEqualToString:currentPassword]) {
            // no big deal.. it's already there.
            return;
        }
        
        // let's remove it, and put it again.
        kcStatus = SecKeychainItemDelete(skItem);
        if (kcStatus == 0) {
             [self addGenericPassword:thePassword];
             return;
        }
        else {
            NSLog(@"error in SecKeychainItemDelete: %d", (int)kcStatus);
        }
        
        [self setPassword:nil];
    }
    else {
        [self setPassword:nil];
    }
}

- (void) deletePassword {
    // can we even find a password? (and load up skItem)
    if ([self genericPassword]) {
        OSStatus kcStatus = SecKeychainItemDelete(skItem);
        if (kcStatus != 0) {
            debug(@"error deleting keychaing item: %d", (int)kcStatus);
        }
    }
    [self setPassword:nil];
}

@end
