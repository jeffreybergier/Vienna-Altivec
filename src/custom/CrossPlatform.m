#import "Vienna_Prefix.pch"
#import "CrossPlatform.h"
#import <objc/objc-runtime.h>
#import <pthread.h>

// ---- ObjC2 runtime polyfills for Tiger (10.4) ----
// GCC adds one leading underscore to C symbols, so objc_setProperty → _objc_setProperty in Mach-O,
// which matches the reference emitted by @synthesize-generated setters.

__attribute__((weak)) void objc_setProperty(id self, SEL _cmd, ptrdiff_t offset, id newValue, BOOL atomic, signed char shouldCopy) {
  (void)_cmd; (void)atomic;
  id *slot = (id *)((char *)self + offset);
  id oldValue = *slot;
  id toStore;
  if (shouldCopy == 1) {
    toStore = [newValue copy];
  } else if (shouldCopy == 2) {
    toStore = [newValue mutableCopy];
  } else {
    toStore = [newValue retain];
  }
  *slot = toStore;
  [oldValue release];
}

// Getter variant (for atomic retain properties — returns retained-then-autoreleased)
__attribute__((weak)) id objc_getProperty(id self, SEL _cmd, ptrdiff_t offset, BOOL atomic) {
  (void)_cmd; (void)atomic;
  id *slot = (id *)((char *)self + offset);
  return [[*slot retain] autorelease];
}

// Called when a collection is mutated during fast enumeration
void objc_enumerationMutation(id object) {
  (void)object;
  [[NSException exceptionWithName:NSGenericException reason:@"Collection mutated during enumeration" userInfo:nil] raise];
}

/* createRecursiveDirectory
 * Recursively creates a directory path. Added for Tiger compatibility.
 */
BOOL createRecursiveDirectory(NSString * path)
{
	NSFileManager * fileManager = [NSFileManager defaultManager];
	BOOL isDir;
	if ([fileManager fileExistsAtPath:path isDirectory:&isDir]) return isDir;
	NSString * parentPath = [path stringByDeletingLastPathComponent];
	if (!createRecursiveDirectory(parentPath)) return NO;
	return [fileManager createDirectoryAtPath:path attributes:nil];
}

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1060
@implementation NSRunningApplication
+ (NSArray *)runningApplicationsWithBundleIdentifier:(NSString *)bundleIdentifier;
{
  // 10.6+ only — return empty on Tiger to allow caller to launch the app
  (void)bundleIdentifier;
  return [NSArray array];
}
@end
#endif

@implementation NSTableColumn (XP_Compatibility)
-(void)XP_setHidden:(BOOL)hidden {
  if ([self respondsToSelector:@selector(setHidden:)])
    [self setHidden:hidden];
}
-(BOOL)XP_isHidden {
  if ([self respondsToSelector:@selector(isHidden)])
    return [self isHidden];
  return NO;
}
@end

@implementation NSCell (XP_Compatibility)
-(void)XP_setBackgroundStyle:(NSInteger)style;
{
	SEL sel = @selector(setBackgroundStyle:);
	if ([self respondsToSelector:sel])
	{
		typedef void (*MethodPtr)(id, SEL, NSInteger);
		MethodPtr m = (MethodPtr)[self methodForSelector:sel];
		m(self, sel, style);
	}
}
// Tiger (10.4) NSCell lacks backgroundStyle/setBackgroundStyle:.
// Provide stubs so subclasses (e.g. BJRVerticallyCenteredTextFieldCell) don't crash.
// On 10.5+ the category is shadowed by the real implementation via the runtime.
-(NSInteger)backgroundStyle { return 0; } // NSBackgroundStyleLight
-(void)setBackgroundStyle:(NSInteger)style { (void)style; }
@end

@implementation NSWindow (XP_Compatibility)
-(void)XP_setCollectionBehavior:(NSUInteger)behavior {
	SEL sel = @selector(setCollectionBehavior:);
	if ([self respondsToSelector:sel]) {
		typedef void (*MethodPtr)(id, SEL, NSUInteger);
		MethodPtr m = (MethodPtr)[self methodForSelector:sel];
		m(self, sel, behavior);
	}
}
@end

