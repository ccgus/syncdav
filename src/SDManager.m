//
//  SDManager.m
//  flysync
//
//  Created by August Mueller on 5/24/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import "SDManager.h"
#import "SDUtils.h"
#import "SDQueueItem.h"
#import "FMWebDAVRequest.h"
#import "FMNSStringAdditions.h"
#import "FMDatabaseAdditions.h"


@interface SDManager ()
- (void)grabChangesForDirectories:(NSArray *)paths;
- (void)cleanupServerDeletesIfDoneDownloading;
- (void)putChangedFilesFromLocalURL:(NSURL*)lURL;
@end

static void VPDocScannerFSEventsCallback(FSEventStreamRef streamRef, SDManager *manager, int numEvents, NSArray *paths, const FSEventStreamEventFlags *eventFlags, const uint64_t *eventIDs)
{
    [manager grabChangesForDirectories:paths];
}


@implementation SDManager
@synthesize localURL=_localURL;
@synthesize remoteURL=_remoteURL;
@synthesize username=_username;
@synthesize password=_password;
@synthesize lastScanDate=_lastScanDate;
@synthesize downloadQue=_downloadQue;
@synthesize authenticated=_authenticated;
@synthesize conflictBehavior=_conflictBehavior;
@synthesize encryptPhrase=_encryptPhrase;
@synthesize reflector = _reflector;


+ (id)managerWithLocalURL:(NSURL*)localU remoteURL:(NSURL*)remoteU username:(NSString *)uname password:(NSString*)pass {
    
    SDManager *me = [[[self alloc] init] autorelease];
    
    if (![[remoteU absoluteString] hasSuffix:@"/"]) {
        remoteU = [NSURL URLWithString:[[remoteU absoluteString] stringByAppendingString:@"/"]];
    }
    
    [me setLocalURL:localU];
    [me setRemoteURL:remoteU];
    [me setUsername:uname];
    [me setPassword:pass];
    
    return me;
}

- (id)init {
	self = [super init];
	if (self != nil) {
		_waitingQueue = [[NSMutableArray array] retain];
		_activeQueue  = [[NSMutableArray array] retain];
		
        //_downloadQueBlockHolder = [[NSMutableDictionary dictionary] retain];
	}
	return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    FMRelease(_localURL);
    FMRelease(_remoteURL);
    FMRelease(_username);
    FMRelease(_password);
    FMRelease(_currentSyncUUID);
    FMRelease(_waitingQueue);
    FMRelease(_activeQueue);
    FMRelease(_encryptPhrase);
    FMRelease(_reflector);
    
    [super dealloc];
}

- (void)threadWillExitNotification:(NSNotification*)note {
    NSString *threadIdentifier = [NSString stringWithFormat:@"com.flyingmeat.SyncDAV.%@", self];
    
    FMDatabase *db = [[[NSThread currentThread] threadDictionary] objectForKey:threadIdentifier];
    
    [db close];
}

- (BOOL)queueIsEmpty {
    return ([_waitingQueue count] == 0 && [_activeQueue count] == 0);
}

- (void)nudgeQueue {
    
    SDAssert([NSThread isMainThread]);
    
    // FIXME: should we do this on the main thread?
    if ([_waitingQueue count] && [_activeQueue count] < 4) {
        
        SDQueueItem *item = [_waitingQueue objectAtIndex:0];
        
        [_activeQueue addObject:item];
        [_waitingQueue removeObjectAtIndex:0];
        
        NSError *err = 0x00;
        
        if (![item makeRequestWithDelegate:self error:&err]) {
            NSLog(@"Whoa- got an error trying to do something!");
            NSLog(@"%@", err);
            [_activeQueue removeObject:item];
        }
        
        //debug(@"%ld active requests. %ld left (%@)", [_activeQueue count], [_waitingQueue count], [item url]);
    }
    
}

- (void)addPUTURLToRequestQueue:(NSURL*)url localDataURL:(NSURL*)lurl withFinishBlock:(void (^)(FMWebDAVRequest *))block {
    
    SDAssert([NSThread isMainThread]);
    
    SDQueueItem *item = [SDQueueItem queueItemWithURL:url putLocalDataURL:lurl finishBlock:block];
    [item setEncryptPhrase:_encryptPhrase];
    
    [_waitingQueue addObject:item];
    
    [self nudgeQueue];
}

- (void)addURLToRequestQueue:(NSURL*)url requestAction:(SEL)reqAction withFinishBlock:(void (^)(FMWebDAVRequest *))block {
    
    SDAssert([NSThread isMainThread]);
    
    SDQueueItem *item = [SDQueueItem queueItemWithURL:url action:reqAction finishBlock:block];
    
    [_waitingQueue addObject:item];
    
    [self nudgeQueue];
}

