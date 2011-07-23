//
//  SDQueItem.h
//  syncdav
//
//  Created by August Mueller on 5/28/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FMWebDAVRequest.h"

@interface SDQueueItem : NSObject {
    NSURL *_url;
    NSURL *_localDataPUTURL;
    SEL    _requestAction;
    void (^_finishBlock)(FMWebDAVRequest *);
    NSString *_encryptPhrase;
}

@property (retain) NSURL *url;
@property (retain) NSURL *localDataPUTURL;
@property (retain) NSString *encryptPhrase;

+ (id)queueItemWithURL:(NSURL*)u action:(SEL)a finishBlock:(void (^)(FMWebDAVRequest *))block;
+ (id)queueItemWithURL:(NSURL*)u putLocalDataURL:(NSURL*)putLocalDataURL finishBlock:(void (^)(FMWebDAVRequest *))block;

- (void)setRequestAction:(SEL)action;
- (void)setFinishBlock:(void (^)(FMWebDAVRequest *))block;

- (BOOL)makeRequestWithDelegate:(id)delegate error:(NSError**)outErr;

@end
