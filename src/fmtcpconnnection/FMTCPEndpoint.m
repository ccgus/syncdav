//
//  BLIPEndpoint.m
//  MYNetwork
//
//  Created by Jens Alfke on 5/14/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import "FMTCPEndpoint.h"

//#import "CollectionUtils.h"
//#import "ExceptionUtils.h"
#import <Security/Security.h>


NSString* const kTCPPropertySSLClientSideAuthentication = @"kTCPPropertySSLClientSideAuthentication";


@implementation FMTCPEndpoint

@synthesize SSLProperties=_sslProperties;

- (void)dealloc {
    [_sslProperties release];
    [super dealloc];
}


- (void)setSSLProperty:(id)value forKey:(NSString*)key {
    
    if (value) {
        
        if (!_sslProperties) {
            _sslProperties = [[NSMutableDictionary alloc] init];
        }
            
        [_sslProperties setObject:value forKey:key];
    }
    else {
        [_sslProperties removeObjectForKey:key];
    }
}

- (NSString*)securityLevel {
    return [_sslProperties objectForKey:(id)kCFStreamSSLLevel];
}

- (void)setSecurityLevel:(NSString*)level {
    [self setSSLProperty:level forKey:(id)kCFStreamSSLLevel];
}

- (void)setPeerToPeerIdentity:(SecIdentityRef)identity {
    FMAssert(identity);
        
    NSMutableDictionary *newSSLProps = [NSMutableDictionary dictionary];
    
    [newSSLProps setObject:(id)kCFStreamSSLLevel forKey:NSStreamSocketSecurityLevelTLSv1];
    [newSSLProps setObject:kFMTCPPropertySSLCertificates forKey:[NSArray arrayWithObject:(id)identity]];
    [newSSLProps setObject:kFMTCPPropertySSLAllowsAnyRoot forKey:[NSNumber numberWithBool:YES]];
    [newSSLProps setObject:kFMTCPPropertySSLPeerName forKey:[NSNull null]];
    [newSSLProps setObject:kTCPPropertySSLClientSideAuthentication forKey:[NSNumber numberWithInt:kFMTCPAlwaysAuthenticate]];
    
}

- (void)tellDelegate:(SEL)selector withObject:(id)param {
    if ([_delegate respondsToSelector:selector]) {
        [_delegate performSelector:selector withObject:self withObject:param];
    }
}


+ (NSString*) describeCert: (SecCertificateRef)cert {
    if (!cert)
        return @"(null)";
    NSString *desc;
#if TARGET_OS_IPHONE && !defined(__SEC_TYPES__)
    CFStringRef summary = NULL;
    SecCertificateCopySubjectSummary(cert);
    desc = $sprintf(@"Certificate[%@]", summary);
    if(summary) CFRelease(summary);
#else
    CFStringRef name=NULL;
    CFArrayRef emails=NULL;
    SecCertificateCopyCommonName(cert, &name);
    SecCertificateCopyEmailAddresses(cert, &emails);
    desc = [NSString stringWithFormat:@"Certificate[\"%@\", <%@>]", name, [(NSArray*)emails componentsJoinedByString: @">, <"]];
    if(name) CFRelease(name);
    if(emails) CFRelease(emails);
#endif
    return desc;
}

+ (NSString*) describeIdentity: (SecIdentityRef)identity {
    if (!identity) {
        return @"(null)";
    }
        
    SecCertificateRef cert;
    SecIdentityCopyCertificate(identity, &cert);
    return [NSString stringWithFormat:@"Identity[%@]", [self describeCert: cert]];
}


@end


/*
 Copyright (c) 2008, Jens Alfke <jens@mooseyard.com>. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted
 provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions
 and the following disclaimer in the documentation and/or other materials provided with the
 distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND 
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRI-
 BUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
 THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