- (void)removeURLFromActiveQueue:(NSURL*)url {
    
    SDAssert([NSThread isMainThread]);
    
    NSUInteger idx = [_activeQueue indexOfObjectPassingTest:^(SDQueueItem *obj, NSUInteger idx, BOOL *stop) {
        return [[obj url] isEqualTo:url];
    }];
    
    if (idx != NSNotFound) {
        [_activeQueue removeObjectAtIndex:idx];
    }
    
    [self nudgeQueue];
}

- (FMDatabase*)catalog {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(threadWillExitNotification:) name:NSThreadWillExitNotification object:[NSThread currentThread]];
    
    NSString *threadIdentifier = [NSString stringWithFormat:@"com.flyingmeat.SyncDAV.%@", self];
    FMDatabase *db             = [[[NSThread currentThread] threadDictionary] objectForKey:threadIdentifier];
    
    if (!db) {
        NSString *databasePath = [[_localURL path] stringByAppendingPathComponent:@".catalog"];
        db = [FMDatabase databaseWithPath:databasePath];
        
        if (![db open]) {
            NSBeep();
            NSLog(@"Can't open the catalog at %@", databasePath);
            return 0x00;
        }
        
        [[[NSThread currentThread] threadDictionary] setObject:db forKey:threadIdentifier];
        
        @synchronized(self) {
            
            FMResultSet *rs = [db executeQuery:@"select name from SQLITE_MASTER where name = 'sync_catalog'"];
            if (![rs next]) {
                
                debug(@"making database");
                
                [db beginTransaction];
                
                [db executeUpdate:@"create table sync_catalog (path text primary key, file_type text, etag text, md5_when_put text, download_time float, created_time float, modified_time float, server_modified_date_string text, weak_etag int, sync_check_uuid text, update_in_progress int)"];
                
                if ([db lastErrorCode] != SQLITE_OK) {
                    NSBeep();
                    NSLog(@"Can't create the catalog database!");
                    return 0x00;
                }
                
                [db commit];
            }
            
            [rs close];
        }
        
    }
    
    return db;
}

- (BOOL)shouldUploadFileAtURL:(NSURL*)aLocalURL {
    
    NSString *lastPathComp = [aLocalURL lastPathComponent];
    
    if ([lastPathComp isEqualToString:@".DS_Store"] || [lastPathComp isEqualToString:@".catalog"] || [lastPathComp isEqualToString:@"Icon\r"]) {
        return NO;
    }
    
    // FIXME: ask the delegate if it should be uploaded
    
    return YES;
}

- (BOOL)setupLocalListener {
    
    
    SDAssert(_localURL);
    
    CFTimeInterval latency = 2; // seconds 
    
    FSEventStreamContext context = {0, self, 0x00, 0x00, 0x00};
    
    NSArray *paths = [NSArray arrayWithObject:[_localURL path]];
    
    _eventsStreamRef = FSEventStreamCreate(kCFAllocatorDefault,
                                           (FSEventStreamCallback)&VPDocScannerFSEventsCallback,
                                           &context,
                                           (CFArrayRef)paths,
                                           kFSEventStreamEventIdSinceNow,
                                           latency,
                                           kFSEventStreamCreateFlagUseCFTypes);
    
    SDAssert(_eventsStreamRef);
    
    if (!_eventsStreamRef) {
        NSLog(@"Could not setup scanner for %@", _localURL);
        return NO;
    }
    
    FSEventStreamScheduleWithRunLoop(_eventsStreamRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    
    if (!FSEventStreamStart(_eventsStreamRef)) {
        NSLog(@"Failed to start the FSEventStream!");
        FSEventStreamRelease(_eventsStreamRef);
        return NO;
    }
    
    return YES;
}

- (void)scanDirectory:(NSString*)path {
    
    debug(@"something updated in '%@'", path);
    
    
}

- (void)grabChangesForDirectories:(NSArray *)paths {
    
    if (_suppressReloads) {
        
        for (NSString *path in paths) {
            
            NSUInteger alreadyAround = [_pathsToScanAfterSupressionLifts indexOfObjectPassingTest:^(NSString *existingPath, NSUInteger idx, BOOL *stop) {
                return ([existingPath isEqualToString:path]);
            }];
            
            debug(@"alreadyAround: %ld", alreadyAround);
            
            if (alreadyAround != NSNotFound) {
                debug(@"adding %@", path);
                [_pathsToScanAfterSupressionLifts addObject:path];
            }
        }
        
        return;
    }
    
    SDAssert([NSThread isMainThread]);
    
    [self setSuppressReloads:YES];
    
    NSDate *startScanTime = [NSDate date];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        for (NSString *path in paths) {
            [self scanDirectory:path];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLastScanDate:startScanTime];
            [self setSuppressReloads:NO];
        });
    });
}


