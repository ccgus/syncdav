//
//  FMTCPWriter.m
//
//  Originally Created by Jens Alfke on 5/10/08.
//  Hijacked by Gus Mueller in 2011
//  Copyright 2008 Jens Alfke. All rights reserved.
//  

#import "FMTCPWriter.h"
#import "FMTCP_Internal.h"

@implementation FMTCPWriter

- (void)dealloc {
    [_queue release];
    [_currentData release];
    [super dealloc];
}

- (FMTCPReader*)reader {
    return [_conn reader];
}

- (BOOL)isBusy {
    return _currentData || _queue.count > 0;
}

- (void)writeUTF8String:(NSString*)data {
    [self writeData:[data dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)writeUTF8StringLine:(NSString*)data {
    [self writeData:[[data stringByAppendingString:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    //[self writeData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)writeData:(NSData*)data {
    
    if (!_queue) {
        _queue = [[NSMutableArray alloc] init];
    }
        
    [_queue addObject: data];
    
    if ([_queue count] == 1 && [(NSOutputStream*)_stream hasSpaceAvailable]) {
        [self _canWrite];
    }
}


- (void)_canWrite {
    
    if (!_currentData) {
        
        if ([_queue count] == 0) {
            [self queueIsEmpty]; // this may call -writeData, which will call _canWrite again
            return;
        }
        
        _currentData = [[_queue objectAtIndex:0] retain];
        _currentDataPos = 0;
        
        [_queue removeObjectAtIndex: 0];
    }
    
    const uint8_t *src = [_currentData bytes];
    src += _currentDataPos;
    NSInteger len = _currentData.length - _currentDataPos;
    NSInteger written = [(NSOutputStream*)_stream write:src maxLength:len];
    
    if (written < 0) {
        [self _gotError];
    }
    else if( written < len ) {
        _currentDataPos += written;
    }
    else {
        //debug(@"%@ wrote %i bytes, released %p", self, (int)written, _currentData);
        FMTCPSetObj(&_currentData,nil);
    }
}


- (void)queueIsEmpty {

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
