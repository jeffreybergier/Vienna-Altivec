//
// AdvancedPreferencesView.m
// Programmatic view builder replacing AdvancedPreferencesView.xib
//
#import "AdvancedPreferencesViewController.h"

static NSTextField *advLabel(NSRect f, NSString *t, float sz) {
  NSTextField *v = [[[NSTextField alloc] initWithFrame:f] autorelease];
  [v setStringValue:t];
  [v setAlignment:NSLeftTextAlignment];
  [v setEditable:NO];
  [v setBordered:NO];
  [v setDrawsBackground:NO];
  [v setFont:[NSFont systemFontOfSize:sz]];
  [[v cell] setWraps:YES];
  [[v cell] setLineBreakMode:NSLineBreakByWordWrapping];
  return v;
}

static NSButton *advCheck(NSRect f, NSString *t, id target, SEL action) {
  NSButton *b = [[[NSButton alloc] initWithFrame:f] autorelease];
  [b setButtonType:NSSwitchButton];
  [b setTitle:t];
  [b setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
  [b setTarget:target];
  [b setAction:action];
  return b;
}

@implementation AdvancedPreferencesViewController (XP_LoadView)
- (void)loadView {
  NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 426, 273)] autorelease];
  float small = [NSFont smallSystemFontSize];

  // --- Description text ---
  [view addSubview:advLabel(NSMakeRect(17, 211, 381, 42),
    @"The settings here should not need to be changed for the normal use of Vienna. "
     "Refer to the Help file for details of each setting.", small)];

  // --- JavaScript ---
  NSButton *js = advCheck(NSMakeRect(18, 187, 275, 18), @"Enable JavaScript in the internal browser", self, @selector(changeUseJavaScript:));
  useJavaScriptButton = js; [view addSubview:js];

  // --- Web plugins ---
  NSButton *wp = advCheck(NSMakeRect(18, 166, 390, 18), @"Enable Plugins in the internal browser", self, @selector(changeUseWebPlugins:));
  useWebPluginsButton = wp; [view addSubview:wp];

  // --- Concurrent downloads ---
  NSTextField *cdLbl = [[[NSTextField alloc] initWithFrame:NSMakeRect(17, 143, 151, 17)] autorelease];
  [cdLbl setStringValue:@"Concurrent downloads:"];
  [cdLbl setAlignment:NSLeftTextAlignment];
  [cdLbl setEditable:NO]; [cdLbl setBordered:NO]; [cdLbl setDrawsBackground:NO];
  [cdLbl setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
  [view addSubview:cdLbl];

  NSPopUpButton *cd = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(170, 137, 62, 26) pullsDown:NO] autorelease];
  [cd addItemWithTitle:@"1"];
  [cd addItemWithTitle:@"2"];
  [cd addItemWithTitle:@"5"];
  [cd addItemWithTitle:@"10"];
  [cd addItemWithTitle:@"15"];
  [cd addItemWithTitle:@"30"];
  [cd addItemWithTitle:@"50"];
  [cd setTarget:self]; [cd setAction:@selector(changeConcurrentDownloads:)];
  concurrentDownloads = cd; [view addSubview:cd];

  // --- Help text below downloads ---
  [view addSubview:advLabel(NSMakeRect(17, 90, 392, 33),
    @"The higher the number, the quicker your subscriptions will be downloaded.", small)];
  [view addSubview:advLabel(NSMakeRect(17, 49, 392, 33),
    @"However, high numbers also render your computer less responsive while refreshing feeds.", small)];

  // --- Help button ---
  NSButton *helpBtn = [[[NSButton alloc] initWithFrame:NSMakeRect(384, 17, 25, 25)] autorelease];
  [helpBtn setButtonType:NSMomentaryLightButton];
  [helpBtn setBezelStyle:NSHelpButtonBezelStyle];
  [helpBtn setTitle:@""];
  [helpBtn setTarget:self]; [helpBtn setAction:@selector(showAdvancedHelp:)];
  [view addSubview:helpBtn];

  [self setView:view];
}
@end