- (BOOL)suppressReloads {
    return _suppressReloads;
}

- (void)setSuppressReloads:(BOOL)value {
    
    SDAssert([NSThread isMainThread]);
    
    _suppressReloads = value;
    
    if (!_suppressReloads && [_pathsToScanAfterSupressionLifts count]) {
        [self grabChangesForDirectories:_pathsToScanAfterSupressionLifts];
        [_pathsToScanAfterSupressionLifts removeAllObjects];
    }
}


- (void)request:(FMWebDAVRequest*)request didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
    debug(@"[challenge previousFailureCount]: %ld", [challenge previousFailureCount]);
    
    if ([challenge previousFailureCount] == 0) {
        
        NSURLCredential *cred = [NSURLCredential credentialWithUser:_username
                                                           password:_password
                                                        persistence:NSURLCredentialPersistenceForSession];
        
        [[challenge sender] useCredential:cred forAuthenticationChallenge:challenge];
        
        return;
    }
}

- (NSURL*)localPathURLFromServerURI:(NSString*)uri {
    
    NSString *baseURI = [_remoteURL path];
    NSString *choppedURI = [uri substringFromIndex:[baseURI length]];
    
    NSString *s = [[_localURL path] stringByAppendingString:choppedURI];
    
    return [NSURL fileURLWithPath:s];
}

- (NSString*)relativePathForLocalURL:(NSURL*)lurl {
    
    NSUInteger llen = [[_localURL path] length];
    
    NSString *relPath = [[lurl path] substringFromIndex:llen];
    
    return relPath;
}

- (NSURL*)localURLFromRelativePath:(NSString*)relPath {
    
    NSString *lPath = [_localURL path];
    lPath = [lPath stringByAppendingString:relPath];
    return [NSURL fileURLWithPath:lPath];
}

- (NSURL*)serverURLFromRelativePath:(NSString*)relPath {
    
    if ([relPath hasPrefix:@"/"] && [[_remoteURL absoluteString] hasSuffix:@"/"]) {
        relPath = [relPath substringFromIndex:1];
    }
    
    NSString *s = [[_remoteURL absoluteString] stringByAppendingString:[relPath fmStringByAddingPercentEscapesWithExceptions:nil]];
    
    return [NSURL URLWithString:s];
}

- (BOOL)localURLHasChangedSinceLastSync:(NSURL*)lurl {
    
    NSString *serverMD5  = 0x00;
    NSString *path = [self relativePathForLocalURL:lurl];
    FMResultSet *rs = [[self catalog] executeQuery:@"select etag, md5_when_put from sync_catalog where path = ?", path];
    while ([rs next]) {
        serverMD5    = [rs stringForColumnIndex:1];
    }
    
    SDAssert(serverMD5);
    
    NSError *err;
    NSData *lData = [[NSData alloc] initWithContentsOfURL:lurl options:NSDataReadingMapped error:&err];
    if (!lData) {
        NSLog(@"Could not load the data for %@", lurl);
        NSLog(@"%@", err);
        SDAssert(NO);
        return NO;
    }
    
    NSString *localMD5 = [SDUtils md5ForData:lData];
    [lData release];
    
    return ![localMD5 isEqualToString:serverMD5];
}

