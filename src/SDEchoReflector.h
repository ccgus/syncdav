//
//  SDEchoReflector.h
//  syncdav
//
//  Created by August Mueller on 8/1/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SDManager.h"
#import "FMTCPConnection.h"

typedef enum {
    SDEchoReflectorConnectingState = 1,
    SDEchoReflectorAuthenticatingState,
} SDEchoReflectorConnectionState;

@interface SDEchoReflector : NSObject <SDReflector, FMTCPConnectionDelegate> {
    
    NSString *_hostname;
    NSString *_password;
    int       _port;
    
    __weak SDManager *_manager;
    
    BOOL _authenticated;
    
    int _connectionState;
}

@property (retain) NSString *hostname;
@property (retain) NSString *password;
@property (assign) int port;
@property (weak) SDManager *manager;

+ (id)reflectorWithHostname:(NSString*)host port:(int)port password:(NSString*)password manager:(SDManager*)manager;

- (void)connect;

@end
