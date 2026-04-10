//
//  CrossPlatform.h
//  Vienna
//
//  Created for Altivec Intelligence Cross-Compile Environment
//

#import <Cocoa/Cocoa.h>

BOOL createRecursiveDirectory(NSString * path);

@interface NSCell (XP_Compatibility)
-(void)XP_setBackgroundStyle:(NSInteger)style;
@end

@interface NSFileManager (XP_Compatibility)
-(BOOL)XP_createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error;
@end

@interface NSURL (XP_Compatibility)
+(NSURL *)XP_fileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir;
+(NSURL *)XP_URLWithString:(NSString *)url;
+(NSURL *)XP_URLWithString:(NSString *)url relativeToURL:(NSURL *)baseURL;
@end

@interface NSString (XP_Compatibility)
-(NSString *)XP_stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement;
@end