@implementation NSApplication (XP_Compatibility)
-(void)XP_setBadgeLabel:(NSString *)label {
	SEL tilesel = @selector(dockTile);
	if (![self respondsToSelector:tilesel]) return;
	typedef id (*TilePtr)(id, SEL);
	id tile = ((TilePtr)[self methodForSelector:tilesel])(self, tilesel);
	SEL badgesel = @selector(setBadgeLabel:);
	typedef void (*BadgePtr)(id, SEL, NSString*);
	((BadgePtr)[tile methodForSelector:badgesel])(tile, badgesel, label);
}
@end

@implementation NSFileManager (XP_Compatibility)
-(BOOL)XP_createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error;
{
	SEL sel = @selector(createDirectoryAtPath:withIntermediateDirectories:attributes:error:);
	if ([self respondsToSelector:sel])
	{
		typedef BOOL (*MethodPtr)(id, SEL, NSString*, BOOL, NSDictionary*, NSError**);
		MethodPtr m = (MethodPtr)[self methodForSelector:sel];
		return m(self, sel, path, createIntermediates, attributes, error);
	}

	if (createIntermediates)
		return createRecursiveDirectory(path);

	return [self createDirectoryAtPath:path attributes:attributes];
}
@end

@implementation NSURL (XP_Compatibility)
+(NSURL *)XP_fileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir;
{
	SEL sel = @selector(fileURLWithPath:isDirectory:);
	if ([NSURL respondsToSelector:sel])
	{
		typedef NSURL* (*MethodPtr)(id, SEL, NSString*, BOOL);
		MethodPtr m = (MethodPtr)[NSURL methodForSelector:sel];
		return m([NSURL class], sel, path, isDir);
	}
	return [NSURL fileURLWithPath:path];
}
+(NSURL *)XP_URLWithString:(NSString *)url;
{
	if (url == nil) return nil;
	return [NSURL URLWithString:url];
}
+(NSURL *)XP_URLWithString:(NSString *)url relativeToURL:(NSURL *)baseURL;
{
	if (url == nil) return nil;
	return [NSURL URLWithString:url relativeToURL:baseURL];
}
-(NSString *)XP_pathExtension;
{
	SEL sel = @selector(pathExtension);
	if ([self respondsToSelector:sel]) {
		return [self performSelector:sel];
	} else {
		return [[self path] pathExtension];
	}
}
@end

@implementation NSString (XP_Compatibility)
-(NSString *)XP_stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement;
{
	return [[self componentsSeparatedByString:target] componentsJoinedByString:replacement];
}
-(NSString *)XP_stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement options:(NSStringCompareOptions)options range:(NSRange)searchRange;
{
	SEL sel = @selector(stringByReplacingOccurrencesOfString:withString:options:range:);
	if ([self respondsToSelector:sel])
	{
		typedef NSString * (*MethodPtr)(id, SEL, NSString *, NSString *, NSStringCompareOptions, NSRange);
		MethodPtr m = (MethodPtr)[self methodForSelector:sel];
		return m(self, sel, target, replacement, options, searchRange);
	}
	NSString * before = [self substringToIndex:searchRange.location];
	NSString * within = [self substringWithRange:searchRange];
	NSString * after  = [self substringFromIndex:searchRange.location + searchRange.length];
	NSString * replaced = [[within componentsSeparatedByString:target] componentsJoinedByString:replacement];
	return [[before stringByAppendingString:replaced] stringByAppendingString:after];
}
@end

@implementation NSNumber (XP_Compatibility)
+(NSNumber *)XP_numberWithInteger:(NSInteger)value;
{
	return [NSNumber numberWithInt:(int)value];
}
+(NSNumber *)XP_numberWithUnsignedInteger:(NSUInteger)value;
{
	return [NSNumber numberWithUnsignedInt:(unsigned int)value];
}
-(NSInteger)XP_integerValue;
{
	return (NSInteger)[self intValue];
}
-(NSUInteger)XP_unsignedIntegerValue;
{
	return (NSUInteger)[self unsignedIntValue];
}
@end

