#ifdef __OBJC__
#import <Cocoa/Cocoa.h>

// ---- Growl ----
#define GROWL_APP_NAME                           @"ApplicationName"
#define GROWL_NOTIFICATIONS_ALL                  @"AllNotifications"
#define GROWL_NOTIFICATIONS_DEFAULT              @"DefaultNotifications"
#define GROWL_NOTIFICATIONS_HUMAN_READABLE_NAMES @"HumanReadableNames"

@protocol GrowlApplicationBridgeDelegate <NSObject>
@optional
- (NSDictionary *)registrationDictionaryForGrowl;
- (void)growlNotificationWasClicked:(id)clickContext;
@end

@interface GrowlApplicationBridge : NSObject
+ (void)setGrowlDelegate:(NSObject<GrowlApplicationBridgeDelegate> *)delegate;
+ (void)notifyWithTitle:(NSString *)title
            description:(NSString *)description
       notificationName:(NSString *)notifName
               iconData:(NSData *)iconData
               priority:(float)priority
               isSticky:(BOOL)isSticky
           clickContext:(id)clickContext;
+ (void)notifyWithTitle:(NSString *)title
            description:(NSString *)description
       notificationName:(NSString *)notifName
               iconData:(NSData *)iconData
               priority:(float)priority
               isSticky:(BOOL)isSticky
           clickContext:(id)clickContext
             identifier:(NSString *)identifier;
+ (BOOL)isGrowlInstalled;
+ (BOOL)isGrowlRunning;
@end

// ---- Sparkle ----
#define SUUpdaterWillRestartNotification @"SUUpdaterWillRestartNotification"

@interface SUUpdater : NSObject
+ (SUUpdater *)sharedUpdater;
+ (SUUpdater *)updaterForBundle:(NSBundle *)bundle;
- (void)checkForUpdates:(id)sender;
- (void)setSendsSystemProfile:(BOOL)flag;
- (BOOL)sendsSystemProfile;
- (void)setAutomaticallyChecksForUpdates:(BOOL)flag;
- (BOOL)automaticallyChecksForUpdates;
- (void)setFeedURL:(NSURL *)feedURL;
@end

#endif
