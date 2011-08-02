//
//  TCPWriter.h
//  MYNetwork
//
//  Created by Jens Alfke on 5/10/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import "FMTCPStream.h"


/** Output stream for a TCPConnection. Writes a queue of arbitrary data blobs to the socket. */
@interface FMTCPWriter : FMTCPStream 
{
    NSMutableArray *_queue;
    NSData *_currentData;
    SInt32 _currentDataPos;
}

/** The connection's TCPReader. */
@property (readonly) FMTCPReader *reader;

/** Schedules data to be written to the socket.
    Always returns immediately; the bytes won't actually be sent until there's room. */
- (void)writeData: (NSData*)data;

- (void)writeUTF8String:(NSString*)data;
- (void)writeUTF8StringLine:(NSString*)data;

//protected:

/** Will be called when the internal queue of data to be written is empty.
    Subclasses should override this and call -writeData: to refill the queue,
    if possible. */
- (void)queueIsEmpty;

@end
