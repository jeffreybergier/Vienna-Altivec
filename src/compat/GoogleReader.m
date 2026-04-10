//
//  GoogleReader.m
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011-2014 Vienna contributors (see Help/Acknowledgements for list of contributors). All rights reserved.
//
//  Ported to Tiger (10.4) / MRC / AICURLConnection by the Altivec project.
//  Changes from v3.0.0 original:
//    - Removed ASIHTTPRequest/ASIFormDataRequest -> AICURLConnection
//    - Removed GCD (dispatch_async/dispatch_queue_t) -> inline execution
//    - Removed fast enumeration -> NSEnumerator
//    - Removed doTransactionWithBlock: -> beginTransaction/commitTransaction
//    - Removed @property -> manual ivars and accessors
//    - Removed JSONKit JSONDecoder (thread-unsafe) -> per-call objectFromJSONData
//    - Removed postNotificationOnMainThreadWithName -> performSelectorOnMainThread
//

#import "GoogleReader.h"
#import "AICURLConnection.h"
#import "JSONKit.h"
#import "Folder.h"
#import "Database.h"
#import "Message.h"
#import "AppController.h"
#import "RefreshManager.h"
#import "Preferences.h"
#import "StringExtensions.h"
#import "KeyChain.h"

#define TIMESTAMP [NSString stringWithFormat:@"%0.0f", [[NSDate date] timeIntervalSince1970]]

static NSString * LoginBaseURL = @"https://%@/accounts/ClientLogin?accountType=GOOGLE&service=reader";
static NSString * ClientName = @"ViennaRSS";

// Host-specific variables
static NSString * openReaderHost = nil;
static NSString * grUsername = nil;
static NSString * grPassword = nil;
static NSString * APIBaseURL = nil;
static BOOL hostSupportsLongId = NO;
static BOOL hostRequiresSParameter = NO;
static BOOL hostRequiresLastPathOnly = NO;

// Singleton instance
static GoogleReader * _googleReader = nil;

typedef enum {
    notAuthenticated = 0,
    isAuthenticating,
    isAuthenticated
} GoogleReaderStatus;

static GoogleReaderStatus googleReaderStatus = notAuthenticated;

// ---------------------------------------------------------------------------
// GRRequest - lightweight async context object (replaces ASIHTTPRequest role)
// ---------------------------------------------------------------------------
@interface GRRequest : NSObject {
@public
    id _target;
    SEL _finishSelector;
    SEL _failSelector;
    NSDictionary * _userInfo;
    NSMutableData * _data;
    NSURLResponse * _response;
    NSError * _error;
    NSURL * _originalURL;
    AICURLConnection * _connection;
}
+(GRRequest *)requestWithURL:(NSURL *)url
                      target:(id)target
              finishSelector:(SEL)finish
                failSelector:(SEL)fail
                    userInfo:(NSDictionary *)info;

-(void)start;
-(void)cancel;

-(NSData *)responseData;
-(NSString *)responseString;
-(NSInteger)responseStatusCode;
-(NSDictionary *)userInfo;
-(NSURL *)originalURL;
-(NSError *)error;
@end

// NSURLConnectionDelegate doesn't exist as a formal protocol on 10.4 — no declaration needed

@implementation GRRequest

+(GRRequest *)requestWithURL:(NSURL *)url
                      target:(id)target
              finishSelector:(SEL)finish
                failSelector:(SEL)fail
                    userInfo:(NSDictionary *)info
{
    GRRequest * r = [[[GRRequest alloc] init] autorelease];
    r->_target = target;
    r->_finishSelector = finish;
    r->_failSelector = fail;
    r->_userInfo = [info retain];
    r->_data = [[NSMutableData alloc] init];
    r->_originalURL = [url retain];

    NSMutableURLRequest * req = [NSMutableURLRequest requestWithURL:url
                                                        cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                    timeoutInterval:180.0];
    [req setHTTPMethod:@"GET"];
    r->_connection = [[AICURLConnection alloc] initWithRequest:req
                                                      delegate:r
                                              startImmediately:NO];
    return r;
}


-(void)start
{
    [_connection start];
}

-(void)cancel
{
    [_connection cancel];
}

-(NSData *)responseData  { return _data; }
-(NSString *)responseString { return [[[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding] autorelease]; }
-(NSInteger)responseStatusCode { return _response ? [(NSHTTPURLResponse *)_response statusCode] : 0; }
-(NSDictionary *)userInfo { return _userInfo; }
-(NSURL *)originalURL { return _originalURL; }
-(NSError *)error { return _error; }

// NSURLConnection delegate
-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [_response release];
    _response = [response retain];
    [_data setLength:0];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_data appendData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (_target && _finishSelector)
        [_target performSelector:_finishSelector withObject:self];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [_error release];
    _error = [error retain];
    if (_target && _failSelector)
        [_target performSelector:_failSelector withObject:self];
    else if (_target && _finishSelector) // fallback: let finish handler check error
        [_target performSelector:_finishSelector withObject:self];
}

-(void)dealloc
{
    [_userInfo release];
    [_data release];
    [_response release];
    [_error release];
    [_originalURL release];
    [_connection release];
    [super dealloc];
}

