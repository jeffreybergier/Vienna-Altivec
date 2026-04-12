#import <Cocoa/Cocoa.h>
#import "stubs.h"

@implementation GrowlApplicationBridge
+(void)setGrowlDelegate:(NSObject<GrowlApplicationBridgeDelegate> *)delegate {}
+(void)notifyWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)notifName iconData:(NSData *)iconData priority:(float)priority isSticky:(BOOL)isSticky clickContext:(id)clickContext {}
+(void)notifyWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)notifName iconData:(NSData *)iconData priority:(float)priority isSticky:(BOOL)isSticky clickContext:(id)clickContext identifier:(NSString *)identifier {}
+(BOOL)isGrowlInstalled { return NO; }
+(BOOL)isGrowlRunning { return NO; }
@end

@implementation SUUpdater
+(SUUpdater *)sharedUpdater;
{
    static SUUpdater * sharedInstance = nil;
    if (!sharedInstance)
        sharedInstance = [[SUUpdater alloc] init];
    return sharedInstance;
}

+(SUUpdater *)updaterForBundle:(NSBundle *)bundle;
{
    (void)bundle;
    return [SUUpdater sharedUpdater];
}

-(void)setSendsSystemProfile:(BOOL)sends;
{
    (void)sends;
}

-(BOOL)sendsSystemProfile;
{
    return NO;
}

-(void)setAutomaticallyChecksForUpdates:(BOOL)flag;
{
    (void)flag;
}

-(BOOL)automaticallyChecksForUpdates;
{
    return NO;
}

-(void)setFeedURL:(NSURL *)feedURL;
{
    (void)feedURL;
}

-(void)awakeFromNib;
{
    NSLog(@"[SUUpdater.awakeFromNib] stub");
}

-(void)checkForUpdates:(id)sender;
{
    NSLog(@"[SUUpdater.checkForUpdates] stub");
}
@end
