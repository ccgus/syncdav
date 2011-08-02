//
//  SDManager.h
//
//  Created by August Mueller on 5/24/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

/*
 
 Here's the general algorithm for the sync steps:
 
 1) Check for local deletes by peeking the the .catalog for what is no longer here.
    Tell the server to delete those files.
 
 2) Recursively look through the webdav folders, looking for new files and changed etags.
    Does it have a different etag, or is it new?  Add to the download queue.

 3) Once the files have all downloaded (the queue is empty), then delete any local files that are no longer on the server.
 
 4) Finally push up any new and changed files (based on comparing its md5).

*/




#import <Cocoa/Cocoa.h>
#import "FMDatabase.h"

@protocol SDReflector;

enum {
    SDOnConflictDiscardLocal = 0,
    SDOnConflictDiscardServer,
    SDOnConflictRenameLocal,
    SDOnConflictAskDelegate
};
typedef NSUInteger SDConflictOptions;


@interface SDManager : NSObject {
    
    NSURL               *_localURL;
    NSURL               *_remoteURL;
    
    NSString            *_username;
    NSString            *_password;
    NSString            *_encryptPhrase;
    
    FSEventStreamRef    _eventsStreamRef;
    
    BOOL                _stopping;
    BOOL                _suppressReloads;
    BOOL                _listing;
    BOOL                _authenticated;
    
    NSMutableArray      *_pathsToScanAfterSupressionLifts;
    
    NSDate              *_lastScanDate;
    
    NSString            *_currentSyncUUID;
    
    NSUInteger           _conflictBehavior;
    
    void (^_finishBlock)(NSError *);
    
    NSMutableArray      *_waitingQueue;
    NSMutableArray      *_activeQueue;
    
    id<SDReflector>     _reflector;
}


@property (retain) NSURL *localURL;
@property (retain) NSURL *remoteURL;
@property (retain) NSString *username;
@property (retain) NSString *password;
@property (assign) BOOL suppressReloads;
@property (retain) NSDate *lastScanDate;
@property (retain) NSMutableArray *downloadQue;
@property (assign) BOOL authenticated;
@property (assign) NSUInteger conflictBehavior;
@property (retain) NSString *encryptPhrase;
@property (retain) id<SDReflector> reflector;


+ (id)managerWithLocalURL:(NSURL*)localU remoteURL:(NSURL*)remoteU username:(NSString *)uname password:(NSString*)pass;

- (void)start;
- (void)stop;
- (void)sync;
- (void)syncWithFinishBlock:(void (^)(NSError *))block;
- (void)authenticateWithFinishBlock:(void (^)(NSError *))block;
- (void)reflector:(id<SDReflector>)relector sawURLUpdated:(NSURL*)updatedURL;

@end


@protocol SDReflector <NSObject>

- (void)fileWasPUT:(NSString*)filePath;

@end
