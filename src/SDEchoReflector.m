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
#import "FMNSStringAdditions.h"

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
    
    FMIPAddress *addr   = [FMIPAddress addressWithHostname:@"localhost" port:7000];
    _server             = [[FMTCPConnection alloc] initToAddress:addr];
    
    NSMutableDictionary *sslProps = [NSMutableDictionary dictionary];
    
    [sslProps setObject:[NSNumber numberWithBool:YES] forKey:kFMTCPPropertySSLAllowsAnyRoot];
    [sslProps setObject:[NSNull null] forKey:(id)kCFStreamSSLPeerName];
    [sslProps setObject:NSStreamSocketSecurityLevelNegotiatedSSL forKey:(id)kCFStreamSSLLevel];
    
    [_server setSSLProperties:sslProps];
    
    [_server setDelegate:self];
    
    [_server open];
    
}



- (void)informFilePUT:(NSString*)relativeFilePath localHash:(NSString*)hash {
    
    if (_authenticated) {
         [[_server writer] writeUTF8StringLine:[NSString stringWithFormat:@"UPDATE %@ %@", hash, relativeFilePath]];
    }
    
}

- (void)informFileDELETE:(NSString*)relativeFilePath {
    
    if (_authenticated) {
        [[_server writer] writeUTF8StringLine:[NSString stringWithFormat:@"DELETE %@", relativeFilePath]];
    }
}

- (void)connectionDidOpen:(FMTCPConnection*)connection {
    
    debug(@"%s:%d", __FUNCTION__, __LINE__);
    
    [[connection reader] setCanReadBlock:^(FMTCPReader *reader) {
        
        if (!_authenticated && _connectionState == SDEchoReflectorAuthenticatingState) {
            NSString *s = [reader stringFromReadData];
            _authenticated = [s hasPrefix:@"OKAUTH"];
            
            debug(@"An important message from our server: '%@'", [s trim]);
            debug(@"_authenticated: %d", _authenticated);
        }
        else if (_authenticated) {
            NSString *s = [reader stringFromReadData];
            debug(@"Got server message: %@", s);
            
            if ([s hasPrefix:@"UPDATE"]) {
                
                #pragma message "FIXME: make sure it's big enough, and check ranges"
                
                NSString *junk = [[s trim] substringFromIndex:7];
                debug(@"junk: '%@'", junk);
                NSInteger idx = [junk rangeOfString:@" "].location;
                
                NSString *hash = [junk substringToIndex:idx];
                NSString *path = [junk substringFromIndex:idx + 1];
                
                [_manager reflector:self sawURIUpdate:path fileHash:hash];
            }
            
        }
        else {
            debug(@"Never got authenticated - why am I getting data?");
        }
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
