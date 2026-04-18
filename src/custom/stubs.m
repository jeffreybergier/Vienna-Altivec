#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "stubs.h"

// ---- Runtime-version-safe method injection ----
// class_addMethod is 10.5+ only. On Tiger we use class_addMethods (old runtime API)
// with a manual respondsToSelector: guard to replicate the "only add if missing" semantics.

// Mirrors the Tiger-era struct objc_method / objc_method_list layout (i386 + ppc, 32-bit).
struct xp_method_t      { SEL name; char *types; IMP imp; };
struct xp_method_list_t { void *obsolete; int count; struct xp_method_t entries[1]; };

static BOOL xp_add_method(Class cls, SEL sel, IMP imp, const char *types) {
  typedef BOOL (*modern_fn_t)(Class, SEL, IMP, const char *);
  static modern_fn_t modern_fn;
  static BOOL modern_checked;
  if (!modern_checked) {
    modern_fn = (modern_fn_t)dlsym(RTLD_DEFAULT, "class_addMethod");
    modern_checked = YES;
  }
  if (modern_fn)
    return modern_fn(cls, sel, imp, types);

  // Tiger: class_addMethods does not check for existing methods, so guard manually.
  if (class_getInstanceMethod(cls, sel)) return NO;
  typedef void (*legacy_fn_t)(Class, struct xp_method_list_t *);
  static legacy_fn_t legacy_fn;
  static BOOL legacy_checked;
  if (!legacy_checked) {
    legacy_fn = (legacy_fn_t)dlsym(RTLD_DEFAULT, "class_addMethods");
    legacy_checked = YES;
  }
  if (!legacy_fn) return NO;
  // Heap-allocate: the runtime stores a pointer to this list directly (does not copy it).
  struct xp_method_list_t *list = calloc(1, sizeof(struct xp_method_list_t));
  list->count = 1;
  list->entries[0].name  = sel;
  list->entries[0].types = (char *)types;
  list->entries[0].imp   = imp;
  legacy_fn(cls, list);
  return YES;
}

// ---- Fast enumeration polyfill implementations ----
// These only run on Tiger where allKeys/allObjects don't recurse into fast enumeration.

static NSUInteger xp_array_enumerate(id self, SEL _cmd, NSFastEnumerationState *state, id *stackbuf, NSUInteger len) {
  NSUInteger idx = state->state;
  NSUInteger total = (NSUInteger)[(NSArray *)self count];
  if (idx == 0)
    state->mutationsPtr = &state->extra[0];
  NSUInteger cnt = 0;
  while (idx < total && cnt < len)
    stackbuf[cnt++] = [(NSArray *)self objectAtIndex:idx++];
  state->state = idx;
  state->itemsPtr = stackbuf;
  return cnt;
}

static NSUInteger xp_set_enumerate(id self, SEL _cmd, NSFastEnumerationState *state, id *stackbuf, NSUInteger len) {
  NSArray *arr = (state->state == 0) ? [[[(NSSet *)self allObjects] retain] autorelease] : nil;
  if (arr) {
    state->extra[0] = (unsigned long)arr;
    state->mutationsPtr = &state->extra[1];
  } else {
    arr = (NSArray *)(void *)state->extra[0];
  }
  NSUInteger idx = state->state & 0xFFFF;
  NSUInteger total = (NSUInteger)[arr count];
  NSUInteger cnt = 0;
  while (idx < total && cnt < len)
    stackbuf[cnt++] = [arr objectAtIndex:idx++];
  state->state = (state->state & ~0xFFFF) | idx;
  state->itemsPtr = stackbuf;
  return cnt;
}

static NSUInteger xp_dict_enumerate(id self, SEL _cmd, NSFastEnumerationState *state, id *stackbuf, NSUInteger len) {
  NSArray *keys = (state->state == 0) ? [[[(NSDictionary *)self allKeys] retain] autorelease] : nil;
  if (keys) {
    state->extra[0] = (unsigned long)keys;
    state->mutationsPtr = &state->extra[1];
  } else {
    keys = (NSArray *)(void *)state->extra[0];
  }
  NSUInteger idx = state->state & 0xFFFF;
  NSUInteger total = (NSUInteger)[keys count];
  NSUInteger cnt = 0;
  while (idx < total && cnt < len)
    stackbuf[cnt++] = [keys objectAtIndex:idx++];
  state->state = (state->state & ~0xFFFF) | idx;
  state->itemsPtr = stackbuf;
  return cnt;
}

static NSUInteger xp_enumerator_enumerate(id self, SEL _cmd, NSFastEnumerationState *state, id *stackbuf, NSUInteger len) {
  if (state->state == 0)
    state->mutationsPtr = &state->extra[0];
  NSUInteger cnt = 0;
  id obj;
  while (cnt < len && (obj = [(NSEnumerator *)self nextObject]) != nil)
    stackbuf[cnt++] = obj;
  state->state = 1;
  state->itemsPtr = stackbuf;
  return cnt;
}

@implementation XPFastEnumerationInstaller
+ (void)load {
  SEL sel = @selector(countByEnumeratingWithState:objects:count:);
  const char *enc = "I@:^v^@I";
  BOOL patched = NO;
  patched |= xp_add_method([NSArray class],      sel, (IMP)xp_array_enumerate,      enc);
  patched |= xp_add_method([NSSet class],        sel, (IMP)xp_set_enumerate,        enc);
  patched |= xp_add_method([NSDictionary class], sel, (IMP)xp_dict_enumerate,       enc);
  patched |= xp_add_method([NSEnumerator class], sel, (IMP)xp_enumerator_enumerate, enc);
  NSLog(@"[Stubs.Fast Enumeration] %@", (patched) ? @"patched" : @"NOT patched");
}
@end

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