- (void)getServerURLIfNeeded:(NSURL*)itemServerURL withPathInfo:(NSDictionary*)pathInfo{
    
    debug(@"itemServerURL: '%@'", itemServerURL);
    
    NSString *etag      = [SDUtils makeStrongEtag:[pathInfo objectForKey:FMWebDAVETagKey]];
    NSString *uri       = [[pathInfo objectForKey:FMWebDAVURIKey] fmStringByReplacingPercentEscapes];
    NSURL *lurl         = [self localPathURLFromServerURI:uri];
    NSString *relPath   = [self relativePathForLocalURL:lurl];
    
    BOOL isDir          = NO;
    BOOL isServerDir    = [[pathInfo objectForKey:FMWebDAVContentTypeKey] hasSuffix:@"directory"] || [uri hasSuffix:@"/"]; // MobileMe doesn't remort the content type for dirs.
    BOOL shouldDownload = ![[NSFileManager defaultManager] fileExistsAtPath:[lurl path] isDirectory:&isDir];
    BOOL alreadyExists  = NO;
    
    debug(@"1 shouldDownload: '%d'", shouldDownload);
    
    if (!shouldDownload) {
        // Check the etag to see if it's changed at all.
        // Don't use stringForQuery:, because MobileMe dirs don't have etags and it'll return a nil value otherwise.
        
        debug(@"checking…");
        
        // /enc.txt|file|"50519-10-4a8b1a42e0600"|b10a8db164e0754105b7a99be72e3fe5||1311380823.0|1311380823.67838|Sat, 23 Jul 2011 00:27:04 GMT|1|8e6ac38a-ef9e-4d80-b4e0-aa31191c5006|
        debug(@"relPath: '%@'", relPath);
        FMResultSet *rs = [[self catalog] executeQuery:@"select etag from sync_catalog where path = ?", relPath];
        while ([rs next]) {
            NSString *localEtag = [rs stringForColumnIndex:0];
            shouldDownload = ![localEtag isEqualToString:etag];
            alreadyExists  = YES;
            
            debug(@"etag: '%@'", etag);
            debug(@"localEtag: '%@'", localEtag);
            
            if (isDir && alreadyExists) {
                shouldDownload = NO;
            }
            
            if (shouldDownload) {
                debug(@"Different etags- scheduling %@ for download s: %@ vs l: %@", relPath, etag, localEtag);
            }
        }
        
        debug(@"done checking");
    }
    
    
    debug(@"2 shouldDownload: '%d'", shouldDownload);
    
    if (shouldDownload) {
        
        if (isServerDir) {
            NSError *err;
            
            if (![[NSFileManager defaultManager] createDirectoryAtPath:[lurl path] withIntermediateDirectories:YES attributes:nil error:&err]) {
                NSLog(@"Error: %@", err);
                NSLog(@"Could not create the directory at: %@", lurl);
                SDAssert(false);
            }
        }
        else {
            
            BOOL locallyModified = alreadyExists && [self localURLHasChangedSinceLastSync:lurl];
            
            // this feels skanky.
            if (locallyModified && _conflictBehavior == SDOnConflictDiscardServer) {
                //debug(@"WHOA HOLY CARP CONFLICT");
            }
            else {
                
                NSString *renameFileTo = 0x00;
                
                if (locallyModified && _conflictBehavior == SDOnConflictRenameLocal) {
                    
                    NSCalendarDate *d      = [NSCalendarDate calendarDate];
                    NSString *conflictTime = [NSString stringWithFormat:@"%d-%d-%d", [d yearOfCommonEra], [d monthOfYear], [d dayOfMonth]];
                    
                    NSString *oldName   = [lurl lastPathComponent];
                    NSString *extension = [oldName pathExtension];
                    oldName             = [oldName stringByDeletingPathExtension];
                    
                    renameFileTo        = [NSString stringWithFormat:@"%@ (%@'s conflicted copy %@).%@", oldName, [SDUtils computerName], conflictTime, extension];
                    
                    int conflictIdx     = 0;
                    
                    NSFileManager *fm   = [[[NSFileManager alloc] init] autorelease];
                    NSString *fold      = [[lurl path] stringByDeletingLastPathComponent];
                    
                    while ([fm fileExistsAtPath:[fold stringByAppendingPathComponent:renameFileTo]] && (conflictIdx < 1000)) {
                        conflictIdx++;
                        renameFileTo = [NSString stringWithFormat:@"%@ (%@'s conflicted copy %@ (%d)).%@", oldName, [SDUtils computerName], conflictTime, conflictIdx, extension];
                    }
                    
                    SDAssert((conflictIdx < 1000));
                    
                    NSError *err;
                    if (![fm moveItemAtURL:lurl toURL:[NSURL fileURLWithPath:[fold stringByAppendingPathComponent:renameFileTo]] error:&err]) {
                        NSLog(@"Could not rename %@ to %@", lurl, [NSURL fileURLWithPath:[fold stringByAppendingPathComponent:renameFileTo]]);
                        NSLog(@"%@", err);
                        SDAssert(false);
                    }
                    
                    // dropbox does this:
                    // filename (compname's conflicted copy 2011-06-01).extension
                    // filename (compname's conflicted copy 2011-06-01 (1)).extension
                }
                
                [self addURLToRequestQueue:itemServerURL requestAction:@selector(get) withFinishBlock:^(FMWebDAVRequest *getRequest) {
                    
                    NSData *writeData = [getRequest responseData];
                    
                    if (_encryptPhrase) {
                        writeData = [writeData AESDecryptWithKey:_encryptPhrase];
                        if (!writeData) {
                            NSLog(@"Whooa- I think the password given to decrypt the data is wrong.");
                            #pragma message "FIXME: Fixme- make a delegate message to say HEY BAD PASSWORD"
                        }
                    }
                    
                    NSError *err = 0x00;
                    if (![writeData writeToURL:lurl options:NSDataWritingAtomic error:&err]) {
                        debug(@"err: %p", err);
                        NSLog(@"Error: %@", err);
                        NSLog(@"Could not write to %@", lurl);
                        
                        #pragma message "FIXME: update the database here on an error"
                        
                        SDAssert(false);
                    }
                    else {
                        
                        NSString *md5        = [SDUtils md5ForData:writeData];
                        
                        NSError *err;
                        NSDictionary *atts   = [[NSFileManager defaultManager] attributesOfItemAtPath:[lurl path] error:&err];
                        NSDate *localModDate = [atts fileModificationDate];
                        NSString *newEtag    = [SDUtils makeStrongEtag:[SDUtils stringValueFromHeaders:[getRequest allHeaderFields] forKey:@"etag"]];
                        
                        SDAssert(newEtag);
                        SDAssert(localModDate);
                        
                        BOOL updated = [[self catalog] executeUpdate:@"update sync_catalog set md5_when_put = ?, download_time = ?, etag = ? where path = ?", md5, localModDate, newEtag, relPath];
                        
                        SDAssert(updated);
                        
                        if ([[self catalog] hadError]) {
                            debug(@"lastErrorMessage: '%@'", [[self catalog] lastErrorMessage]);
                        }
                        
                        NSString *s = [[self catalog] stringForQuery:@"select md5_when_put from sync_catalog where path = ?", relPath];
                        
                        SDAssert([s isEqualToString:md5]);
                    }
                    
                    [self removeURLFromActiveQueue:itemServerURL];
                    
                    [self cleanupServerDeletesIfDoneDownloading];
                }];
            }
        }
    }
    
    NSDate *creDate   = [pathInfo objectForKey:FMWebDAVCreationDateKey];
    NSDate *modDate   = [pathInfo objectForKey:FMWebDAVModificationDateKey];
    
    modDate = (!modDate) ? [NSDate date] : modDate;
    
    if (!creDate && isServerDir) {
        // We're on MobileMe, aren't we?
        creDate = modDate;
    }
    
    SDAssert(creDate);
    
    if (!alreadyExists) {
        [[self catalog] executeUpdate:@"insert into sync_catalog (path, file_type, etag, created_time, modified_time, sync_check_uuid) values (?, ?, ?, ?, ?, ?)", relPath, isServerDir ? @"fold" : @"file", etag, creDate, modDate, _currentSyncUUID];
        
        SDAssert(![[self catalog] hadError]);
        
    }
    else {
        [[self catalog] executeUpdate:@"update sync_catalog set sync_check_uuid = ? where path = ?", _currentSyncUUID, relPath];
    }
}