@implementation NSString (XP_IntegerValue)
-(NSInteger)XP_integerValue { return (NSInteger)[self intValue]; }
-(NSUInteger)XP_unsignedIntegerValue { return (NSUInteger)strtoul([self UTF8String], NULL, 10); }
@end

@implementation NSImage (XP_Compatibility)
-(void)XP_drawInRect:(NSRect)dstRect fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op fraction:(CGFloat)delta respectFlipped:(BOOL)flipped hints:(NSDictionary *)hints;
{
	SEL sel = @selector(drawInRect:fromRect:operation:fraction:respectFlipped:hints:);
	if ([self respondsToSelector:sel]) {
		typedef void (*DrawPtr)(id, SEL, NSRect, NSRect, NSCompositingOperation, CGFloat, BOOL, NSDictionary *);
		((DrawPtr)[self methodForSelector:sel])(self, sel, dstRect, srcRect, op, delta, flipped, hints);
	} else {
		[self drawInRect:dstRect fromRect:srcRect operation:op fraction:delta];
	}
}
@end

@implementation NSDate (XP_Compatibility)
-(NSDate *)XP_dateByAddingTimeInterval:(NSTimeInterval)ti;
{
	SEL sel = @selector(dateByAddingTimeInterval:);
	if ([self respondsToSelector:sel]) {
		typedef id (*DatePtr)(id, SEL, NSTimeInterval);
		return ((DatePtr)[self methodForSelector:sel])(self, sel, ti);
	}
	return [self addTimeInterval:ti];
}
@end

@implementation NSDateFormatter (XP_Compatibility)
+(NSString *)XP_localizedStringFromDate:(NSDate *)date dateStyle:(NSDateFormatterStyle)dateStyle timeStyle:(NSDateFormatterStyle)timeStyle;
{
	SEL sel = @selector(localizedStringFromDate:dateStyle:timeStyle:);
	if ([self respondsToSelector:sel]) {
		typedef id (*FmtPtr)(id, SEL, NSDate *, NSDateFormatterStyle, NSDateFormatterStyle);
		return ((FmtPtr)[self methodForSelector:sel])(self, sel, date, dateStyle, timeStyle);
	}
	NSDateFormatter *fmt = [[[NSDateFormatter alloc] init] autorelease];
	[fmt setDateStyle:dateStyle];
	[fmt setTimeStyle:timeStyle];
	return [fmt stringFromDate:date];
}
@end

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1060
@implementation XPViewController

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle {
  (void)nibName; (void)bundle;
  return [super init];
}

- (NSView *)view {
  if (!_view) [self loadView];
  return _view;
}

- (void)setView:(NSView *)view {
  if (_view != view) {
    [_view release];
    _view = [view retain];
  }
}

- (void)loadView {}
- (void)viewWillAppear {}
- (BOOL)commitEditing { return YES; }

- (void)dealloc {
  [_view release];
  _view = nil;
  [super dealloc];
}

@end
#endif

@implementation NSObject (XP_WebOpenPanel)
-(void)XP_chooseFilenames:(NSArray *)filenames {
  SEL plural = @selector(chooseFilenames:);
  if ([self respondsToSelector:plural]) {
    [self performSelector:plural withObject:filenames];
  } else {
    NSString *first = [filenames count] > 0 ? [filenames objectAtIndex:0] : nil;
    if (first) {
      [self performSelector:@selector(chooseFilename:) withObject:first];
    }
  }
}
@end

