// Stub: Reachability is an iOS library. On Mac/Tiger, network reachability
// checks via SCNetworkReachability are not needed. All WWAN checks will
// return NO and the reachability notifier will be a no-op.

typedef enum {
  NotReachable = 0,
  ReachableViaWiFi,
  ReachableViaWWAN,
} NetworkStatus;

extern NSString *kReachabilityChangedNotification;

@interface Reachability : NSObject
+ (Reachability *)reachabilityForInternetConnection;
- (BOOL)startNotifier;
- (NetworkStatus)currentReachabilityStatus;
@end
