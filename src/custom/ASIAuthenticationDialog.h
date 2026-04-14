// Stub: ASIAuthenticationDialog is iOS-only.
// All usage in ASIHTTPRequest.m is guarded by #if TARGET_OS_IPHONE.
@interface ASIAuthenticationDialog : NSObject
+ (void)presentAuthenticationDialogForRequest:(id)request;
@end
