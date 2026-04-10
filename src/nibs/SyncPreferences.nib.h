//
//  SyncPreferences.nib.h
//  Vienna / Altivec backport
//
//  Declares the programmatic window builder category for SyncPreferences.
//  This replaces the SyncPreferences.xib from v3.0.0 which cannot be
//  compiled on a Tiger-targeting Linux build host.
//
//  XIB source: lproj/en.lproj/SyncPreferences.xib @ v/3.0.0
//  Window size: 507 x 247
//

#import "SyncPreferences.h"

@interface SyncPreferences (NibBuild)
// Called from -[SyncPreferences init] to build the window UI without a NIB.
- (void)_buildWindow;
@end
