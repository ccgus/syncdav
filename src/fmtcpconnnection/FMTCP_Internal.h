//
//  TCP_Internal.h
//  MYNetwork
//
//  Created by Jens Alfke on 5/18/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//


#import "FMTCPWriter.h"
#import "FMTCPConnection.h"
#import "FMTCPListener.h"

/* Private declarations and APIs for TCP client/server implementation. */

@interface FMTCPConnection ()
- (void)_setStreamProperty:(id)value forKey:(NSString*)key;
- (void)_streamOpened:(FMTCPStream*)stream;
- (BOOL)_streamPeerCertAvailable:(FMTCPStream*)stream;
- (void)_stream:(FMTCPStream*)stream gotError:(NSError*)error;
- (void)_streamCanClose:(FMTCPStream*)stream;
- (void)_streamGotEOF:(FMTCPStream*)stream;
- (void)_streamDisconnected:(FMTCPStream*)stream;
@end


@interface FMTCPStream ()
- (void)_unclose;
@end


@interface FMTCPEndpoint ()
+ (NSString*)describeCert:(SecCertificateRef)cert;
+ (NSString*)describeIdentity:(SecIdentityRef)identity;
@end

void FMTCPSetObj( id *var, id value );
BOOL FMTCPIfSetObj( id *var, id value );
