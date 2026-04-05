#ifdef __OBJC__
#import <Cocoa/Cocoa.h>

@protocol GrowlApplicationBridgeDelegate <NSObject>
@end

// Growl Stubs
@interface GrowlApplicationBridge : NSObject
+(void)setGrowlDelegate:(NSObject<GrowlApplicationBridgeDelegate> *)delegate;
+(void)notifyWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)notifName iconData:(NSData *)iconData priority:(float)priority isSticky:(BOOL)isSticky clickContext:(id)clickContext;
+(void)notifyWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)notifName iconData:(NSData *)iconData priority:(float)priority isSticky:(BOOL)isSticky clickContext:(id)clickContext identifier:(NSString *)identifier;
+(BOOL)isGrowlInstalled;
+(BOOL)isGrowlRunning;
@end

#define GROWL_APP_NAME @"GrowlAppName"
#define GROWL_NOTIFICATIONS_ALL @"GrowlAllNotifications"
#define GROWL_NOTIFICATIONS_DEFAULT @"GrowlDefaultNotifications"

// Sparkle Stubs
#define SUUpdaterWillRestartNotification @"SUUpdaterWillRestartNotification"

// 10.5 Compatibility Stubs
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1060
@protocol NSMenuDelegate <NSObject>
@end
@protocol NSTabViewDelegate <NSObject>
@end
#endif

#endif
