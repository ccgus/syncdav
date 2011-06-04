//
//  SDQueItem.m
//  syncdav
//
//  Created by August Mueller on 5/28/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import "SDQueueItem.h"


@implementation SDQueueItem
@synthesize url=_url;
@synthesize localDataPUTURL=_localDataPUTURL;


+ (id)queueItemWithURL:(NSURL*)u action:(SEL)a finishBlock:(void (^)(FMWebDAVRequest *))block {
    
    SDQueueItem *item = [[[self alloc] init] autorelease];
    
    [item setUrl:u];
    [item setRequestAction:a];
    [item setFinishBlock:block];
    
    return item;
}

+ (id)queueItemWithURL:(NSURL*)u putLocalDataURL:(NSURL*)putLocalDataURL finishBlock:(void (^)(FMWebDAVRequest *))block {
    
    SDQueueItem *item = [[[self alloc] init] autorelease];
    
    [item setUrl:u];
    [item setLocalDataPUTURL:putLocalDataURL];
    [item setRequestAction:@selector(putData:)];
    [item setFinishBlock:block];
    
    return item;
}

- (void)dealloc {
    [_url release];
    [_finishBlock release];
    [_localDataPUTURL release];
    
    [super dealloc];
}


- (void)setFinishBlock:(void (^)(FMWebDAVRequest *))block {
    [_finishBlock autorelease];
    _finishBlock = [block copy];
}

- (void)setRequestAction:(SEL)action {
    _requestAction = action;
}

- (BOOL)makeRequestWithDelegate:(id)delegate error:(NSError**)outErr {
    
    //debug(@"makingRequest: '%@'", _url);
    
    if (_localDataPUTURL) {
        NSError *err = 0x00;
        NSData *data = [NSData dataWithContentsOfURL:_localDataPUTURL options:NSDataReadingMapped error:&err];
        
        if (!data) {
            
            if (outErr) {
                *outErr = err;
            }
            
            return NO;
        }
        else {
            [[[FMWebDAVRequest requestToURL:_url delegate:delegate] putData:data] withFinishBlock:_finishBlock];
        }
    }
    else {
        [[[FMWebDAVRequest requestToURL:_url delegate:delegate] performSelector:_requestAction] withFinishBlock:_finishBlock];
    }
    
    return YES;
}

@end
