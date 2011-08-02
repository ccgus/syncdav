//
//  TCPConnection.m
//  MYNetwork
//
//  Created by Jens Alfke on 5/18/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import "FMTCP_Internal.h"
//#import "FMIPAddress.h"
//#import "MYBonjourService.h"

//#import "Logging.h"
//#import "Test.h"
//#import "ExceptionUtils.h"

#pragma message "FIXME: get rid of these."

void FMTCPSetObj( id *var, id value ) {
    if (value != *var) {
        [*var release];
        *var = [value retain];
    }
}

BOOL FMTCPIfSetObj( id *var, id value ) {
    if (value != *var && ![value isEqual:*var] ) {
        [*var release];
        *var = [value retain];
        return YES;
    }
    else {
        return NO;
    }
}

#if TARGET_OS_IPHONE && !defined(__SEC_TYPES__)
// SecureTransport.h is missing on iPhone, with its SSL constants:
enum{
    errSSLClosedAbort 			= -9806,	/* connection closed via error */
};
#endif



NSString* const FMTCPErrorDomain = @"TCP";


@interface FMTCPConnection ()
@property FMTCPConnectionStatus status;
@property (retain) FMIPAddress *address;
- (BOOL)_checkIfClosed;
- (void)_closed;
@end


@implementation FMTCPConnection

static NSMutableArray *FMTCPConnectionAllConnections;


@synthesize address=_address;
@synthesize isIncoming=_isIncoming;
@synthesize status=_status;
@synthesize reader=_reader;
@synthesize writer=_writer;
@synthesize server=_server;
@synthesize openTimeout=_openTimeout;

- (Class)readerClass {
    return [FMTCPReader class];
}

- (Class)writerClass {
    return [FMTCPWriter class];
}


- (id)_initWithAddress:(FMIPAddress*)address
           inputStream:(NSInputStream*)input
          outputStream:(NSOutputStream*)output
{
    self = [super init];
    
    if (self != nil) {
        
        if (!input || !output) {
            debug(@"Failed to create %@: addr=%@, in=%@, out=%@", self.class, address, input, output);
            [self release];
            return nil;
        }
        
        _address = [address copy];
        _reader = [[[self readerClass] alloc] initWithConnection:self stream:input];
        _writer = [[[self writerClass] alloc] initWithConnection:self stream:output];
    }
    
    return self;
}



- (id)initToAddress:(FMIPAddress*)address {
    
    #pragma message "FIXME: review this- see if we can just use the CF stuff below."
    
    NSInputStream *input = nil;
    NSOutputStream *output = nil;
    
#if TARGET_OS_IPHONE
    // +getStreamsToHost: is missing for some stupid reason on iPhone. Grrrrrrrrrr.
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)address.hostname, address.port, (CFReadStreamRef*)&input, (CFWriteStreamRef*)&output);
    
    if (input) {
        [NSMakeCollectable(input) autorelease];
    }
    
    if (output) {
        [NSMakeCollectable(output) autorelease];
    }
#else
    [NSStream getStreamsToHost:[NSHost hostWithAddress:[address ipv4name]]
                          port:[address port]
                   inputStream:&input 
                  outputStream:&output];
#endif

    return [self _initWithAddress: address inputStream: input outputStream: output];
}

/*
- (id)initToNetService:(NSNetService*)service {
    
    FMIPAddress *address = nil;
    NSInputStream *input = nil;
    NSOutputStream *output = nil;
    
    if ([service getInputStream:&input outputStream:&output]) {
        
        NSArray *addresses = [service addresses];
        if ([addresses count] > 0 ) {
            address = [[[FMIPAddress alloc] initWithSockAddr:[[addresses objectAtIndex:0] bytes]] autorelease];
        }
    }
    
    return [self _initWithAddress:address inputStream:input outputStream:output];
}


- (id)initToBonjourService:(MYBonjourService*)service;
{
    NSNetService *netService = [[NSNetService alloc] initWithDomain: service.domain
                                                               type: service.type name: service.name];
    self = [self initToNetService: netService];
    [netService release];
    return self;
}
*/

- (id)initIncomingFromSocket:(CFSocketNativeHandle)socket listener:(FMTCPListener*)listener {
    
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, socket, &readStream, &writeStream);
    
	if (readStream) {
        [NSMakeCollectable(readStream) autorelease];
    }
    
    if (writeStream) {
        [NSMakeCollectable(writeStream) autorelease];
    } 
	
    self = [self _initWithAddress:[FMIPAddress addressOfSocket: socket] 
                      inputStream:(NSInputStream*)readStream
                     outputStream:(NSOutputStream*)writeStream];
    
    if (self) {
        _isIncoming = YES;
        _server = [listener retain];
        CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    }
    
    return self;
}    