@end

// ---------------------------------------------------------------------------
// Helpers for building URL-encoded POST bodies
// ---------------------------------------------------------------------------
static NSString * urlEncode(NSString *s)
{
    if (!s) return @"";
    NSString * encoded = (NSString *)CFURLCreateStringByAddingPercentEscapes(
        NULL,
        (CFStringRef)s,
        NULL,
        (CFStringRef)@"!*'();:@&=+$,/?%#[]",
        kCFStringEncodingUTF8);
    return [encoded autorelease];
}

static NSMutableURLRequest * makeGETRequest(NSURL *url, NSString *authToken)
{
    NSMutableURLRequest * req = [NSMutableURLRequest requestWithURL:url
                                                        cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                    timeoutInterval:180.0];
    if (authToken)
        [req setValue:[NSString stringWithFormat:@"GoogleLogin auth=%@", authToken]
   forHTTPHeaderField:@"Authorization"];
    return req;
}

static NSMutableURLRequest * makePOSTRequest(NSURL *url, NSString *body, NSString *authToken)
{
    NSMutableURLRequest * req = [NSMutableURLRequest requestWithURL:url
                                                        cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                    timeoutInterval:180.0];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    if (authToken)
        [req setValue:[NSString stringWithFormat:@"GoogleLogin auth=%@", authToken]
   forHTTPHeaderField:@"Authorization"];
    if (body)
        [req setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    return req;
}

// ---------------------------------------------------------------------------
// GoogleReader implementation
// ---------------------------------------------------------------------------
@interface GoogleReader ()
-(NSString *)token;
-(void)setToken:(NSString *)t;
-(NSString *)clientAuthToken;
-(void)setClientAuthToken:(NSString *)t;
-(NSMutableArray *)localFeeds;
-(void)submitLoadSubscriptions;
-(void)createNewSubscription:(NSArray *)params;
-(void)createFolders:(NSMutableArray *)params;
-(void)startGRRequest:(NSURL *)url withTarget:(id)target finishSelector:(SEL)finish failSelector:(SEL)fail userInfo:(NSDictionary *)info;
-(void)notifyArticleCountUpdate;
@end

@implementation GoogleReader

-(NSString *)token { return _token; }
-(void)setToken:(NSString *)t { if (t != _token) { [_token release]; _token = [t copy]; } }
-(NSString *)clientAuthToken { return _clientAuthToken; }
-(void)setClientAuthToken:(NSString *)t { if (t != _clientAuthToken) { [_clientAuthToken release]; _clientAuthToken = [t copy]; } }
-(NSMutableArray *)localFeeds { return _localFeeds; }

-(BOOL)isReady
{
    return (googleReaderStatus == isAuthenticated && tokenTimer != nil);
}

-(NSUInteger)countOfNewArticles
{
    NSUInteger count = countOfNewArticles;
    countOfNewArticles = 0;
    return count;
}

-(id)init
{
    self = [super init];
    if (self) {
        _localFeeds = [[NSMutableArray alloc] init];
        googleReaderStatus = notAuthenticated;
        countOfNewArticles = 0;
        _clientAuthToken = nil;
        _token = nil;
        tokenTimer = nil;
        authTimer = nil;
    }
    return self;
}

+(GoogleReader *)sharedManager
{
    if (!_googleReader)
        _googleReader = [[GoogleReader alloc] init];
    return _googleReader;
}

// ---------------------------------------------------------------------------
#pragma mark Authentication
// ---------------------------------------------------------------------------

-(void)authenticate
{
    Preferences * prefs = [Preferences standardPreferences];
    if (![prefs syncGoogleReader])
        return;
    if (googleReaderStatus != notAuthenticated) {
        NSLog(@"[GR] Another instance is authenticating...");
        return;
    }
    NSLog(@"[GR] Start first authentication...");
    googleReaderStatus = isAuthenticating;
    [(AppController *)[NSApp delegate] setStatusMessage:NSLocalizedString(@"Authenticating on Open Reader", nil) persist:NO];

    [grUsername release];
    grUsername = [[prefs syncingUser] retain];
    [openReaderHost release];
    openReaderHost = [[prefs syncServer] retain];

    // Server-specific flags
    hostSupportsLongId = NO;
    hostRequiresSParameter = NO;
    hostRequiresLastPathOnly = NO;
    if ([openReaderHost isEqualToString:@"theoldreader.com"]) {
        hostSupportsLongId = YES;
        hostRequiresSParameter = YES;
        hostRequiresLastPathOnly = YES;
    }

    [grPassword release];
    grPassword = [[KeyChain getPasswordFromKeychain:grUsername url:openReaderHost] retain];
    [APIBaseURL release];
    APIBaseURL = [[NSString stringWithFormat:@"https://%@/reader/api/0/", openReaderHost] retain];

    // Synchronous POST to ClientLogin
    NSURL * loginURL = [NSURL URLWithString:[NSString stringWithFormat:LoginBaseURL, openReaderHost]];
    NSString * loginBody = [NSString stringWithFormat:@"Email=%@&Passwd=%@",
                            urlEncode(grUsername), urlEncode(grPassword)];
    NSMutableURLRequest * req = makePOSTRequest(loginURL, loginBody, nil);

    NSHTTPURLResponse * httpResp = nil;
    NSError * err = nil;
    NSData * responseData = [AICURLConnection sendSynchronousRequest:req
                                                  returningResponse:(NSURLResponse **)&httpResp
                                                              error:&err];

    if (!responseData || [httpResp statusCode] != 200) {
        NSLog(@"[GR] Auth failed, status=%ld err=%@", (long)[httpResp statusCode], err);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_GoogleAuthFailed" object:nil];
        [(AppController *)[NSApp delegate] setStatusMessage:nil persist:NO];
        googleReaderStatus = notAuthenticated;
        return;
    }

    NSString * response = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
    NSArray * components = [response componentsSeparatedByString:@"\n"];
    // Line 0: SID=..., Line 1: LSID=..., Line 2: Auth=...
    if ([components count] < 3) {
        NSLog(@"[GR] Unexpected auth response: %@", response);
        googleReaderStatus = notAuthenticated;
        return;
    }
    [self setClientAuthToken:[[components objectAtIndex:2] substringFromIndex:5]];

    [self getToken];

    if (authTimer == nil || ![authTimer isValid])
        authTimer = [NSTimer scheduledTimerWithTimeInterval:6*24*3600
                                                     target:self
                                                   selector:@selector(resetAuthentication)
                                                   userInfo:nil
                                                    repeats:YES];
}

-(void)getToken
{
    NSLog(@"[GR] Getting action token...");
    NSURL * tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@token", APIBaseURL]];
    NSMutableURLRequest * req = makeGETRequest(tokenURL, _clientAuthToken);

    googleReaderStatus = isAuthenticating;

    NSHTTPURLResponse * httpResp = nil;
    NSError * err = nil;
    NSData * data = [AICURLConnection sendSynchronousRequest:req
                                          returningResponse:(NSURLResponse **)&httpResp
                                                      error:&err];

    if (err || !data) {
        NSLog(@"[GR] Token request failed: %@", err);
        [self resetAuthentication];
        return;
    }

    NSString * tokenStr = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    [self setToken:tokenStr];
    googleReaderStatus = isAuthenticated;

    if (tokenTimer == nil || ![tokenTimer isValid])
        tokenTimer = [NSTimer scheduledTimerWithTimeInterval:25*60
                                                      target:self
                                                    selector:@selector(getToken)
                                                    userInfo:nil
                                                     repeats:YES];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_Autheticated" object:nil];
}

-(void)clearAuthentication
{
    googleReaderStatus = notAuthenticated;
    [self setClientAuthToken:nil];
    [self setToken:nil];
}

-(void)resetAuthentication
{
    [self clearAuthentication];
    [self authenticate];
}

// ---------------------------------------------------------------------------
#pragma mark Feed refresh
// ---------------------------------------------------------------------------

-(void)refreshFeed:(Folder *)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit
{
    NSString * folderLastUpdateString = ignoreLimit ? @"0" : [thisFolder lastUpdateString];
    if ([folderLastUpdateString isEqualToString:@""] || [folderLastUpdateString isEqualToString:@"(null)"])
        folderLastUpdateString = @"0";

    NSString * itemsLimitation;
    if (ignoreLimit)
        itemsLimitation = @"&n=10000";
    else
        itemsLimitation = [NSString stringWithFormat:@"&ot=%@&n=500", folderLastUpdateString];

    if (![self isReady])
        [self authenticate];

    NSString * feedIdentifier = hostRequiresLastPathOnly ? [[thisFolder feedURL] lastPathComponent] : [thisFolder feedURL];

    NSURL * refreshURL = [NSURL URLWithString:[NSString stringWithFormat:
        @"%@stream/contents/feed/%@?client=%@&comments=false&likes=false%@&ck=%@&output=json",
        APIBaseURL, percentEscape(feedIdentifier), ClientName, itemsLimitation, TIMESTAMP]];

    NSDictionary * userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                thisFolder, @"folder",
                                aItem, @"log",
                                folderLastUpdateString, @"lastupdatestring",
                                nil];
    [self startGRRequest:refreshURL
              withTarget:self
          finishSelector:@selector(feedRequestDone:)
            failSelector:@selector(feedRequestFailed:)
                userInfo:userInfo];
}

