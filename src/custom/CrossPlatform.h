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
#endif

// XPInteger: matches NSTableViewDataSource row parameter type across SDK versions.
// Tiger SDK (10.4) uses int; 10.5+ SDK uses NSInteger. Both are 'int' on 32-bit,
// but the compiler checks the declared type, so we match what the SDK header says.
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
#define XPInteger NSInteger
#else
#define XPInteger int
#endif

// Fast enumeration polyfill for Tiger (10.4) which lacks NSFastEnumeration support
@interface NSArray (XP_FastEnumeration)
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len;
@end

@interface NSSet (XP_FastEnumeration)
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len;
@end

@interface NSDictionary (XP_FastEnumeration)
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len;
@end

@interface NSEnumerator (XP_FastEnumeration)
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len;
@end

@interface NSCell (XP_Compatibility)
-(void)XP_setBackgroundStyle:(NSInteger)style;
@end

#if !defined(NSWindowCollectionBehaviorFullScreenPrimary)
enum { NSWindowCollectionBehaviorFullScreenPrimary = (1 << 7) };
#endif

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

@interface NSNumber (XP_Compatibility)
+(NSNumber *)XP_numberWithInteger:(NSInteger)value;
+(NSNumber *)numberWithInteger:(NSInteger)value;
+(NSNumber *)numberWithUnsignedInteger:(NSUInteger)value;
-(NSInteger)integerValue;
-(NSUInteger)unsignedIntegerValue;
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

@interface NSViewController (XP_Compatibility)
-(void)viewWillAppear;
@end

@interface NSObject (XP_WebOpenPanel)
-(void)XP_chooseFilenames:(NSArray *)filenames;
@end

@interface NSBezierPath (XP_Compatibility)
+(NSBezierPath *)XP_bezierPathWithRoundedRect:(NSRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius;
@end

// Tiger (10.4): +[NSThread isMainThread] is 10.5+ only.
// Implemented via pthread_main_np() which is available on Darwin since 10.4.
@interface NSThread (XP_Compatibility)
+ (BOOL)isMainThread;
@end

// Tiger (10.4): NSObject performSelector:onThread:withObject:waitUntilDone: is 10.5+ only.
// We implement it using NSRunLoop performSelector:target:argument:order:modes: + CFRunLoopWakeUp.
// The target thread must have registered its NSRunLoop under the key @"_XPRunLoop" in its
// threadDictionary before the first call (done by ASIHTTPRequest's +runRequests).
@interface NSObject (XP_ThreadPerform)
-(void)performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)wait;
-(void)performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)wait modes:(NSArray *)array;
@end