- (void)dealloc {
    
    [_reader release];
    [_writer release];
    [_address release];
    [super dealloc];
}


- (NSString*)description {
    return [NSString stringWithFormat:@"%@[%@ %@]", self.class, (_isIncoming ? @"from" : @"to"), _address];
}

- (id<FMTCPConnectionDelegate>) delegate {
    return _delegate;
}

- (void)setDelegate:(id<FMTCPConnectionDelegate>)delegate {
    _delegate = delegate;
}

- (NSError*)error {
    return _error;
}

- (NSString*)actualSecurityLevel {
    return [_reader securityLevel];
}

- (NSArray*)peerSSLCerts {
    return [_reader peerSSLCerts] ? [_reader peerSSLCerts] : [_writer peerSSLCerts];
}

- (void)_setStreamProperty:(id)value forKey:(NSString*)key {
    [_reader setProperty:value forKey:(CFStringRef)key];
    [_writer setProperty:value forKey:(CFStringRef)key];
}


#pragma mark -
#pragma mark OPENING / CLOSING:


- (void)open {
    
    if (_status <= kFMTCPClosed && _reader) {
        _reader.SSLProperties = _sslProperties;
        _writer.SSLProperties = _sslProperties;
        [_reader open];
        [_writer open];
        
        if ([FMTCPConnectionAllConnections indexOfObjectIdenticalTo:self] == NSNotFound) {
            [FMTCPConnectionAllConnections addObject: self];
        }
        
        
        self.status = kFMTCPOpening;
        if( _openTimeout > 0 )
            [self performSelector: @selector(_openTimeoutExpired) withObject: nil afterDelay: _openTimeout];
    }
}

- (void)_stopOpenTimer
{
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_openTimeoutExpired) object: nil];
}

- (void)_openTimeoutExpired
{
    if( _status == kFMTCPOpening ) {
        debug(@"%@: timed out waiting to open",self);
        [self _stream: _reader gotError: [NSError errorWithDomain: NSPOSIXErrorDomain
                                                             code: ETIMEDOUT userInfo: nil]];
    }
}


- (void)disconnect
{
    if( _status > kFMTCPClosed ) {
        debug(@"%@ disconnecting",self);
        [_writer disconnect];
        [_reader disconnect];
        self.status = kFMTCPDisconnected;
    }
    [self _stopOpenTimer];
}


- (void)close
{
    [self closeWithTimeout: 60.0];
}

- (void)closeWithTimeout: (NSTimeInterval)timeout {
    
    [self _stopOpenTimer];
    
    if (_status == kFMTCPOpening) {
        debug(@"%@ canceling open",self);
        [self _closed];
    }
    else if (_status == kFMTCPOpen) {
        debug(@"%@ closing",self);
        [self setStatus:kFMTCPClosing];
        [self retain];
        [self _beginClose];
        
        if (![self _checkIfClosed]) {
            
            if (timeout <= 0.0) {
                [self disconnect];
            }
            else if( timeout != INFINITY ) {
                [self performSelector:@selector(_closeTimeoutExpired) withObject:nil afterDelay:timeout];
            }
        }
        
        [self release];
    }
}

- (void)_closeTimeoutExpired {
    
    if (_status == kFMTCPClosing) {
        [self disconnect];
    }
        
}

- (void)_stopCloseTimer {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_closeTimeoutExpired) object:nil];
}

- (void)_unclose {
    
    if (_status == kFMTCPClosing) {
        debug(@"%@: _unclose!",self);
        [_reader _unclose];
        [_writer _unclose];
        [self _stopCloseTimer];
        [self setStatus:kFMTCPOpen];
    }
}


/** Subclasses can override this to customize what happens when -close is called. */
- (void)_beginClose {
    
    [_reader close];
    [_writer close];
}


- (BOOL)_checkIfClosed {
    
    if (_status == kFMTCPClosing && _writer==nil && _reader==nil) {
        [self _closed];
        return YES;
    }
    else {
        return NO;
    }
}