- (void)finishSyncing {
    debug(@"All done!");
    FMRelease(_currentSyncUUID);
    
    if (_finishBlock) {
        _finishBlock(nil);
    }
}

- (void)putChangedFilesFromLocalURL:(NSURL*)lURL {
    
    if (!lURL) {
        lURL = _localURL;
    }
    
    //debug(@"Entering putChangedFilesFromLocalURL %@", lURL);
    
    NSError *err;
    NSMutableArray *pushUpInfo = [NSMutableArray array];
    NSFileManager *fm          = [[[NSFileManager alloc] init] autorelease];
    NSArray *ar                = [fm subpathsOfDirectoryAtPath:[lURL path] error:&err];
    
    if (!ar) {
        NSLog(@"Error getting subpaths!");
        NSLog(@"%@", err);
    }
    
    for (NSString *path in ar) {
        
        BOOL found           = NO;
        NSString *serverMD5  = 0x00;
        NSString *lastEtag   = 0x00;
        
        FMResultSet *rs = [[self catalog] executeQuery:@"select etag, md5_when_put from sync_catalog where path = ?", [NSString stringWithFormat:@"/%@", path]];
        while ([rs next]) {
            found        = YES;
            lastEtag     = [rs stringForColumnIndex:0];
            serverMD5    = [rs stringForColumnIndex:1];
        }
        
        NSString *fullPath = [[lURL path] stringByAppendingPathComponent:path];
        NSURL *fullURL     = [NSURL fileURLWithPath:fullPath];
        
        if (!found) {
            
            BOOL isDir;
            [fm fileExistsAtPath:fullPath isDirectory:&isDir];
            
            NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:fullURL, @"url", [NSNumber numberWithBool:YES], @"exists", [NSNumber numberWithBool:isDir], @"isDir", nil];
            
            [pushUpInfo addObject:d];
        }
        else if (!serverMD5) {
            // it's probably a directory?
            
            BOOL isDir;
            if ([fm fileExistsAtPath:fullPath isDirectory:&isDir] && !isDir) {
                // GOTTA PUSH PUSH!
                NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:fullURL, @"url", [NSNumber numberWithBool:YES], @"exists", lastEtag, @"lastEtag", nil];
                [pushUpInfo addObject:d];
            }
        }
        else {
            NSError *err;
            NSDictionary *atts = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:&err];
            
            if ([[atts fileType] isEqualToString:NSFileTypeDirectory]) {
                SDAssert(NO); // what?  why are we here?
                //debug(@"directory to make!  %@", fullURL);
                continue;
            }
            
            if (!atts) {
                NSLog(@"Could not load the file attributes for %@", fullPath);
                NSLog(@"%@", err);
                continue;
            }
            
            NSData *lData = [NSData dataWithContentsOfURL:fullURL options:NSDataReadingMapped error:&err];
            if (!lData) {
                NSLog(@"Could not load the data for %@", fullPath);
                NSLog(@"%@", err);
                continue;
            }
            
            NSString *localMD5 = [SDUtils md5ForData:lData];
            
            if (![localMD5 isEqualToString:serverMD5]) {
                
                NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:fullURL, @"url", [NSNumber numberWithBool:YES], @"exists", lastEtag, @"lastEtag", nil];
                
                [pushUpInfo addObject:d];
            }
        }
    }
    
    for (NSDictionary *dict in pushUpInfo) {
        
        
        NSURL *localPushURL = [dict objectForKey:@"url"];
        BOOL isDir          = [[dict objectForKey:@"isDir"] boolValue];
        //NSString *lastEtag  = [dict objectForKey:@"lastEtag"];
        
        if (![self shouldUploadFileAtURL:localPushURL]) {
            continue;
        }
        
        NSString *relativePath = [self relativePathForLocalURL:localPushURL];
        NSURL *pushToURL       = [self serverURLFromRelativePath:relativePath];
        
        
        if (isDir) {
            #pragma message "FIXME: queue this?"
            FMWebDAVRequest *req = [[[FMWebDAVRequest requestToURL:pushToURL delegate:self] synchronous] createDirectory];
            SDAssert(![req error]);
            continue;
        }
        
        debug(@"pushing %@", [relativePath lastPathComponent]);
        
        NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
        
        NSError *err;
        NSData *lData = [NSData dataWithContentsOfURL:localPushURL options:NSDataReadingMapped error:&err];
        
        NSString *localMD5 = [SDUtils md5ForData:lData];
        
        if (!lData) {
            NSLog(@"Could not get data for %@", localPushURL);
            NSLog(@"%@", err);
            continue;
        }
        
        [self addPUTURLToRequestQueue:pushToURL localDataURL:localPushURL withFinishBlock:^(FMWebDAVRequest *pushRequest) {
            
            NSString *pushDate = [SDUtils stringValueFromHeaders:[pushRequest allHeaderFields] forKey:@"date"];
            NSString *pushEtag = [SDUtils stringValueFromHeaders:[pushRequest allHeaderFields] forKey:@"etag"];
            
            //BOOL pushWeakEtag  = [pushEtag hasPrefix:@"W/"];
            //SDAssert(![pushEtag hasPrefix:@"w/"]); // oh god, I just know this is going to happen some day, with some server.
            
            if (pushEtag) {
                // mobileme does this.  Apache doesn't. so we don't need to do the request below.  but we will anyway.
                debug(@"FIXME: WE GOT AN ETAG DON'T NEED TO HEAD HEAD YO");
            }
            
            if ([pushRequest error]) {
                debug(@"put error: %@", [pushRequest error]);
            }
            
            [self removeURLFromActiveQueue:pushToURL];
            
            [self addURLToRequestQueue:pushToURL requestAction:@selector(head) withFinishBlock:^(FMWebDAVRequest *headRequest) {
                
                NSString *headDate = [SDUtils stringValueFromHeaders:[headRequest allHeaderFields] forKey:@"Last-Modified"];
                NSString *headEtag = [SDUtils makeStrongEtag:[SDUtils stringValueFromHeaders:[headRequest allHeaderFields] forKey:@"etag"]];
                
                BOOL headWeakEtag  = [[SDUtils stringValueFromHeaders:[headRequest allHeaderFields] forKey:@"etag"] hasPrefix:@"W/"];
                
                if (headWeakEtag) {
                    debug(@"Weak etag for %@.  It won't be in a bit, will it?  We're going to download it again, aren't we?", [pushToURL lastPathComponent]);
                }
                
                if ([headDate isEqualToString:pushDate]) {
                    // ok, what?
                    debug(@"Same mod date.");
                }
                
                if (![headRequest error]) {
                    
                    // debug(@"got etag for %@ %@ (w?: %@) was %@", relativePath, headEtag, [SDUtils stringValueFromHeaders:[headRequest allHeaderFields] forKey:@"etag"], lastEtag);
                    
                    SDAssert(headEtag);
                    
                    BOOL worked = [[self catalog] executeUpdate:@"replace into sync_catalog (path, etag, md5_when_put, sync_check_uuid, server_modified_date_string, weak_etag) values (?, ?, ?, ?, ?, ?)", relativePath, headEtag, localMD5, headDate, [NSNumber numberWithBool:headWeakEtag], _currentSyncUUID];
                    
                    SDAssert(worked);
                    /*
                    if (exists) {
                        BOOL res = [[self catalog] executeUpdate:@"update sync_catalog set etag = ?, md5_when_put = ?, sync_check_uuid = ?, server_modified_date_string = ?, weak_etag = ? where path = ?", headEtag, localMD5, _currentSyncUUID, headDate, [NSNumber numberWithBool:headWeakEtag], relativePath];
                        
                        SDAssert(res);
                        SDAssert(![[self catalog] hadError]);
                    }
                    else {
                        BOOL res = [[self catalog] executeUpdate:@"insert into sync_catalog (path, etag, md5_when_put, sync_check_uuid, server_modified_date_string, weak_etag) values (?, ?, ?, ?, ?, ?)", relativePath, headEtag, localMD5, headDate, [NSNumber numberWithBool:headWeakEtag], _currentSyncUUID];
                        SDAssert(res);
                    }
                    */
                }
                else {
                    NSLog(@"Bad head on %@", pushToURL);
                    debug(@"[headRequest error]: '%@'", [headRequest error]);
                }
                
                [self removeURLFromActiveQueue:pushToURL];
                
                if ([self queueIsEmpty]) {
                    [self finishSyncing];
                }
            }];
        }];
        
        [pool release];
    }
    
    
    if ([self queueIsEmpty]) {
        [self finishSyncing];
    }
}

