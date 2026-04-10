//
//  SyncPreferences.nib.m
//  Vienna / Altivec backport
//
//  Programmatic reconstruction of SyncPreferences.xib (v3.0.0, en.lproj).
//  All frame coordinates are taken directly from the XIB (AppKit non-flipped
//  origin: bottom-left, y increasing upward).
//
//  Window content size: {507, 247}
//
//  Controls (XIB id -> ivar/action):
//    565105119  NSButton checkbox   "Sync with an Open Reader server"  -> syncButton
//    964045615  NSTextField label   "Server:"
//    271039292  NSPopUpButton       (service selector)                 -> openReaderSource
//    383281994  NSTextField label   "URL: https://"
//    191197697  NSTextField editable (host/URL field)                  -> openReaderHost
//    949236059  NSButton            globe visit-website button         -> visitWebsite:
//    124146712  NSTextField label   (hint text, wrapping)              -> credentialsInfoText
//    941710880  NSTextField label   "Login:"
//     84390960  NSTextField editable (username field)                  -> username
//   1054133262  NSTextField label   "Password:"
//    835690345  NSSecureTextField   (password field)                   -> password
//

#import "SyncPreferences.nib.h"

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static NSTextField * makeLabel(NSString * text, NSRect frame, float fontSize, NSTextAlignment align)
{
    NSTextField * tf = [[NSTextField alloc] initWithFrame:frame];
    [tf setStringValue:text];
    [tf setEditable:NO];
    [tf setSelectable:NO];
    [tf setBezeled:NO];
    [tf setDrawsBackground:NO];
    [tf setFont:[NSFont systemFontOfSize:fontSize]];
    [tf setAlignment:align];
    [tf autorelease];
    return tf;
}

static NSTextField * makeField(NSRect frame)
{
    NSTextField * tf = [[NSTextField alloc] initWithFrame:frame];
    [tf setEditable:YES];
    [tf setSelectable:YES];
    [tf setBezeled:YES];
    [tf setDrawsBackground:YES];
    [tf setFont:[NSFont systemFontOfSize:13.0]];
    [tf autorelease];
    return tf;
}

// ---------------------------------------------------------------------------
// NibBuild category
// ---------------------------------------------------------------------------

@implementation SyncPreferences (NibBuild)

- (void)_buildWindow
{
    NSView * contentView = [[self window] contentView];

    // --- Checkbox: "Sync with an Open Reader server" ---
    // XIB frame: {{18, 211}, {463, 18}}
    syncButton = [[NSButton alloc] initWithFrame:NSMakeRect(18, 211, 463, 18)];
    [syncButton setButtonType:NSSwitchButton];
    [syncButton setTitle:@"Sync with an Open Reader server"];
    [syncButton setFont:[NSFont boldSystemFontOfSize:13.0]];
    [syncButton setTarget:self];
    [syncButton setAction:@selector(changeSyncGoogleReader:)];
    [contentView addSubview:syncButton];

    // --- Label: "Server:" ---
    // XIB frame: {{17, 163}, {119, 21}}
    [contentView addSubview:makeLabel(@"Server:", NSMakeRect(17, 163, 119, 21),
                                      13.0, NSRightTextAlignment)];

    // --- PopUpButton: service selector ---
    // XIB frame: {{138, 160}, {175, 26}}
    openReaderSource = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(138, 160, 175, 26)
                                                  pullsDown:NO];
    [openReaderSource setFont:[NSFont systemFontOfSize:13.0]];
    [openReaderSource setTarget:self];
    [openReaderSource setAction:@selector(changeSource:)];
    [contentView addSubview:openReaderSource];

    // --- Label: "URL: https://" ---
    // XIB frame: {{17, 128}, {119, 22}}
    [contentView addSubview:makeLabel(@"URL: https://", NSMakeRect(17, 128, 119, 22),
                                      13.0, NSRightTextAlignment)];

    // --- TextField: openReaderHost (editable) ---
    // XIB frame: {{140, 131}, {296, 22}}
    openReaderHost = makeField(NSMakeRect(140, 131, 296, 22));
    [contentView addSubview:openReaderHost];

    // --- Button: globe (visit website) ---
    // XIB frame: {{437, 125}, {48, 32}}
    NSButton * globeButton = [[NSButton alloc] initWithFrame:NSMakeRect(437, 125, 48, 32)];
    [globeButton setButtonType:NSMomentaryLightButton];
    [globeButton setBezelStyle:NSRoundedBezelStyle];
    [globeButton setTitle:@"Go"];
    [globeButton setTarget:self];
    [globeButton setAction:@selector(visitWebsite:)];
    [contentView addSubview:globeButton];
    [globeButton release];

    // --- TextField: credentialsInfoText (hint, wrapping, read-only) ---
    // XIB frame: {{17, 79}, {422, 33}}
    credentialsInfoText = [[NSTextField alloc] initWithFrame:NSMakeRect(17, 79, 422, 33)];
    [credentialsInfoText setEditable:NO];
    [credentialsInfoText setSelectable:NO];
    [credentialsInfoText setBezeled:NO];
    [credentialsInfoText setDrawsBackground:NO];
    [credentialsInfoText setFont:[NSFont systemFontOfSize:11.0]];
    [credentialsInfoText setStringValue:@""];
    [[credentialsInfoText cell] setWraps:YES];
    [contentView addSubview:credentialsInfoText];

    // --- Label: "Login:" ---
    // XIB frame: {{-3, 54}, {139, 17}} — right-aligned, clipped left edge intentional
    [contentView addSubview:makeLabel(@"Login:", NSMakeRect(-3, 54, 139, 17),
                                      13.0, NSRightTextAlignment)];

    // --- TextField: username (editable) ---
    // XIB frame: {{140, 51}, {296, 22}}
    username = makeField(NSMakeRect(140, 51, 296, 22));
    [contentView addSubview:username];

    // --- Label: "Password:" ---
    // XIB frame: {{-3, 22}, {139, 17}} — right-aligned, clipped left edge intentional
    [contentView addSubview:makeLabel(@"Password:", NSMakeRect(-3, 22, 139, 17),
                                      13.0, NSRightTextAlignment)];

    // --- SecureTextField: password ---
    // XIB frame: {{140, 19}, {296, 22}}
    // Declared as NSSecureTextField * in header; same layout as a regular field
    password = (NSSecureTextField *)[[NSSecureTextField alloc] initWithFrame:NSMakeRect(140, 19, 296, 22)];
    [password setEditable:YES];
    [password setSelectable:YES];
    [password setBezeled:YES];
    [password setDrawsBackground:YES];
    [password setFont:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:(NSView *)password];
}

@end
