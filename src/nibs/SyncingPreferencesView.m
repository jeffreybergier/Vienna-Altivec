//
// SyncingPreferencesView.m
// Programmatic view builder replacing SyncingPreferencesView.xib
//
#import "SyncingPreferencesViewController.h"

static NSTextField *spLabel(NSRect f, NSString *t, NSTextAlignment a) {
  NSTextField *v = [[[NSTextField alloc] initWithFrame:f] autorelease];
  [v setStringValue:t];
  [v setAlignment:a];
  [v setEditable:NO];
  [v setBordered:NO];
  [v setDrawsBackground:NO];
  [v setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
  return v;
}

@implementation SyncingPreferencesViewController (XP_LoadView)
- (void)loadView {
  NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 507, 247)] autorelease];

  // --- Sync enable checkbox ---
  NSButton *sb = [[[NSButton alloc] initWithFrame:NSMakeRect(18, 211, 463, 18)] autorelease];
  [sb setButtonType:NSSwitchButton];
  [sb setTitle:@"Sync with an Open Reader server"];
  [sb setFont:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]];
  [sb setTarget:self]; [sb setAction:@selector(changeSyncOpenReader:)];
  syncButton = sb; [view addSubview:sb];

  // --- Server source popup ---
  [view addSubview:spLabel(NSMakeRect(17, 163, 119, 21), @"Server:", NSRightTextAlignment)];
  NSPopUpButton *ors = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(138, 160, 175, 26) pullsDown:NO] autorelease];
  [ors addItemWithTitle:@"URL"]; [[ors lastItem] setTag:100];
  [ors setTarget:self]; [ors setAction:@selector(changeSource:)];
  openReaderSource = ors; [view addSubview:ors];

  // --- Host URL text field ---
  [view addSubview:spLabel(NSMakeRect(17, 128, 119, 22), @"URL: https://", NSRightTextAlignment)];
  NSTextField *orh = [[[NSTextField alloc] initWithFrame:NSMakeRect(140, 131, 296, 22)] autorelease];
  openReaderHost = orh; [view addSubview:orh];

  // --- Visit website button ---
  NSButton *vb = [[[NSButton alloc] initWithFrame:NSMakeRect(437, 125, 48, 32)] autorelease];
  [vb setTitle:@"Visit"]; [vb setTarget:self];
  [vb setAction:@selector(visitWebsite:)];
  [view addSubview:vb];

  // --- Credentials info text ---
  NSTextField *cit = [[[NSTextField alloc] initWithFrame:NSMakeRect(17, 79, 422, 33)] autorelease];
  [cit setStringValue:@""];
  [cit setEditable:NO];
  [cit setBordered:NO];
  [cit setDrawsBackground:NO];
  [cit setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
  credentialsInfoText = cit; [view addSubview:cit];

  // --- Login row ---
  [view addSubview:spLabel(NSMakeRect(-3, 54, 139, 17), @"Login:", NSRightTextAlignment)];
  NSTextField *un = [[[NSTextField alloc] initWithFrame:NSMakeRect(140, 51, 296, 22)] autorelease];
  username = un; [view addSubview:un];

  // --- Password row ---
  [view addSubview:spLabel(NSMakeRect(-3, 22, 139, 17), @"Password:", NSRightTextAlignment)];
  NSSecureTextField *pw = [[[NSSecureTextField alloc] initWithFrame:NSMakeRect(140, 19, 296, 22)] autorelease];
  password = pw; [view addSubview:pw];

  [self setView:view];
}
@end
