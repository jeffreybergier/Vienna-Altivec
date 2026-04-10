//
//  SyncPreferences.m
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Updated by Barijaona Ramaholimihaso in July 2013 following Google Reader demise.
//  Copyright 2011-2013 Vienna contributors (see Help/Acknowledgements for list of contributors).
//  All rights reserved.
//
//  Ported to Tiger (10.4) / MRC by the Altivec project.
//  Changes from v3.0.0 original:
//    - Removed @property / @synthesize -> manual ivar (ObjC 2.0 not available on 10.4)
//    - Replaced initWithWindowNibName: -> programmatic window via _buildWindow (no NIB)
//    - Replaced fast enumeration -> NSEnumerator (for...in requires ObjC 2.0 / 10.5+)
//

#import "SyncPreferences.h"
#import "SyncPreferences.nib.h"
#import "GoogleReader.h"
#import "Preferences.h"
#import "KeyChain.h"
#import "StringExtensions.h"

@implementation SyncPreferences

static BOOL _credentialsChanged;

/* init
 * Build the window programmatically (replaces initWithWindowNibName:@"SyncPreferences").
 */
-(id)init
{
    NSRect contentRect = NSMakeRect(0, 0, 507, 247);
    NSWindow * win = [[NSWindow alloc] initWithContentRect:contentRect
                                                 styleMask:NSTitledWindowMask
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
    self = [super initWithWindow:win];
    [win release];
    if (self)
    {
        sourcesDict = nil;
        _credentialsChanged = NO;
        [self _buildWindow];
        [self windowDidLoad];
    }
    return self;
}

-(void)windowWillClose:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if ([syncButton state] == NSOnState && _credentialsChanged)
    {
        [[GoogleReader sharedManager] resetAuthentication];
        [[GoogleReader sharedManager] loadSubscriptions:nil];
    }
}

-(IBAction)changeSyncGoogleReader:(id)sender
{
    BOOL sync = [sender state] == NSOnState;
    Preferences *prefs = [Preferences standardPreferences];
    [prefs setSyncGoogleReader:sync];
    [prefs savePreferences];
    if (sync)
    {
        [openReaderSource setEnabled:YES];
        [openReaderHost setEnabled:YES];
        [username setEnabled:YES];
        [password setEnabled:YES];
        _credentialsChanged = YES;
    }
    else
    {
        [openReaderSource setEnabled:NO];
        [openReaderHost setEnabled:NO];
        [username setEnabled:NO];
        [password setEnabled:NO];
        [[GoogleReader sharedManager] clearAuthentication];
    }
}

-(IBAction)changeSource:(id)sender
{
    NSMenuItem * readerItem = [openReaderSource selectedItem];
    NSString * key = [readerItem title];
    NSDictionary * itemDict = [sourcesDict valueForKey:key];
    NSString * hostName = [itemDict valueForKey:@"Address"];
    if (!hostName)
        hostName = @"";
    NSString * hint = [itemDict valueForKey:@"Hint"];
    if (!hint)
        hint = @"";
    [openReaderHost setStringValue:hostName];
    [credentialsInfoText setStringValue:hint];
    if (sender != nil)
        [self handleServerTextDidChange:nil];
}

-(IBAction)visitWebsite:(id)sender
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/", [openReaderHost stringValue]]];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

/* handleServerTextDidChange [delegate / notification]
 */
-(void)handleServerTextDidChange:(NSNotification *)aNotification
{
    _credentialsChanged = YES;
    Preferences * prefs = [Preferences standardPreferences];
    if (!([[openReaderHost stringValue] isBlank] || [[username stringValue] isBlank]))
    {
        NSString * thePass = [KeyChain getWebPasswordFromKeychain:[username stringValue]
                                                              url:[NSString stringWithFormat:@"https://%@", [openReaderHost stringValue]]];
        if (![thePass isBlank])
        {
            [password setStringValue:thePass];
            [KeyChain setGenericPasswordInKeychain:[password stringValue]
                                         username:[username stringValue]
                                          service:@"Vienna sync"];
        }
    }
    [prefs setSyncServer:[openReaderHost stringValue]];
    [prefs savePreferences];
}

/* handleUserTextDidChange [delegate / notification]
 */
