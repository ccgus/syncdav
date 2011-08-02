//
//  TCPStream.m
//  MYNetwork
//
//  Created by Jens Alfke on 5/10/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import "FMTCPStream.h"
#import "FMTCP_Internal.h"
#import "FMIPAddress.h"


#pragma message "FIXME: revisit the client-side ssl stuff for ios"
#if !TARGET_OS_IPHONE
// You can't do client-side SSL auth using CFStream without this constant,
// but it was accidentally not declared in a public header.
// Unfortunately you can't use this on iPhone without Apple rejecting your app
// for using "private API". :-(
extern const CFStringRef _kCFStreamPropertySSLClientSideAuthentication; // in CFNetwork
#endif

static NSError* fixStreamError( NSError *error );


@implementation FMTCPStream


- (id) initWithConnection: (FMTCPConnection*)conn stream: (NSStream*)stream
{
    self = [super init];
    if (self != nil) {
        _conn = [conn retain];
        _stream = [stream retain];
        _stream.delegate = self;
        [_stream scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
    }
    return self;
}


- (void)dealloc {
    
    if (_stream) {
        [self disconnect];
    }
    
    [super dealloc];
}


- (id) propertyForKey: (CFStringRef)cfStreamProperty
{
    return [_stream propertyForKey: (NSString*)cfStreamProperty];
}

- (void)setProperty: (id)value forKey: (CFStringRef)cfStreamProperty
{
    if( ! [_stream setProperty: value forKey: (NSString*)cfStreamProperty] ) {
        debug(@"Failed to set property %@ on %@",cfStreamProperty,self);
    }
        
}


- (FMIPAddress*) peerAddress
{
    const CFSocketNativeHandle *socketPtr = [[self propertyForKey: kCFStreamPropertySocketNativeHandle] bytes];
    return socketPtr ?[FMIPAddress addressOfSocket: *socketPtr] :nil;
}


#pragma mark -
#pragma mark SSL:


- (NSString*) securityLevel                 {return [_stream propertyForKey: NSStreamSocketSecurityLevelKey];}

- (NSDictionary*) SSLProperties             {return [self propertyForKey: kCFStreamPropertySSLSettings];}

- (void)setSSLProperties:(NSDictionary*)p {
    
    [self setProperty: p forKey: kCFStreamPropertySSLSettings];
    
#if !TARGET_OS_IPHONE
    id clientAuth = [p objectForKey:kTCPPropertySSLClientSideAuthentication];
    
    if (clientAuth) {
        [self setProperty:clientAuth forKey:_kCFStreamPropertySSLClientSideAuthentication];
    }
        
#endif
}

- (NSArray*)peerSSLCerts {
    FMAssert([self isOpen]);
    return [self propertyForKey: kCFStreamPropertySSLPeerCertificates];
}


#pragma mark -
#pragma mark OPENING/CLOSING:


- (void)open
{
    FMAssert(_stream);
    FMAssert([_stream streamStatus] == (NSStreamStatus)NSStreamStatusNotOpen);
    
    [_stream open];
}


- (void)disconnect {
    
    if (_stream) {
        debug(@"Disconnect %@",self);
        [_stream setDelegate:nil];
        [_stream close];
        FMTCPSetObj(&_stream,nil);
    }
    
    if (_conn) {
        [self retain];
        [_conn _streamDisconnected: self];
        FMTCPSetObj(&_conn,nil);
        [self release];
    }
}


- (BOOL)close
{
    if( ! _shouldClose ) {
        _shouldClose = YES;
        debug(@"Request to close %@",self);
    }
    if( self.isBusy ) {
        return NO;
    } else {
        [[self retain] autorelease];        // don't let myself be dealloced in the midst of this
        [_conn _streamCanClose: self];
        return YES;
    }
}

- (void)_unclose
{
    _shouldClose = NO;
}


- (BOOL)isOpen
{
    NSStreamStatus status = _stream.streamStatus;
    return status >= NSStreamStatusOpen && status < NSStreamStatusAtEnd;
}

- (BOOL)isBusy
{
    return NO;  // abstract
}

- (BOOL)isActive
{
    return !_shouldClose || self.isBusy;
}


- (void)_opened
{
    [_conn _streamOpened: self];
}

- (void)_canRead {
    
}

- (void)_canWrite
{
    // abstract
}

- (void)_gotEOF {
    [_conn _streamGotEOF: self];
}

- (BOOL)_gotError:(NSError*)error {
    [_conn _stream:self gotError:fixStreamError(error)];
    
    return NO;
}

- (BOOL)_gotError {
    NSError *error = [_stream streamError];
    
    debug(@"error: '%@'", error);
    
    if (!error) {
        error = [NSError errorWithDomain: NSPOSIXErrorDomain code: EIO userInfo: nil]; //fallback
    }
        
    return [self _gotError:error];
}


- (void)stream:(NSStream*)stream handleEvent:(NSStreamEvent)streamEvent  {
    [[self retain] autorelease];
    
    switch(streamEvent) {
            
        case NSStreamEventOpenCompleted:
            [self _opened];
            break;
            
        case NSStreamEventHasBytesAvailable:
            debug(@"Bytes!");
            if (![_conn _streamPeerCertAvailable:self]) {
                return;
            }
            debug(@"going to read!");
            [self _canRead];
            break;
            
        case NSStreamEventHasSpaceAvailable:
            if( ! [_conn _streamPeerCertAvailable: self] ) {
                return;
            }
            
            debug(@"%@ can write",self);
            [self _canWrite];
            break;
            
        case NSStreamEventErrorOccurred:
            debug(@"%@ got error",self);
            [self _gotError];
            break;
            
        case NSStreamEventEndEncountered:
            debug(@"%@ got EOF",self);
            [self _gotEOF];
            break;
            
        default:
            debug(@"%@: unknown NSStreamEvent %i", self, (int)streamEvent);
            break;
    }
    
    // If I was previously asked to close, try again in case I'm no longer busy
    if (_shouldClose) {
        [self close];
    }
        
}


@end




@implementation FMTCPReader

- (void)dealloc {
    [_canReadBlock release];
    [super dealloc];
}


- (FMTCPWriter*)writer {
    return [_conn writer];
}

- (NSInteger)read:(void*)dst maxLength:(NSUInteger)maxLength {
    
    NSInteger bytesRead = [(NSInputStream*)_stream read:dst maxLength: maxLength];
    if (bytesRead < 0) {
        [self _gotError];
    }
        
    return bytesRead;
}


- (void)_canRead {
    
    if (_canReadBlock) {
        _canReadBlock(self);
    }
    else {
        NSLog(@"Reader has data, but nothings being done with it!");
        NSLog(@"%@", [self stringFromReadData]);
    }
}

- (void)setCanReadBlock:(void (^)(FMTCPReader *))block {
    [_canReadBlock release];
    _canReadBlock = [block copy];
}

- (NSString*)stringFromReadData {
    
#define MAX_BYTES_READ 2048
    
    NSMutableData *data         = [NSMutableData dataWithLength:MAX_BYTES_READ];
    NSInteger localBytesRead    = [self read:[data mutableBytes] maxLength:MAX_BYTES_READ];
    
    return [[[NSString alloc] initWithBytes:[data bytes] length:localBytesRead encoding:NSUTF8StringEncoding] autorelease];
}


@end




static NSError* fixStreamError( NSError *error )
{
    // NSStream incorrectly returns SSL errors without the correct error domain:
    if ([[error domain] isEqualTo:@"NSUnknownErrorDomain"]) {
        int code = error.code;
        if( -9899 <= code && code <= -9800 ) {
            NSMutableDictionary *userInfo = error.userInfo.mutableCopy;
            if( ! [userInfo objectForKey: NSLocalizedFailureReasonErrorKey] ) {
                // look up error message:
                NSBundle *secBundle = [NSBundle bundleWithPath: @"/System/Library/Frameworks/Security.framework"];
                NSString *message = [secBundle localizedStringForKey: [NSString stringWithFormat:@"%i", code]
                                                               value: nil
                                                               table: @"SecErrorMessages"];
                if (message) {
                    if (!userInfo) {
                        userInfo = [NSMutableDictionary dictionary];
                    }
                    
                    [userInfo setObject: message forKey: NSLocalizedFailureReasonErrorKey];
                }
            }
            error = [NSError errorWithDomain: NSStreamSocketSSLErrorDomain
                                        code: code userInfo: userInfo];
        }
        else {
            debug(@"NSStream returned error with unknown domain: %@",error);
        }
    }
    
    return error;
}

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