// callback
-(void)feedRequestFailed:(GRRequest *)request
{
    ActivityItem * aItem = [[request userInfo] objectForKey:@"log"];
    Folder * refreshedFolder = [[request userInfo] objectForKey:@"folder"];
    [aItem appendDetail:[NSString stringWithFormat:@"%@ %@",
                          NSLocalizedString(@"Error", nil),
                          [[request error] localizedDescription]]];
    [aItem setStatus:NSLocalizedString(@"Error", nil)];
    [refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
    [refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
}

// callback
-(void)feedRequestDone:(GRRequest *)request
{
    ActivityItem * aItem = [[request userInfo] objectForKey:@"log"];
    Folder * refreshedFolder = [[request userInfo] objectForKey:@"folder"];
    NSLog(@"[GR] Feed refresh done: %@", [refreshedFolder feedURL]);

    if ([request responseStatusCode] == 404) {
        [aItem appendDetail:NSLocalizedString(@"Error: Feed not found!", nil)];
        [aItem setStatus:NSLocalizedString(@"Error", nil)];
        [refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
        [refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
        return;
    }

    if ([request responseStatusCode] != 200) {
        [aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"HTTP code %d reported from server", nil),
                              [request responseStatusCode]]];
        [aItem setStatus:NSLocalizedString(@"Error", nil)];
        [refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
        [refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
        return;
    }

    NSData * data = [request responseData];
    NSDictionary * dict = [[data objectFromJSONData] retain];
    if (!dict) {
        NSLog(@"[GR] JSON parse failed for feed %@", [refreshedFolder feedURL]);
        [refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
        [refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
        return;
    }

    NSString * folderLastUpdateString = [[dict objectForKey:@"updated"] stringValue];
    if (!folderLastUpdateString || [folderLastUpdateString isEqualToString:@""] ||
        [folderLastUpdateString isEqualToString:@"(null)"])
        folderLastUpdateString = [[request userInfo] objectForKey:@"lastupdatestring"];

    [aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"%ld bytes received", nil), (long)[data length]]];
    NSLog(@"[GR] %lu items returned from %@", (unsigned long)[[dict objectForKey:@"items"] count], [request originalURL]);

    NSMutableArray * articleArray = [NSMutableArray array];
    NSArray * items = [dict objectForKey:@"items"];
    NSEnumerator * itemEnum = [items objectEnumerator];
    NSDictionary * newsItem;
    while ((newsItem = [itemEnum nextObject]) != nil) {
        NSDate * articleDate = [NSDate dateWithTimeIntervalSince1970:[[newsItem objectForKey:@"published"] doubleValue]];
        NSString * articleGuid = [newsItem objectForKey:@"id"];
        Article * article = [[[Article alloc] initWithGuid:articleGuid] autorelease];
        [article setFolderId:[refreshedFolder itemId]];

        if ([newsItem objectForKey:@"author"] != nil)
            [article setAuthor:[newsItem objectForKey:@"author"]];
        else
            [article setAuthor:@""];

        if ([newsItem objectForKey:@"content"] != nil)
            [article setBody:[[newsItem objectForKey:@"content"] objectForKey:@"content"]];
        else if ([newsItem objectForKey:@"summary"] != nil)
            [article setBody:[[newsItem objectForKey:@"summary"] objectForKey:@"content"]];
        else
            [article setBody:@"Not available..."];

        NSArray * categories = [newsItem objectForKey:@"categories"];
        NSEnumerator * catEnum = [categories objectEnumerator];
        NSString * category;
        while ((category = [catEnum nextObject]) != nil) {
            if ([category hasSuffix:@"/read"]) [article markRead:YES];
            if ([category hasSuffix:@"/starred"]) [article markFlagged:YES];
            if ([category hasSuffix:@"/kept-unread"]) [article markRead:NO];
        }

        if ([newsItem objectForKey:@"title"] != nil)
            [article setTitle:[[newsItem objectForKey:@"title"] summaryTextFromHTML]];
        else
            [article setTitle:@""];

        NSArray * alternates = [newsItem objectForKey:@"alternate"];
        if ([alternates count] != 0)
            [article setLink:[[alternates objectAtIndex:0] objectForKey:@"href"]];
        else
            [article setLink:[refreshedFolder feedURL]];

        [article setDate:articleDate];

        NSArray * enclosures = [newsItem objectForKey:@"enclosure"];
        if ([enclosures count] != 0)
            [article setEnclosure:[[enclosures objectAtIndex:0] objectForKey:@"href"]];
        else
            [article setEnclosure:@""];

        if (![[article enclosure] isEqualToString:@""])
            [article setHasEnclosure:YES];

        [articleArray addObject:article];
    }

    // Write articles to database
    Database * db = [Database sharedDatabase];
    NSInteger newArticlesFromFeed = 0;

    if ([articleArray count] > 0) {
        [db beginTransaction];
        NSArray * guidHistory = [db guidHistoryForFolderId:[refreshedFolder itemId]];
        [refreshedFolder clearCache];

        NSEnumerator * artEnum = [articleArray objectEnumerator];
        Article * article;
        while ((article = [artEnum nextObject]) != nil) {
            if ([db createArticle:[refreshedFolder itemId] article:article guidHistory:guidHistory] &&
                ([article status] == MA_MsgStatus_New))
                newArticlesFromFeed++;
        }

        [db setFolderLastUpdate:[refreshedFolder itemId] lastUpdate:[NSDate date]];
        [db commitTransaction];
    }

    if ([folderLastUpdateString isEqualToString:@""] || [folderLastUpdateString isEqualToString:@"(null)"])
        folderLastUpdateString = @"0";

    [db beginTransaction];
    [db setFolderLastUpdateString:[refreshedFolder itemId] lastUpdateString:folderLastUpdateString];
    id alternate = [dict objectForKey:@"alternate"];
    if ([alternate isKindOfClass:[NSArray class]])
        [db setFolderHomePage:[refreshedFolder itemId]
                  newHomePage:[[alternate objectAtIndex:0] objectForKey:@"href"]];
    else if ([alternate isKindOfClass:[NSDictionary class]])
        [db setFolderHomePage:[refreshedFolder itemId]
                  newHomePage:[alternate objectForKey:@"href"]];
    [db commitTransaction];

    countOfNewArticles += newArticlesFromFeed;

    [dict release];

    // Update UI on main thread
    [(AppController *)[NSApp delegate] performSelectorOnMainThread:@selector(setStatusMessage:) withObject:nil waitUntilDone:NO];
    [(AppController *)[NSApp delegate] performSelectorOnMainThread:@selector(showUnreadCountOnApplicationIconAndWindowTitle) withObject:nil waitUntilDone:NO];
    [refreshedFolder clearNonPersistedFlag:MA_FFlag_Error];

    if (newArticlesFromFeed == 0)
        [aItem setStatus:NSLocalizedString(@"No new articles available", nil)];
    else {
        [aItem setStatus:[NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), (int)newArticlesFromFeed]];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListStateChange" object:refreshedFolder];
    }

    // Chain: request unread IDs
    NSString * feedIdentifier = hostRequiresLastPathOnly ? [[refreshedFolder feedURL] lastPathComponent] : [refreshedFolder feedURL];

    NSString * unreadArgs = [NSString stringWithFormat:
        @"?ck=%@&client=%@&s=feed/%@&xt=user/-/state/com.google/read&n=1000&output=json",
        TIMESTAMP, ClientName, percentEscape(feedIdentifier)];
    NSURL * unreadURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stream/items/ids%@", APIBaseURL, unreadArgs]];
    NSDictionary * readInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                refreshedFolder, @"folder",
                                aItem, @"log", nil];
    [self startGRRequest:unreadURL
              withTarget:self
          finishSelector:@selector(readRequestDone:)
            failSelector:@selector(readRequestFailed:)
                userInfo:readInfo];

    // Chain: request starred IDs
    NSString * starredSelector = hostRequiresSParameter ?
        @"s=user/-/state/com.google/starred" :
        @"it=user/-/state/com.google/starred";
    NSString * starredArgs = [NSString stringWithFormat:
        @"?ck=%@&client=%@&s=feed/%@&%@&n=1000&output=json",
        TIMESTAMP, ClientName, percentEscape(feedIdentifier), starredSelector];
    NSURL * starredURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stream/items/ids%@", APIBaseURL, starredArgs]];
    [self startGRRequest:starredURL
              withTarget:self
          finishSelector:@selector(starredRequestDone:)
            failSelector:@selector(starredRequestFailed:)
                userInfo:readInfo];
}

// Convenience to fire an authenticated async GET
-(void)startGRRequest:(NSURL *)url
           withTarget:(id)target
       finishSelector:(SEL)finish
         failSelector:(SEL)fail
             userInfo:(NSDictionary *)info
{
    GRRequest * r = [[[GRRequest alloc] init] autorelease];
    r->_target = target;
    r->_finishSelector = finish;
    r->_failSelector = fail;
    r->_userInfo = [info retain];
    r->_data = [[NSMutableData alloc] init];
    r->_originalURL = [url retain];

    NSMutableURLRequest * req = [NSMutableURLRequest requestWithURL:url
                                                        cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                    timeoutInterval:180.0];
    [req setValue:[NSString stringWithFormat:@"GoogleLogin auth=%@", _clientAuthToken]
forHTTPHeaderField:@"Authorization"];
    r->_connection = [[AICURLConnection alloc] initWithRequest:req
                                                      delegate:r
                                              startImmediately:NO];
    [r start];
}

// callback
-(void)readRequestFailed:(GRRequest *)request
{
    ActivityItem * aItem = [[request userInfo] objectForKey:@"log"];
    Folder * refreshedFolder = [[request userInfo] objectForKey:@"folder"];
    [aItem appendDetail:[NSString stringWithFormat:@"%@ %@",
                          NSLocalizedString(@"Error", nil),
                          [[request error] localizedDescription]]];
    [aItem setStatus:NSLocalizedString(@"Error", nil)];
    [refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
    [refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
}

// callback
-(void)readRequestDone:(GRRequest *)request
{
    Folder * refreshedFolder = [[request userInfo] objectForKey:@"folder"];
    ActivityItem * aItem = [[request userInfo] objectForKey:@"log"];

    if ([request responseStatusCode] != 200) {
        [aItem appendDetail:[NSString stringWithFormat:@"%@ HTTP %d",
                              NSLocalizedString(@"Error", nil),
                              (int)[request responseStatusCode]]];
        [aItem setStatus:NSLocalizedString(@"Error", nil)];
        [refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
        [refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
        return;
    }

    NSDictionary * dict = [[request responseData] objectFromJSONData];
    NSArray * itemRefs = [dict objectForKey:@"itemRefs"];
    if (!itemRefs) {
        [refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
        return;
    }

    NSMutableArray * guidArray = [NSMutableArray arrayWithCapacity:[itemRefs count]];
    NSEnumerator * e = [itemRefs objectEnumerator];
    NSDictionary * itemRef;
    while ((itemRef = [e nextObject]) != nil) {
        NSString * guid;
        if (hostSupportsLongId) {
            guid = [NSString stringWithFormat:@"tag:google.com,2005:reader/item/%@", [itemRef objectForKey:@"id"]];
        } else {
            NSInteger shortId = [[itemRef objectForKey:@"id"] integerValue];
            guid = [NSString stringWithFormat:@"tag:google.com,2005:reader/item/%016qx", (long long)shortId];
        }
        [guidArray addObject:guid];
    }

    NSLog(@"[GR] %lu unread items for %@", (unsigned long)[guidArray count], [request originalURL]);
    Database * db = [Database sharedDatabase];
    [db beginTransaction];
    [db markUnreadArticlesFromFolder:refreshedFolder guidArray:guidArray];
    [db commitTransaction];

    // Favicon refresh is handled by RefreshManager internally during its own refresh cycle.
}

// callback
-(void)starredRequestFailed:(GRRequest *)request
{
    ActivityItem * aItem = [[request userInfo] objectForKey:@"log"];
    Folder * refreshedFolder = [[request userInfo] objectForKey:@"folder"];
    [aItem appendDetail:[NSString stringWithFormat:@"%@ %@",
                          NSLocalizedString(@"Error", nil),
                          [[request error] localizedDescription]]];
    [aItem setStatus:NSLocalizedString(@"Error", nil)];
    [refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
    [refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
}

// callback
-(void)starredRequestDone:(GRRequest *)request
{
    Folder * refreshedFolder = [[request userInfo] objectForKey:@"folder"];
    ActivityItem * aItem = [[request userInfo] objectForKey:@"log"];

    if ([request responseStatusCode] != 200) {
        [aItem appendDetail:[NSString stringWithFormat:@"%@ HTTP %d",
                              NSLocalizedString(@"Error", nil),
                              (int)[request responseStatusCode]]];
        [aItem setStatus:NSLocalizedString(@"Error", nil)];
        [refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
        [refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated"
                                                            object:[NSNumber numberWithInt:[refreshedFolder itemId]]];
        return;
    }

    NSDictionary * dict = [[request responseData] objectFromJSONData];
    NSArray * itemRefs = [dict objectForKey:@"itemRefs"];

    NSMutableArray * guidArray = [NSMutableArray array];
    if (itemRefs) {
        NSEnumerator * e = [itemRefs objectEnumerator];
        NSDictionary * itemRef;
        while ((itemRef = [e nextObject]) != nil) {
            NSString * guid;
            if (hostSupportsLongId) {
                guid = [NSString stringWithFormat:@"tag:google.com,2005:reader/item/%@", [itemRef objectForKey:@"id"]];
            } else {
                NSInteger shortId = [[itemRef objectForKey:@"id"] integerValue];
                guid = [NSString stringWithFormat:@"tag:google.com,2005:reader/item/%016qx", (long long)shortId];
            }
            [guidArray addObject:guid];
        }
    }

    NSLog(@"[GR] %lu starred items for %@", (unsigned long)[guidArray count], [request originalURL]);
    Database * db = [Database sharedDatabase];
    [db beginTransaction];
    [db markStarredArticlesFromFolder:refreshedFolder guidArray:guidArray];
    [db commitTransaction];

    [refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated"
                                                        object:[NSNumber numberWithInt:[refreshedFolder itemId]]];
}

// ---------------------------------------------------------------------------
#pragma mark Subscription management
// ---------------------------------------------------------------------------

-(void)loadSubscriptions:(NSNotification *)nc
{
    if (nc != nil) {
        NSLog(@"[GR] Firing after GRSync_Autheticated notification");
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:@"GRSync_Autheticated"
                                                      object:nil];
        [self submitLoadSubscriptions];
    } else {
        if ([self isReady]) {
            [self submitLoadSubscriptions];
        } else {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(loadSubscriptions:)
                                                         name:@"GRSync_Autheticated"
                                                       object:nil];
            [self authenticate];
        }
    }
}

-(void)submitLoadSubscriptions
{
    [(AppController *)[NSApp delegate] setStatusMessage:NSLocalizedString(@"Fetching Open Reader Subscriptions...", nil) persist:NO];
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/list?client=%@&output=json",
                                         APIBaseURL, ClientName]];
    [self startGRRequest:url
              withTarget:self
          finishSelector:@selector(subscriptionsRequestDone:)
            failSelector:@selector(subscriptionsRequestFailed:)
                userInfo:nil];
}

-(void)subscriptionsRequestFailed:(GRRequest *)request
{
    NSLog(@"[GR] Subscription list request failed: %@", [[request error] localizedDescription]);
    [(AppController *)[NSApp delegate] setStatusMessage:nil persist:NO];
}

-(void)subscriptionsRequestDone:(GRRequest *)request
{
    NSLog(@"[GR] Subscription list received");
    NSDictionary * dict = [[request responseData] objectFromJSONData];

    [_localFeeds removeAllObjects];
    NSArray * localFolders = [(AppController *)[NSApp delegate] folders];
    NSEnumerator * lfe = [localFolders objectEnumerator];
    Folder * lf;
    while ((lf = [lfe nextObject]) != nil) {
        if ([lf feedURL])
            [_localFeeds addObject:[lf feedURL]];
    }

    NSMutableArray * googleFeeds = [[NSMutableArray alloc] init];

    NSArray * subscriptions = [dict objectForKey:@"subscriptions"];
    NSEnumerator * subEnum = [subscriptions objectEnumerator];
    NSDictionary * feed;
    while ((feed = [subEnum nextObject]) != nil) {
        NSString * feedID = [feed objectForKey:@"id"];
        if (feedID == nil) break;

        NSString * feedURL = [feedID stringByReplacingOccurrencesOfString:@"feed/" withString:@"" options:0 range:NSMakeRange(0, 5)];
        if (![feedURL hasPrefix:@"http:"] && ![feedURL hasPrefix:@"https:"])
            feedURL = [NSString stringWithFormat:@"https://%@/reader/public/atom/%@", openReaderHost, feedURL];

        NSString * folderName = nil;
        NSArray * categories = [feed objectForKey:@"categories"];
        NSEnumerator * catEnum = [categories objectEnumerator];
        NSDictionary * category;
        while ((category = [catEnum nextObject]) != nil) {
            if ([category objectForKey:@"label"]) {
                NSString * label = [category objectForKey:@"label"];
                NSArray * folderNames = [label componentsSeparatedByString:@" — "];
                folderName = [folderNames lastObject];
                NSMutableArray * params = [NSMutableArray arrayWithObjects:
                                           [[folderNames mutableCopy] autorelease],
                                           [NSNumber numberWithInt:MA_Root_Folder], nil];
                [self createFolders:params];
                break;
            }
        }

        if (![_localFeeds containsObject:feedURL]) {
            NSString * rssTitle = [feed objectForKey:@"title"] ? [feed objectForKey:@"title"] : @"";
            NSArray * params = [NSArray arrayWithObjects:feedURL, rssTitle, folderName, nil];
            [self createNewSubscription:params];
        } else {
            NSString * homePageURL = [feed objectForKey:@"htmlUrl"];
            if (homePageURL) {
                NSEnumerator * folderEnum = [localFolders objectEnumerator];
                Folder * f;
                while ((f = [folderEnum nextObject]) != nil) {
                    if (IsGoogleReaderFolder(f) && [[f feedURL] isEqualToString:feedURL]) {
                        [[Database sharedDatabase] setFolderHomePage:[f itemId] newHomePage:homePageURL];
                        break;
                    }
                }
            }
        }

        [googleFeeds addObject:feedURL];
    }

    // Remove local GR folders that are no longer on the server
    NSEnumerator * allFolderEnum = [[(AppController *)[NSApp delegate] folders] objectEnumerator];
    Folder * f;
    while ((f = [allFolderEnum nextObject]) != nil) {
        if (IsGoogleReaderFolder(f) && ![googleFeeds containsObject:[f feedURL]])
            [[Database sharedDatabase] deleteFolder:[f itemId]];
    }
    [googleFeeds release];

    [(AppController *)[NSApp delegate] setStatusMessage:nil persist:NO];
    [(AppController *)[NSApp delegate] performSelectorOnMainThread:@selector(showUnreadCountOnApplicationIconAndWindowTitle)
                                   withObject:nil
                                waitUntilDone:NO];
}

-(void)createNewSubscription:(NSArray *)params
{
    NSLog(@"[GR] createNewSubscription");
    NSInteger underFolder = MA_Root_Folder;
    NSString * feedURL = [params objectAtIndex:0];
    NSString * rssTitle = @"";

    if ([params count] > 1) {
        if ([params count] > 2) {
            NSString * folderName = [params objectAtIndex:2];
            if (folderName) {
                Database * db = [Database sharedDatabase];
                Folder * folder = [db folderFromName:folderName];
                underFolder = folder ? [folder itemId] : MA_Root_Folder;
            }
        }
        rssTitle = [params objectAtIndex:1];
    }

    [(AppController *)[NSApp delegate] createNewGoogleReaderSubscription:feedURL underFolder:underFolder withTitle:rssTitle afterChild:-1];
}

-(void)createFolders:(NSMutableArray *)params
{
    NSMutableArray * folderNames = [params objectAtIndex:0];
    NSNumber * parentNumber = [params objectAtIndex:1];
    [params removeObjectAtIndex:1];

    Database * db = [Database sharedDatabase];
    NSString * folderName = [folderNames objectAtIndex:0];
    Folder * folder = [db folderFromName:folderName];

    NSInteger newFolderId;
    if (!folder) {
        newFolderId = [db addFolder:[parentNumber intValue]
                         afterChild:-1
                         folderName:folderName
                               type:MA_Group_Folder
                    canAppendIndex:NO];
        parentNumber = [NSNumber numberWithInteger:newFolderId];
    } else {
        parentNumber = [NSNumber numberWithInteger:[folder itemId]];
    }

    [folderNames removeObjectAtIndex:0];
    if ([folderNames count] > 0) {
        [params addObject:parentNumber];
        [self createFolders:params];
    }
}

// ---------------------------------------------------------------------------
#pragma mark Write-back operations (mark read/starred, subscribe/unsubscribe)
// ---------------------------------------------------------------------------

// Fire-and-forget synchronous POST helper (runs on calling thread)
-(void)sendSyncPOST:(NSString *)bodyString toURL:(NSURL *)url
{
    NSMutableURLRequest * req = makePOSTRequest(url, bodyString, _clientAuthToken);
    NSHTTPURLResponse * resp = nil;
    NSError * err = nil;
    NSData * data = [AICURLConnection sendSynchronousRequest:req
                                          returningResponse:(NSURLResponse **)&resp
                                                      error:&err];
    if (!data || err || [resp statusCode] != 200) {
        NSLog(@"[GR] POST failed (%ld): %@ -> %@", (long)[resp statusCode], url, err);
        NSString * response = data ? [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease] : @"";
        if (![response isEqualToString:@"OK"])
            [self clearAuthentication];
    }
}

-(void)subscribeToFeed:(NSString *)feedURL
{
    if (![self isReady]) [self authenticate];
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/quickadd?client=%@",
                                         APIBaseURL, ClientName]];
    NSString * body = [NSString stringWithFormat:@"quickadd=%@&T=%@",
                       urlEncode(feedURL), urlEncode(_token)];
    [self sendSyncPOST:body toURL:url];
}

-(void)unsubscribeFromFeed:(NSString *)feedURL
{
    if (![self isReady]) [self authenticate];
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit", APIBaseURL]];
    NSString * body = [NSString stringWithFormat:@"ac=unsubscribe&s=%@&T=%@",
                       urlEncode([NSString stringWithFormat:@"feed/%@", feedURL]),
                       urlEncode(_token)];
    [self sendSyncPOST:body toURL:url];
}

-(void)setFolderName:(NSString *)folderName forFeed:(NSString *)feedURL set:(BOOL)flag
{
    if (![self isReady]) [self authenticate];
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?client=%@",
                                         APIBaseURL, ClientName]];
    NSString * labelKey = flag ? @"a" : @"r";
    NSString * body = [NSString stringWithFormat:@"ac=edit&s=%@&%@=%@&T=%@",
                       urlEncode([NSString stringWithFormat:@"feed/%@", feedURL]),
                       labelKey,
                       urlEncode([NSString stringWithFormat:@"user/-/label/%@", folderName]),
                       urlEncode(_token)];
    [self sendSyncPOST:body toURL:url];
}

-(void)markRead:(NSString *)itemGuid readFlag:(BOOL)flag
{
    if (![self isReady]) [self authenticate];
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@edit-tag", APIBaseURL]];
    NSString * body;
    if (flag) {
        body = [NSString stringWithFormat:@"async=true&i=%@&a=%@&T=%@",
                urlEncode(itemGuid),
                urlEncode(@"user/-/state/com.google/read"),
                urlEncode(_token)];
    } else {
        body = [NSString stringWithFormat:@"async=true&i=%@&a=%@&r=%@&T=%@",
                urlEncode(itemGuid),
                urlEncode(@"user/-/state/com.google/kept-unread"),
                urlEncode(@"user/-/state/com.google/read"),
                urlEncode(_token)];
    }
    [self sendSyncPOST:body toURL:url];

    if (!flag) {
        // Also send tracking-kept-unread
        NSString * body2 = [NSString stringWithFormat:@"async=true&i=%@&a=%@&T=%@",
                            urlEncode(itemGuid),
                            urlEncode(@"user/-/state/com.google/tracking-kept-unread"),
                            urlEncode(_token)];
        [self sendSyncPOST:body2 toURL:url];
    }
}

-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag
{
    if (![self isReady]) [self authenticate];
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@edit-tag", APIBaseURL]];
    NSString * stateTag = @"user/-/state/com.google/starred";
    NSString * actionKey = flag ? @"a" : @"r";
    NSString * body = [NSString stringWithFormat:@"async=true&i=%@&%@=%@&T=%@",
                       urlEncode(itemGuid),
                       actionKey,
                       urlEncode(stateTag),
                       urlEncode(_token)];
    [self sendSyncPOST:body toURL:url];
}

// ---------------------------------------------------------------------------
// Called on main thread after feed refresh completes
-(void)notifyArticleCountUpdate
{
    AppController * app = (AppController *)[NSApp delegate];
    [app setStatusMessage:nil persist:NO];
    [app showUnreadCountOnApplicationIconAndWindowTitle];
}

// ---------------------------------------------------------------------------
#pragma mark Dealloc
// ---------------------------------------------------------------------------

-(void)dealloc
{
    [_localFeeds release]; _localFeeds = nil;
    [_clientAuthToken release]; _clientAuthToken = nil;
    [_token release]; _token = nil;
    [tokenTimer release]; tokenTimer = nil;
    [authTimer release]; authTimer = nil;
    [super dealloc];
}

@end
