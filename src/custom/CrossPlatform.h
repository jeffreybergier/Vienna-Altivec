//
//  CrossPlatform.h
//  Vienna
//
//  Created for Altivec Intelligence Cross-Compile Environment
//

#import <Cocoa/Cocoa.h>

BOOL createRecursiveDirectory(NSString * path);

// Class stubs — available on 10.6+, stubbed for Tiger
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1060
@interface NSRunningApplication : NSObject
+ (NSArray *)runningApplicationsWithBundleIdentifier:(NSString *)bundleIdentifier;
@end
#endif

// Protocol polyfills — available on 10.6+, stubbed for Tiger
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1060
@protocol NSWindowDelegate @end
@protocol NSApplicationDelegate @end
@protocol NSTableViewDelegate @end
@protocol NSTableViewDataSource @end
@protocol NSOutlineViewDelegate @end
@protocol NSOutlineViewDataSource @end
@protocol NSSplitViewDelegate @end
@protocol NSToolbarDelegate @end
@protocol NSComboBoxDelegate @end
@protocol NSTextFieldDelegate @end
@protocol NSTextViewDelegate @end
@protocol NSURLConnectionDelegate @end
@protocol NSURLConnectionDataDelegate @end
@protocol NSAnimationDelegate @end
@protocol NSMenuDelegate @end
@protocol NSTabViewDelegate @end
#endif

// XPInteger: matches NSTableViewDataSource row parameter type across SDK versions.
// Tiger SDK (10.4) uses int; 10.5+ SDK uses NSInteger. Both are 'int' on 32-bit,
// but the compiler checks the declared type, so we match what the SDK header says.
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
#define XPInteger NSInteger
#else
#define XPInteger int
#endif


@interface NSTableColumn (XP_Compatibility)
-(void)XP_setHidden:(BOOL)hidden;
-(BOOL)XP_isHidden;
@end

@interface NSCell (XP_Compatibility)
-(void)XP_setBackgroundStyle:(NSInteger)style;
-(NSInteger)backgroundStyle;
-(void)setBackgroundStyle:(NSInteger)style;
@end

@interface NSWindow (XP_Compatibility)
-(void)XP_setCollectionBehavior:(NSUInteger)behavior;
@end

@interface NSApplication (XP_Compatibility)
-(void)XP_setBadgeLabel:(NSString *)label;
@end

@interface NSFileManager (XP_Compatibility)
-(BOOL)XP_createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error;
@end

@interface NSURL (XP_Compatibility)
+(NSURL *)XP_fileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir;
+(NSURL *)XP_URLWithString:(NSString *)url;
+(NSURL *)XP_URLWithString:(NSString *)url relativeToURL:(NSURL *)baseURL;
-(NSString *)XP_pathExtension;
@end

@interface NSString (XP_Compatibility)
-(NSString *)XP_stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement;
-(NSString *)XP_stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement options:(NSStringCompareOptions)options range:(NSRange)searchRange;
@end

// XP_integerValue / XP_unsignedIntegerValue live on both NSNumber and NSString
// because callers may hold either type (JSON dicts return NSString, prefs return NSNumber).
@interface NSNumber (XP_Compatibility)
+(NSNumber *)XP_numberWithInteger:(NSInteger)value;
+(NSNumber *)XP_numberWithUnsignedInteger:(NSUInteger)value;
-(NSInteger)XP_integerValue;
-(NSUInteger)XP_unsignedIntegerValue;
@end

@interface NSString (XP_IntegerValue)
-(NSInteger)XP_integerValue;
-(NSUInteger)XP_unsignedIntegerValue;
@end

@interface NSImage (XP_Compatibility)
-(void)XP_drawInRect:(NSRect)dstRect fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op fraction:(CGFloat)delta respectFlipped:(BOOL)flipped hints:(NSDictionary *)hints;
@end

@interface NSDate (XP_Compatibility)
-(NSDate *)XP_dateByAddingTimeInterval:(NSTimeInterval)ti;
@end

@interface NSDateFormatter (XP_Compatibility)
+(NSString *)XP_localizedStringFromDate:(NSDate *)date dateStyle:(NSDateFormatterStyle)dateStyle timeStyle:(NSDateFormatterStyle)timeStyle;
@end

// XPViewController: use NSViewController on 10.6+, custom subclass on Tiger.
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1060
#define XPViewController NSViewController
#else
@interface XPViewController : NSResponder {
@protected
  NSView *_view;
}
- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle;
- (NSView *)view;
- (void)setView:(NSView *)view;
- (void)loadView;
- (void)viewWillAppear;
- (BOOL)commitEditing;
@end
#endif

@interface NSObject (XP_WebOpenPanel)
-(void)XP_chooseFilenames:(NSArray *)filenames;
@end

@interface NSBezierPath (XP_Compatibility)
+(NSBezierPath *)XP_bezierPathWithRoundedRect:(NSRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius;
@end

// Tiger (10.4): +[NSThread isMainThread] is 10.5+ only.
// Implemented via pthread_main_np() which is available on Darwin since 10.4.
@interface NSThread (XP_Compatibility)
+ (BOOL)XP_isMainThread;
@end

// Tiger (10.4): NSObject performSelector:onThread:withObject:waitUntilDone: is 10.5+ only.
// We implement it using NSRunLoop performSelector:target:argument:order:modes: + CFRunLoopWakeUp.
// The target thread must have registered its NSRunLoop under the key @"_XPRunLoop" in its
// threadDictionary before the first call (done by ASIHTTPRequest's +runRequests).
@interface NSObject (XP_ThreadPerform)
-(void)XP_performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)wait;
-(void)XP_performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)wait modes:(NSArray *)array;
@end
