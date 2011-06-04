//
//  SDApplication.m
//  syncdav
//
//  Created by August Mueller on 5/26/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import "SDApplication.h"
#import "FMWebDAVRequest.h"
#import <JSTalk/JSTalk.h>

@implementation SDApplication

- (id) init {
	self = [super init];
	if (self != nil) {
        [JSTalk listen];
	}
	return self;
}


- (void)doJavaScript:(NSString*)script {
    
    JSTalk *jst = [[[JSTalk alloc] init] autorelease];
    
    if (!jst) {
        NSBeep();
        NSLog(@"Could not create a JSTalk instance!");
        return;
    }
    
    NSMutableDictionary *env = [NSMutableDictionary dictionary];
    
    NSString *junk;
    if ([script hasPrefix:@"/"] && (junk = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:script] encoding:NSUTF8StringEncoding error:nil])) {
        [env setObject:[NSURL fileURLWithPath:script] forKey:@"scriptURL"];
        script = junk;
        [jst setEnv:env];
    }
    
    [jst executeString:@"SyncDAV = NSApplication.sharedApplication();"];
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [jst executeString:script];
    
    [pool release];
    
}

@end


// the scripts expect it to be done this way
@implementation NSApplication (JSTalkTestExtras)

// [NSApplication new1ArgBlockForJSFunction:function(arg1) { ... }];


+ (id)new1ArgBlockForJSFunction:(JSValueRefAndContextRef)callbackFunction {
    
	JSContextRef mainContext = [[JSCocoa controllerFromContext:callbackFunction.ctx] ctx];
	JSValueProtect(mainContext, callbackFunction.value);
    void (^theBlock)(id) = ^(id arg1) {
        [[JSCocoa controllerFromContext:mainContext] callJSFunction:callbackFunction.value withArguments:[NSArray arrayWithObjects:arg1, nil]];
    };
    
    return [theBlock copy];
}

// [NSApplication runJSFunctionInBackground:function() { ... }]

+ (void)runJSFunctionInBackground:(JSValueRefAndContextRef)callbackFunction {
    
    JSContextRef mainContext = [[JSCocoa controllerFromContext:callbackFunction.ctx] ctx];
    JSValueProtect(mainContext, callbackFunction.value);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[JSCocoa controllerFromContext:mainContext] callJSFunction:callbackFunction.value withArguments:nil];
    });
}


@end


@implementation FMWebDAVRequest (JSTalkTestExtras)

- (FMWebDAVRequest*)remove {
    return [self delete];
}

@end