- (void)cleanupServerDeletes {
    
    //debug(@"Entering cleanupServerDeletes");
    
    NSMutableArray *localDeletes = [NSMutableArray array];
    
    FMResultSet *rs = [[self catalog] executeQuery:@"select path from sync_catalog where sync_check_uuid <> ?", _currentSyncUUID];
    while ([rs next]) {
        [localDeletes addObject:[rs stringForColumnIndex:0]];
    }
    
    NSFileManager *fm = [[[NSFileManager alloc] init] autorelease];
    
    for (NSString *relPath in localDeletes) {
        
        //debug(@"deleting: %@", relPath);
        
        NSURL *deleteURL = [NSURL fileURLWithPath:[[_localURL path] stringByAppendingString:relPath]];
        
        NSError *err;
        if ([fm fileExistsAtPath:[deleteURL path]] && ![fm removeItemAtURL:deleteURL error:&err]) {
            debug(@"err: '%@'", err);
            NSLog(@"Could not delete url: %@", deleteURL);
        }
        
        [[self catalog] executeUpdate:@"delete from sync_catalog where path = ?", relPath];
    }
    
    [self putChangedFilesFromLocalURL:nil];
}


- (void)cleanupServerDeletesIfDoneDownloading {
    
    if ([self queueIsEmpty]) {
        [self cleanupServerDeletes];
    }
}

