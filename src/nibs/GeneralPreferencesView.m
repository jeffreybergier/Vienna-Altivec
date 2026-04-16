//
// GeneralPreferencesView.m
// Programmatic view builder replacing GeneralPreferencesView.xib
// Called by XPViewController when -view is first accessed.
//
#import "GeneralPreferencesViewController.h"

static NSTextField *gpLabel(NSRect f, NSString *t, NSTextAlignment a) {
  NSTextField *v = [[[NSTextField alloc] initWithFrame:f] autorelease];
  [v setStringValue:t];
  [v setAlignment:a];
  [v setEditable:NO];
  [v setBordered:NO];
  [v setDrawsBackground:NO];
  [v setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
  return v;
}

static NSButton *gpCheck(NSRect f, NSString *t, id target, SEL action) {
  NSButton *b = [[[NSButton alloc] initWithFrame:f] autorelease];
  [b setButtonType:NSSwitchButton];
  [b setTitle:t];
  [b setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
  [b setTarget:target];
  [b setAction:action];
  return b;
}

@implementation GeneralPreferencesViewController (XP_LoadView)
- (void)loadView {
  NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 525, 499)] autorelease];

  appToPathMap = [[NSMutableDictionary alloc] init];

  // --- Row: Check for new articles ---
  [view addSubview:gpLabel(NSMakeRect(18, 461, 278, 17), @"Check for new articles:", NSRightTextAlignment)];
  NSPopUpButton *cfq = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(304, 455, 193, 26) pullsDown:NO] autorelease];
  [cfq addItemWithTitle:@"Manually"]; [[cfq lastItem] setTag:0];
  [[cfq menu] addItem:[NSMenuItem separatorItem]];
  [cfq addItemWithTitle:@"Every 5 minutes"]; [[cfq lastItem] setTag:300];
  [cfq addItemWithTitle:@"Every 15 minutes"]; [[cfq lastItem] setTag:900];
  [cfq addItemWithTitle:@"Every 30 minutes"]; [[cfq lastItem] setTag:1800];
  [[cfq menu] addItem:[NSMenuItem separatorItem]];
  [cfq addItemWithTitle:@"Every hour"]; [[cfq lastItem] setTag:3600];
  [cfq addItemWithTitle:@"Every 2 hours"]; [[cfq lastItem] setTag:7200];
  [cfq addItemWithTitle:@"Every 3 hours"]; [[cfq lastItem] setTag:10800];
  [cfq addItemWithTitle:@"Every 6 hours"]; [[cfq lastItem] setTag:21600];
  [cfq setTarget:self]; [cfq setAction:@selector(changeCheckFrequency:)];
  checkFrequency = cfq; [view addSubview:cfq];

  // --- Row: Move articles to Trash ---
  [view addSubview:gpLabel(NSMakeRect(18, 431, 278, 17), @"Move articles to Trash:", NSRightTextAlignment)];
  NSPopUpButton *exp = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(304, 425, 193, 26) pullsDown:NO] autorelease];
  [exp setTarget:self]; [exp setAction:@selector(changeExpireDuration:)];
  expireDuration = exp; [view addSubview:exp];

  // --- Row: Default RSS Reader ---
  [view addSubview:gpLabel(NSMakeRect(18, 402, 278, 17), @"Default RSS Reader:", NSRightTextAlignment)];
  NSPopUpButton *lh = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(304, 396, 193, 26) pullsDown:NO] autorelease];
  [lh addItemWithTitle:@"Nothing"];
  [lh setTarget:self]; [lh setAction:@selector(selectDefaultLinksHandler:)];
  linksHandler = lh; [view addSubview:lh];

  // --- Row: Save downloaded files to ---
  [view addSubview:gpLabel(NSMakeRect(18, 373, 278, 17), @"Save downloaded files to:", NSRightTextAlignment)];
  NSPopUpButton *df = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(304, 366, 193, 26) pullsDown:NO] autorelease];
  [df addItemWithTitle:@"(Path)"]; [[df lastItem] setTag:0];
  [[df menu] addItem:[NSMenuItem separatorItem]];
  NSMenuItem *otherItem = [[[NSMenuItem alloc] initWithTitle:@"Other..." action:@selector(changeDownloadFolder:) keyEquivalent:@""] autorelease];
  [otherItem setTarget:self]; [[df menu] addItem:otherItem];
  downloadFolder = df; [view addSubview:df];

  // --- Updates section ---
  [view addSubview:gpLabel(NSMakeRect(19, 222, 410, 17), @"Updates:", NSLeftTextAlignment)];
  NSButton *cfu = gpCheck(NSMakeRect(31, 198, 476, 18), @"Check for newer versions of Vienna on start up", self, @selector(changeCheckForUpdates:));
  checkForUpdates = cfu; [view addSubview:cfu];
  NSButton *ss = gpCheck(NSMakeRect(31, 176, 476, 18), @"Include anonymous system profile", self, @selector(changeSendSystemSpecs:));
  sendSystemSpecs = ss; [view addSubview:ss];
  NSButton *ab = gpCheck(NSMakeRect(31, 154, 464, 18), @"Search for latest Beta versions", self, @selector(changeAlwaysAcceptBetas:));
  alwaysAcceptBetas = ab; [view addSubview:ab];

  // --- General behaviour ---
  NSButton *cos = gpCheck(NSMakeRect(19, 337, 476, 18), @"Check for new articles on start up", self, @selector(changeCheckOnStartUp:));
  checkOnStartUp = cos; [view addSubview:cos];
  NSButton *olib = gpCheck(NSMakeRect(19, 314, 476, 18), @"Open new links in the background", self, @selector(changeOpenLinksInBackground:));
  openLinksInBackground = olib; [view addSubview:olib];
  NSButton *olex = gpCheck(NSMakeRect(19, 291, 476, 18), @"Open links in external browser", self, @selector(changeOpenLinksInExternalBrowser:));
  openLinksInExternalBrowser = olex; [view addSubview:olex];
  NSButton *mun = gpCheck(NSMakeRect(19, 268, 476, 18), @"Mark updated articles as new", self, @selector(changeMarkUpdatedAsNew:));
  markUpdatedAsNew = mun; [view addSubview:mun];
  NSButton *simb = gpCheck(NSMakeRect(19, 245, 476, 18), @"Show in menu bar", self, @selector(changeShowAppInMenuBar:));
  showAppInMenuBar = simb; [view addSubview:simb];

  // --- New articles notifications ---
  [view addSubview:gpLabel(NSMakeRect(18, 131, 410, 17), @"When new unread articles are retrieved:", NSLeftTextAlignment)];
  NSButton *badgeBtn = gpCheck(NSMakeRect(31, 107, 465, 18), @"Show the unread count on the application icon", self, @selector(changeNewArticlesNotificationBadge:));
  newArticlesNotificationBadgeButton = (NSButtonCell *)[badgeBtn cell];
  [view addSubview:badgeBtn];
  NSButton *bounceBtn = gpCheck(NSMakeRect(31, 87, 465, 18), @"Bounce the application icon", self, @selector(changeNewArticlesNotificationBounce:));
  newArticlesNotificationBounceButton = (NSButtonCell *)[bounceBtn cell];
  [view addSubview:bounceBtn];

  // --- Mark read behaviour ---
  [view addSubview:gpLabel(NSMakeRect(19, 64, 410, 17), @"Mark current article read:", NSLeftTextAlignment)];
  NSMatrix *matrix = [[[NSMatrix alloc] initWithFrame:NSMakeRect(32, 20, 462, 38)
                                                 mode:NSRadioModeMatrix
                                            cellClass:[NSButtonCell class]
                                         numberOfRows:2
                                      numberOfColumns:1] autorelease];
  [matrix setAutosizesCells:NO];
  [matrix setCellSize:NSMakeSize(462, 18)];
  [matrix setIntercellSpacing:NSMakeSize(4, 2)];
  [matrix setAllowsEmptySelection:NO];
  [matrix setTarget:self];
  [matrix setAction:@selector(changeMarkReadBehaviour:)];
  NSButtonCell *c0 = [matrix cellAtRow:0 column:0];
  [c0 setButtonType:NSRadioButton];
  [c0 setTitle:@"After \"Next Unread\" command"];
  NSButtonCell *c1 = [matrix cellAtRow:1 column:0];
  [c1 setButtonType:NSRadioButton];
  [c1 setTitle:@"After a short delay"];
  [c1 setTag:1];
  markReadAfterNext = c0;
  markReadAfterDelay = c1;
  [view addSubview:matrix];

  [self setView:view];
}
@end
