//
//  flysyncAppDelegate.h
//  flysync
//
//  Created by August Mueller on 5/24/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SDManager.h"

@interface SDAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
    
    SDManager *_manager;
    
    IBOutlet NSTextField *userTextField;
    IBOutlet NSTextField *passTextField;
    IBOutlet NSTextField *urlTextField;
    IBOutlet NSPathControl *localPathControl;
    IBOutlet NSTextField *statusTextField;
    
    IBOutlet NSButton *syncButton;
    IBOutlet NSProgressIndicator *progressSpinner;
    
}

@property (assign) IBOutlet NSWindow *window;

- (void)syncAction:(id)sender;
- (void)chooseLocalFolderAction:(id)sender;

@end