- (void)getServerChangesAtURL:(NSURL*)endpointURL {
    
    if (!endpointURL) {
        endpointURL = _remoteURL;
    }
    
    debug(@"entering getServerChangesAtURL for %@", endpointURL);
    
    [self addURLToRequestQueue:endpointURL requestAction:@selector(fetchDirectoryListing) withFinishBlock:^(FMWebDAVRequest *dirRequest) {
        
        if ([dirRequest error]) {
            NSLog(@"error fetching directory listing: %@", [dirRequest error]);
        }
        
        for (NSDictionary *pathInfo in [dirRequest directoryListingWithAttributes]) {
            
            NSURL *newURL = [NSURL URLWithString:[[endpointURL absoluteString] stringByAppendingString:[pathInfo objectForKey:FMWebDAVHREFKey]]];
            
            [self getServerURLIfNeeded:newURL withPathInfo:pathInfo];
            
            if ([[pathInfo objectForKey:FMWebDAVContentTypeKey] hasSuffix:@"directory"] || [[pathInfo objectForKey:FMWebDAVURIKey] hasSuffix:@"/"]) {
                [self getServerChangesAtURL:newURL];
            }
        }
        
        [self removeURLFromActiveQueue:endpointURL];
        
        [self cleanupServerDeletesIfDoneDownloading];
    }];
}

