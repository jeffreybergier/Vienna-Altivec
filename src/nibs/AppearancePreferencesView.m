//
// AppearancePreferencesView.m
// Programmatic view builder replacing AppearancePreferencesView.xib
//
#import "AppearancePreferencesViewController.h"

static NSTextField *apLabel(NSRect f, NSString *t, NSTextAlignment a) {
  NSTextField *v = [[[NSTextField alloc] initWithFrame:f] autorelease];
  [v setStringValue:t];
  [v setAlignment:a];
  [v setEditable:NO];
  [v setBordered:NO];
  [v setDrawsBackground:NO];
  [v setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
  return v;
}

static NSButton *apCheck(NSRect f, NSString *t, id target, SEL action) {
  NSButton *b = [[[NSButton alloc] initWithFrame:f] autorelease];
  [b setButtonType:NSSwitchButton];
  [b setTitle:t];
  [b setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
  [b setTarget:target];
  [b setAction:action];
  return b;
}

@implementation AppearancePreferencesViewController (XP_LoadView)
- (void)loadView {
  NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 501, 184)] autorelease];

  // --- Article list font row ---
  [view addSubview:apLabel(NSMakeRect(17, 145, 154, 17), @"Article list font:", NSRightTextAlignment)];
  NSTextField *afs = [[[NSTextField alloc] initWithFrame:NSMakeRect(176, 142, 204, 22)] autorelease];
  [afs setStringValue:@"(Sample)"];
  [afs setAlignment:NSCenterTextAlignment];
  [afs setEditable:NO];
  [afs setBordered:YES];
  [afs setDrawsBackground:YES];
  articleFontSample = afs; [view addSubview:afs];
  NSButton *afb = [[[NSButton alloc] initWithFrame:NSMakeRect(382, 134, 105, 32)] autorelease];
  [afb setTitle:@"Select..."]; [afb setTarget:self];
  [afb setAction:@selector(selectArticleFont:)];
  articleFontSelectButton = afb; [view addSubview:afb];

  // --- Folder list font row ---
  [view addSubview:apLabel(NSMakeRect(17, 115, 154, 17), @"Folder list font:", NSRightTextAlignment)];
  NSTextField *ffs = [[[NSTextField alloc] initWithFrame:NSMakeRect(176, 112, 204, 22)] autorelease];
  [ffs setStringValue:@"(Sample)"];
  [ffs setAlignment:NSCenterTextAlignment];
  [ffs setEditable:NO];
  [ffs setBordered:YES];
  [ffs setDrawsBackground:YES];
  folderFontSample = ffs; [view addSubview:ffs];
  NSButton *ffb = [[[NSButton alloc] initWithFrame:NSMakeRect(382, 105, 105, 32)] autorelease];
  [ffb setTitle:@"Select..."]; [ffb setTarget:self];
  [ffb setAction:@selector(selectFolderFont:)];
  folderFontSelectButton = ffb; [view addSubview:ffb];

  // --- Minimum font size ---
  [view addSubview:apLabel(NSMakeRect(17, 76, 467, 17), @"When viewing articles or web pages:", NSLeftTextAlignment)];
  NSButton *emfs = apCheck(NSMakeRect(30, 52, 233, 18), @"Never use font sizes smaller than", self, @selector(changeMinimumFontSize:));
  enableMinimumFontSize = emfs; [view addSubview:emfs];
  NSComboBox *mfsz = [[[NSComboBox alloc] initWithFrame:NSMakeRect(269, 47, 48, 26)] autorelease];
  [mfsz setNumberOfVisibleItems:5];
  [mfsz setCompletes:NO];
  [mfsz setTarget:self]; [mfsz setAction:@selector(selectMinimumFontSize:)];
  minimumFontSizes = mfsz; [view addSubview:mfsz];

  // --- Show folder images ---
  NSButton *sfi = apCheck(NSMakeRect(18, 18, 465, 18), @"Show feeds icons in folder list", self, @selector(changeShowFolderImages:));
  showFolderImagesButton = sfi; [view addSubview:sfi];

  [self setView:view];
}
@end
