#import <Cocoa/Cocoa.h>
#import "stubs.h"

@implementation GrowlApplicationBridge
+(void)setGrowlDelegate:(NSObject<GrowlApplicationBridgeDelegate> *)delegate {}
+(void)notifyWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)notifName iconData:(NSData *)iconData priority:(float)priority isSticky:(BOOL)isSticky clickContext:(id)clickContext {}
+(void)notifyWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)notifName iconData:(NSData *)iconData priority:(float)priority isSticky:(BOOL)isSticky clickContext:(id)clickContext identifier:(NSString *)identifier {}
+(BOOL)isGrowlInstalled { return NO; }
+(BOOL)isGrowlRunning { return NO; }
@end
