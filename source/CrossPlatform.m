#import "Vienna_Prefix.pch"
#import "CrossPlatform.h"

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
@end

@implementation NSString (XP_Compatibility)
-(NSString *)XP_stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement;
{
	return [[self componentsSeparatedByString:target] componentsJoinedByString:replacement];
}
@end