// called by streams when they close (after -close is called)
- (void)_closed {
    
    [[self retain] autorelease];
    
    if (_status != kFMTCPClosed && _status != kFMTCPDisconnected) {
        
        FMTCPConnectionStatus prevStatus = _status;
        [self setStatus:(prevStatus == kFMTCPClosing ? kFMTCPClosed : kFMTCPDisconnected)];
        
        if (prevStatus == kFMTCPOpening) {
            [self tellDelegate:@selector(connection:failedToOpen:) withObject:[self error]];
        }
        else {
            [self tellDelegate:@selector(connectionDidClose:) withObject:nil];
        }
    }
    
    [self _stopCloseTimer];
    [self _stopOpenTimer];
    
    [FMTCPConnectionAllConnections removeObjectIdenticalTo: self];
}


+ (void)closeAllWithTimeout: (NSTimeInterval)timeout {
    
    NSArray *connections = [FMTCPConnectionAllConnections copy];
    for (FMTCPConnection *conn in connections) {
        [conn closeWithTimeout:timeout];
    }
    
    [connections release];
}

+ (void)waitTillAllClosed {
    
    while ([FMTCPConnectionAllConnections count]) {
        if (![[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]) {
            break;
        }
    }
}


#pragma mark -
#pragma mark STREAM CALLBACKS:


- (void)_streamOpened: (FMTCPStream*)stream {
    
    if (! _address) {
        [self setAddress:[stream peerAddress]];
    }
    
    if (_status == kFMTCPOpening && [_reader isOpen] && [_writer isOpen]) {
        //debug(@"%@ opened; address=%@",self,_address);
        [self _stopOpenTimer];
        [self setStatus:kFMTCPOpen];
        [self tellDelegate:@selector(connectionDidOpen:) withObject:nil];
    }
}


- (BOOL)_streamPeerCertAvailable: (FMTCPStream*)stream
{
    #pragma message "FIXME: review if we really need the try / catch.  They suck"
    BOOL allow = YES;
    if( ! _checkedPeerCert ) {
        @try{
            _checkedPeerCert = YES;
            if( stream.securityLevel != nil ) {
                NSArray *certs = stream.peerSSLCerts;
                if( ! certs && ! _isIncoming )
                    allow = NO; // Server MUST have a cert!
                else {
                    SecCertificateRef cert = certs.count ?(SecCertificateRef)[certs objectAtIndex:0] :NULL;
                    if ([FMTCPEndpoint respondsToSelector: @selector(describeCert:)]) {
                        //debug(@"%@: Peer cert = %@",self,[FMTCPEndpoint describeCert: cert]);
                    }
                        
                    if ([_delegate respondsToSelector:@selector(connection:authorizeSSLPeer:)]) {
                        allow = [_delegate connection:self authorizeSSLPeer:cert];
                    }
                        
                }
            }
        }
        @catch( NSException *x ) {
            //MYReportException(x,@"TCPConnection _streamPeerCertAvailable");
            _checkedPeerCert = NO;
            allow = NO;
        }
        if( ! allow )
            [self _stream: stream 
                 gotError: [NSError errorWithDomain: NSStreamSocketSSLErrorDomain
                                               code: errSSLClosedAbort
                                           userInfo: nil]];
    }
    return allow;
}


- (void)_stream: (FMTCPStream*)stream gotError: (NSError*)error
{
    debug(@"%@ got %@ on %@",self,error,stream.class);
    FMAssert(error);
    [[self retain] autorelease];
    
    if (error) {
        [_error release];
        _error = [error retain];
    }
    
    [_reader disconnect];
    [_writer disconnect];
    [self _closed];
}

- (void)_streamGotEOF: (FMTCPStream*)stream
{
    debug(@"%@ got EOF on %@",self,stream);
    [stream disconnect];
    if( _status == kFMTCPClosing ) {
        [self _streamCanClose: stream];
        [self _checkIfClosed];
    } else {
        [self _stream: stream 
             gotError: [NSError errorWithDomain: NSPOSIXErrorDomain code: ECONNRESET userInfo: nil]];
    }
}


// Called as soon as a stream is ready to close, after its -close method has been called.
- (void)_streamCanClose: (FMTCPStream*)stream
{
    if( ! _reader.isActive && !_writer.isActive ) {
        debug(@"Both streams are ready to close now!");
        [_reader disconnect];
        [_writer disconnect];
    }
}


// Called after I called -close on a stream and it finished closing:
- (void)_streamDisconnected: (FMTCPStream*)stream
{
    debug(@"%@: disconnected %@",self,stream);
    if( stream == _reader )
        FMTCPSetObj(&_reader,nil);
    else if( stream == _writer )
        FMTCPSetObj(&_writer,nil);
    else
        return;
    if( !_reader.isOpen && !_writer.isOpen )
        [self _closed];
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
