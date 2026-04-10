//
//  SyncPreferences.h
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011 Vienna contributors. All rights reserved.
//
//  Ported to Tiger (10.4) / MRC by the Altivec project.
//  Changes from v3.0.0 original:
//    - Removed @property -> manual ivar (ObjC 2.0 not available on 10.4)
//

#import <Cocoa/Cocoa.h>

// NSTextFieldDelegate and NSWindowDelegate are informal protocols on Tiger (10.4);
// formal protocol declarations were added in 10.6. Conformance via method presence.
@interface SyncPreferences : NSWindowController {
    NSButton * syncButton;
    IBOutlet NSPopUpButton * openReaderSource;
    NSDictionary * sourcesDict;
    IBOutlet NSTextField * credentialsInfoText;
    IBOutlet NSTextField * openReaderHost;
    IBOutlet NSTextField * username;
    IBOutlet NSSecureTextField * password;
}

-(IBAction)changeSyncGoogleReader:(id)sender;
-(IBAction)changeSource:(id)sender;
-(IBAction)visitWebsite:(id)sender;

@end
