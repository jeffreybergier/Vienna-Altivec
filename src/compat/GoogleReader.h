//
//  GoogleReader.h
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011-2014 Vienna contributors (see Help/Acknowledgements for list of contributors). All rights reserved.
//
//  Ported to Tiger (10.4) / MRC / AICURLConnection by the Altivec project.
//  Removes: ASIHTTPRequest, GCD blocks, fast enumeration.
//

#import <Cocoa/Cocoa.h>
#import "Folder.h"
#import "ActivityLog.h"

// Note: MA_GoogleReader_Folder and IsGoogleReaderFolder are defined in Folder.h

@interface GoogleReader : NSObject {
@private
    NSString * _token;
    NSString * _clientAuthToken;
    NSMutableArray * _localFeeds;
    NSUInteger countOfNewArticles;
    NSTimer * tokenTimer;
    NSTimer * authTimer;
}

+(GoogleReader *)sharedManager;

-(BOOL)isReady;

-(void)loadSubscriptions:(NSNotification *)nc;
-(void)authenticate;
-(void)getToken;
-(void)clearAuthentication;
-(void)resetAuthentication;

-(void)subscribeToFeed:(NSString *)feedURL;
-(void)unsubscribeFromFeed:(NSString *)feedURL;
-(void)markRead:(NSString *)itemGuid readFlag:(BOOL)flag;
-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag;
-(void)setFolderName:(NSString *)folderName forFeed:(NSString *)feedURL set:(BOOL)flag;
-(void)refreshFeed:(Folder *)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit;
-(NSUInteger)countOfNewArticles;

@end