-(void)handleUserTextDidChange:(NSNotification *)aNotification
{
    _credentialsChanged = YES;
    Preferences * prefs = [Preferences standardPreferences];
    [KeyChain deleteGenericPasswordInKeychain:[prefs syncingUser] service:@"Vienna sync"];
    if (!([[openReaderHost stringValue] isBlank] || [[username stringValue] isBlank]))
    {
        NSString * thePass = [KeyChain getWebPasswordFromKeychain:[username stringValue]
                                                              url:[NSString stringWithFormat:@"https://%@", [openReaderHost stringValue]]];
        if (![thePass isBlank])
        {
            [password setStringValue:thePass];
            [KeyChain setGenericPasswordInKeychain:[password stringValue]
                                         username:[username stringValue]
                                          service:@"Vienna sync"];
        }
    }
    [prefs setSyncingUser:[username stringValue]];
    [prefs savePreferences];
}

/* handlePasswordTextDidChange [delegate / notification]
 */
-(void)handlePasswordTextDidChange:(NSNotification *)aNotification
{
    _credentialsChanged = YES;
    [KeyChain setGenericPasswordInKeychain:[password stringValue]
                                  username:[username stringValue]
                                   service:@"Vienna sync"];
}

/* windowDidLoad
 * Set up notifications, restore saved state, populate server list.
 * Called manually from -init after _buildWindow.
 */
-(void)windowDidLoad
{
    [super windowDidLoad];
    [[self window] setDelegate:self];

    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleGoogleAuthFailed:)
               name:@"MA_Notify_GoogleAuthFailed" object:nil];
    [nc addObserver:self selector:@selector(handleServerTextDidChange:)
               name:NSControlTextDidChangeNotification object:openReaderHost];
    [nc addObserver:self selector:@selector(handleUserTextDidChange:)
               name:NSControlTextDidChangeNotification object:username];
    [nc addObserver:self selector:@selector(handlePasswordTextDidChange:)
               name:NSControlTextDidEndEditingNotification object:password];

    // Restore from Preferences and keychain
    Preferences * prefs = [Preferences standardPreferences];
    [syncButton setState:[prefs syncGoogleReader] ? NSOnState : NSOffState];

    NSString * theUsername = [prefs syncingUser];
    if (!theUsername) theUsername = @"";
    NSString * theHost = [prefs syncServer];
    if (!theHost) theHost = @"";
    NSString * thePassword = [KeyChain getGenericPasswordFromKeychain:theUsername serviceName:@"Vienna sync"];
    if (!thePassword) thePassword = @"";

    [username setStringValue:theUsername];
    [openReaderHost setStringValue:theHost];
    [password setStringValue:thePassword];

    if (![prefs syncGoogleReader])
    {
        [openReaderSource setEnabled:NO];
        [openReaderHost setEnabled:NO];
        [username setEnabled:NO];
        [password setEnabled:NO];
    }
    _credentialsChanged = NO;

    // Load the list of known sync servers from KnownSyncServers.plist
    if (!sourcesDict)
    {
        NSBundle * thisBundle = [NSBundle bundleForClass:[self class]];
        NSString * pathToPList = [thisBundle pathForResource:@"KnownSyncServers" ofType:@"plist"];
        if (pathToPList != nil)
        {
            sourcesDict = [[NSDictionary dictionaryWithContentsOfFile:pathToPList] retain];
            [openReaderSource removeAllItems];
            if (sourcesDict)
            {
                [openReaderSource setEnabled:YES];
                BOOL match = NO;

                // Tiger: no fast enumeration, use NSEnumerator
                NSArray * keys = [sourcesDict allKeys];
                NSEnumerator * keyEnum = [keys objectEnumerator];
                NSString * key;
                while ((key = [keyEnum nextObject]))
                {
                    [openReaderSource addItemWithTitle:NSLocalizedString(key, nil)];
                    NSDictionary * itemDict = [sourcesDict valueForKey:key];
                    if ([theHost isEqualToString:[itemDict valueForKey:@"Address"]])
                    {
                        [openReaderSource selectItemWithTitle:NSLocalizedString(key, nil)];
                        [self changeSource:nil];
                        match = YES;
                    }
                }
                if (!match)
                {
                    [openReaderSource selectItemWithTitle:NSLocalizedString(@"Other", nil)];
                    [openReaderHost setStringValue:theHost];
                }
            }
        }
        else
            [openReaderSource setEnabled:NO];
    }
}

-(void)handleGoogleAuthFailed:(NSNotification *)nc
{
    if ([[self window] isVisible])
    {
        NSAlert * alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:NSLocalizedString(@"Open Reader Authentication Failed", nil)];
        [alert setInformativeText:NSLocalizedString(@"Make sure the username and password needed to access the Open Reader server are correctly set in Vienna's preferences.\nAlso check your network access.", nil)];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
        [[GoogleReader sharedManager] clearAuthentication];
    }
}

-(void)dealloc
{
    [sourcesDict release];
    sourcesDict = nil;
    [super dealloc];
}

@end