// ---- NSBezierPath rounded rect polyfill for Tiger (10.4) ----
// bezierPathWithRoundedRect:xRadius:yRadius: is 10.5+ only.
// On Tiger we construct the path manually using 4 straight edges and 4 cubic
// Bézier corner arcs. Each quarter-ellipse is approximated with a single cubic
// segment using the standard control-point offset factor k = 4(√2-1)/3 ≈ 0.5522847498,
// which keeps the curve within 0.03% of a true ellipse. Radii are clamped to half
// the rect dimensions to prevent self-intersection. On 10.5+ the runtime check
// delegates to the real implementation so there is no visual regression on Leopard.
@implementation NSBezierPath (XP_Compatibility)
+(NSBezierPath *)XP_bezierPathWithRoundedRect:(NSRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius {
  SEL sel = @selector(bezierPathWithRoundedRect:xRadius:yRadius:);
  if ([self respondsToSelector:sel]) {
    typedef NSBezierPath *(*FnPtr)(id, SEL, NSRect, CGFloat, CGFloat);
    return ((FnPtr)[self methodForSelector:sel])(self, sel, rect, xRadius, yRadius);
  }
  // Clamp radii to half the rect dimensions
  CGFloat rx = MIN(xRadius, rect.size.width  * 0.5);
  CGFloat ry = MIN(yRadius, rect.size.height * 0.5);
  // Cubic bezier approximation constant for a quarter ellipse
  const CGFloat k = 0.5522847498;
  CGFloat kx = rx * k;
  CGFloat ky = ry * k;
  CGFloat x  = rect.origin.x;
  CGFloat y  = rect.origin.y;
  CGFloat w  = rect.size.width;
  CGFloat h  = rect.size.height;
  NSBezierPath *path = [NSBezierPath bezierPath];
  [path moveToPoint:NSMakePoint(x + rx, y)];
  // bottom edge → bottom-right corner
  [path lineToPoint:NSMakePoint(x + w - rx, y)];
  [path curveToPoint:NSMakePoint(x + w, y + ry)
       controlPoint1:NSMakePoint(x + w - rx + kx, y)
       controlPoint2:NSMakePoint(x + w, y + ry - ky)];
  // right edge → top-right corner
  [path lineToPoint:NSMakePoint(x + w, y + h - ry)];
  [path curveToPoint:NSMakePoint(x + w - rx, y + h)
       controlPoint1:NSMakePoint(x + w, y + h - ry + ky)
       controlPoint2:NSMakePoint(x + w - rx + kx, y + h)];
  // top edge → top-left corner
  [path lineToPoint:NSMakePoint(x + rx, y + h)];
  [path curveToPoint:NSMakePoint(x, y + h - ry)
       controlPoint1:NSMakePoint(x + rx - kx, y + h)
       controlPoint2:NSMakePoint(x, y + h - ry + ky)];
  // left edge → bottom-left corner
  [path lineToPoint:NSMakePoint(x, y + ry)];
  [path curveToPoint:NSMakePoint(x + rx, y)
       controlPoint1:NSMakePoint(x, y + ry - ky)
       controlPoint2:NSMakePoint(x + rx - kx, y)];
  [path closePath];
  return path;
}
@end

@implementation NSThread (XP_Compatibility)
+ (BOOL)XP_isMainThread {
  return pthread_main_np() != 0;
}
@end

// Tiger (10.4): NSObject performSelector:onThread:withObject:waitUntilDone: is 10.5+ only.
// The target thread must have stored [NSRunLoop currentRunLoop] under @"_XPRunLoop"
// in its [[NSThread currentThread] threadDictionary] before the first call.
@implementation NSObject (XP_ThreadPerform)
-(void)XP_performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)wait;
{
  SEL nat = @selector(performSelector:onThread:withObject:waitUntilDone:);
  if ([self respondsToSelector:nat]) {
    typedef void (*Fn)(id, SEL, SEL, NSThread *, id, BOOL);
    ((Fn)[self methodForSelector:nat])(self, nat, aSelector, thr, arg, wait);
    return;
  }
  // Tiger (10.4) fallback: use NSRunLoop dispatch.
  NSRunLoop *rl = [[thr threadDictionary] objectForKey:@"_XPRunLoop"];
  if (!rl) {
    [self performSelectorOnMainThread:aSelector withObject:arg waitUntilDone:wait];
    return;
  }
  [rl performSelector:aSelector target:self argument:arg order:0
                modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
  CFRunLoopWakeUp([rl getCFRunLoop]);
}
-(void)XP_performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)wait modes:(NSArray *)array;
{
  [self XP_performSelector:aSelector onThread:thr withObject:arg waitUntilDone:wait];
}
@end
