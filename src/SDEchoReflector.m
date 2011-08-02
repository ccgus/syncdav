//
//  SDEchoReflector.m
//  syncdav
//
//  Created by August Mueller on 8/1/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import "SDEchoReflector.h"
#import "FMTCPStream.h"
#import "FMTCPWriter.h"

@implementation SDEchoReflector

@synthesize hostname = _hostname;
@synthesize password = _password;
@synthesize port = _port;
@synthesize manager = _manager;

+ (id)reflectorWithHostname:(NSString*)host port:(int)port password:(NSString*)password manager:(SDManager*)manager {
    
    SDEchoReflector *me = [[[self alloc] init] autorelease];
    
    [me setHostname:host];
    [me setPort:port];
    [me setPassword:password];
    [me setManager:manager];
    
    return me;
}

- (void)dealloc {
    
    FMRelease(_hostname);
    
    [super dealloc];
}

- (void)connect {
    
    _connectionState = SDEchoReflectorConnectingState;
    
    FMIPAddress *addr     = [FMIPAddress addressWithHostname:@"localhost" port:7000];
    FMTCPConnection *conn = [[FMTCPConnection alloc] initToAddress:addr];
    
    NSMutableDictionary *sslProps = [NSMutableDictionary dictionary];
    
    [sslProps setObject:[NSNumber numberWithBool:YES] forKey:kFMTCPPropertySSLAllowsAnyRoot];
    [sslProps setObject:[NSNull null] forKey:(id)kCFStreamSSLPeerName];
    [sslProps setObject:NSStreamSocketSecurityLevelNegotiatedSSL forKey:(id)kCFStreamSSLLevel];
    
    [conn setSSLProperties:sslProps];
    
    [conn setDelegate:self];
    
    [conn open];
    
}



- (void)fileWasPUT:(NSString*)filePath {
    
}


- (void)connectionDidOpen:(FMTCPConnection*)connection {
    
    debug(@"%s:%d", __FUNCTION__, __LINE__);
    
    [[connection reader] setCanReadBlock:^(FMTCPReader *reader) {
        
        if (!_authenticated && _connectionState == SDEchoReflectorAuthenticatingState) {
            NSString *s = [reader stringFromReadData];
            _authenticated = [s hasPrefix:@"OK"];
            
            if (!_authenticated) {
                debug(@"BUMMER, bad password!");
            }
            
        }
        else if (_authenticated) {
            
        }
        else {
            debug(@"Never got authenticated - why am I getting data?");
        }
        
        
        //[[connection writer] writeUTF8StringLine:@"Hi"];
        
    }];
    
    _connectionState = SDEchoReflectorAuthenticatingState;
    
    [[connection writer] writeUTF8StringLine:[NSString stringWithFormat:@"PASS %@", _password]];
}

- (void)connection:(FMTCPConnection*)connection failedToOpen:(NSError*)error {
    debug(@"%s:%d", __FUNCTION__, __LINE__);
}

- (BOOL)connection:(FMTCPConnection*)connection authorizeSSLPeer:(SecCertificateRef)peerCert {
    return peerCert != nil;
}

- (void)connectionDidClose:(FMTCPConnection*)connection {
    debug(@"%s:%d", __FUNCTION__, __LINE__);
}


@end