- (void)cleanupLocalDeletesAtURL:(NSURL*)lURL {
    
    //debug(@"Entering cleanupLocalDeletesAtURL");
    
    //FIXME: eventually narrow it down with the lURL argument, which is currently ignored
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSMutableArray *deletes = [NSMutableArray array];
        
        NSFileManager *fm = [[[NSFileManager alloc] init] autorelease];
        FMResultSet *rs = [[self catalog] executeQuery:@"select path, file_type from sync_catalog order by 1"];
        
        while ([rs next]) {
            [deletes addObject:[rs resultDict]];
        }
        
        for (NSDictionary *d in deletes) {
            
            debug(@"deletes: '%@'", deletes);
            
            NSString *path = [d objectForKey:@"path"];
            NSString *type = [d objectForKey:@"file_type"];
            
            NSURL *lURL = [self localURLFromRelativePath:path];
            
            if (![fm fileExistsAtPath:[lURL path]]) {
                
                NSURL *rURL = [self serverURLFromRelativePath:path];
                
                if ([type isEqualTo:@"fold"] && ![[rURL absoluteString] hasSuffix:@"/"]) {
                    rURL = [NSURL URLWithString:[[rURL absoluteString] stringByAppendingString:@"/"]];
                }
                
                // FIXME: use a queue for this?
                FMWebDAVRequest *req = [[[FMWebDAVRequest requestToURL:rURL delegate:self] synchronous] delete];
                
                SDAssert(![req error]);
                
                [[self catalog] executeUpdate:@"delete from sync_catalog where path = ?", path];
                
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self getServerChangesAtURL:nil];
        });
    });
    
}


- (void)setFinishBlock:(void (^)(NSError *))block {
    [_finishBlock autorelease];
    _finishBlock = [block copy];
}

- (void)syncWithFinishBlock:(void (^)(NSError *))block {
    
    if (!_authenticated) {
        NSBeep();
        NSLog(@"Need to authenticate first!");
        return;
    }
    
    if (_currentSyncUUID) {
        NSLog(@"Pull already in progress!");
        
        if (block) {
            block(nil);
        }
        
        return;
    }
    
    _currentSyncUUID = [[NSString stringWithUUID] retain];
    
    [self setFinishBlock:block];
    
    [self cleanupLocalDeletesAtURL:nil];
}

- (void)sync {
    [self syncWithFinishBlock:nil];
}

- (void)start {
    if (![self setupLocalListener]) {
        debug(@"Could not open local listener!");
    }
    
    [self sync];
    
    debug(@"started.");
    
}

- (void)stop {
    
}

- (void)authenticateWithFinishBlock:(void (^)(NSError *))authBlock {
    
    SDAssert(_remoteURL);
    
    FMWebDAVRequest *r = [FMWebDAVRequest requestToURL:_remoteURL];
    [r setUsername:_username];
    [r setPassword:_password];
    
    [[r propfind] withFinishBlock:^(FMWebDAVRequest *getRequest) {
        
        if ([getRequest responseStatusCode] == 404) {
            
            [[[FMWebDAVRequest requestToURL:_remoteURL] createDirectory] withFinishBlock:^(FMWebDAVRequest *createRequest) {
                
                NSError *err = 0x00;
                
                if ([createRequest responseStatusCode] != FMWebDAVCreatedStatusCode) {
                    err = [NSError errorWithDomain:@"create" code:[createRequest responseStatusCode] userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Could not make base directory on server.", @"Could not make base directory on server.") forKey:NSLocalizedDescriptionKey]];
                }
                else {
                    _authenticated = YES;
                }
                
                authBlock(err);
            }];
            
        }
        else {
            
            NSError *err = 0x00;
            
            if ([getRequest responseStatusCode] != FMWebDAVMultiSTatusStatusCode) {
                
                if ([getRequest responseStatusCode] == FMWebDAVPaymentRequired) {
                    err = [NSError errorWithDomain:@"get" code:[getRequest responseStatusCode] userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Bad URL?", @"Bad URL?") forKey:NSLocalizedDescriptionKey]];
                }
                else if ([getRequest responseStatusCode] == FMWebDAVUnauthorized) {
                    err = [NSError errorWithDomain:@"get" code:[getRequest responseStatusCode] userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Bad username or password.", @"Bad username or password.") forKey:NSLocalizedDescriptionKey]];
                }
                else {
                    err = [NSError errorWithDomain:@"get" code:[getRequest responseStatusCode] userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Could not get base directory on server.", @"Could not get base directory on server.") forKey:NSLocalizedDescriptionKey]];
                }
            }
            else {
                _authenticated = YES;
            }
            
            authBlock(err);
        }
    }];
}

- (void)reflector:(id<SDReflector>)relector sawURLUpdated:(NSURL*)updatedURL {
    
}

@end
