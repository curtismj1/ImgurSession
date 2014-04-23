    //
//  IMGAuthenticationTests.m
//  ImgurSession
//
//  Created by Xtreme Dev on 2014-03-25.
//  Copyright (c) 2014 GeoffMacDonald. All rights reserved.
//


#import "IMGIntegratedTestCase.h"

//add read-write prop
@interface IMGSession (TestSession)

@property (readwrite, nonatomic, copy) NSString *clientID;
@property (readwrite, nonatomic, copy) NSString *secret;
@property (readwrite, nonatomic, copy) NSString *refreshToken;
@property (readwrite, nonatomic, copy) NSString *accessToken;
@property (readwrite, nonatomic) NSDate *accessTokenExpiry;
@property (readwrite, nonatomic) IMGAuthType lastAuthType;
@property (readwrite, nonatomic) NSInteger creditsUserRemaining;
@property (readwrite, nonatomic) NSInteger creditsUserLimit;
@property (readwrite, nonatomic) NSInteger creditsUserReset;
@property (readwrite, nonatomic) NSInteger creditsClientRemaining;
@property (readwrite, nonatomic) NSInteger creditsClientLimit;
@property (readwrite, nonatomic) NSInteger warnRateLimit;

- (void)setAuthorizationHeader:(NSDictionary *)tokens;

@end



@interface IMGAuthenticationTests : IMGIntegratedTestCase

@end

@implementation IMGAuthenticationTests

#pragma mark - Testing Authentication

-(void)testGarbageAccessToken{
 
     __block BOOL isSuccess;
    
    //after getting correct tokens
    [IMGAccountRequest accountWithUser:@"me" success:^(IMGAccount *account) {
        
         //sets bad access token in header which will cause re-auth with correct refresh token
        [[IMGSession sharedInstance].requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", @"BadAccessToken"] forHTTPHeaderField:@"Authorization"];
         
         //should fail and trigger re-auth
         [IMGAccountRequest accountWithUser:@"me" success:^(IMGAccount *account) {
         
             isSuccess = YES;
             expect(account.username).beTruthy();
         
         } failure:failBlock];
    } failure:failBlock];
     
     expect(isSuccess).will.beTruthy();
}

-(void)testSuspend{
    
    __block BOOL isSuccess;
    
    [[IMGSession sharedInstance] refreshUserAccount:^(IMGAccount *user) {
        
        IMGSession * ses = [IMGSession sharedInstance];
        [ses.operationQueue setSuspended:YES];
        
        [ses refreshUserAccount:^(IMGAccount *user) {
            
            isSuccess = YES;
            
        } failure:failBlock];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [ses.operationQueue setSuspended:NO];
        });
        
    } failure:failBlock];
    
    expect(isSuccess).will.beTruthy();
}
    
-(void)testGarbageRefreshToken{
 
     __block BOOL isSuccess = NO;
    
    //after getting correct tokens
    [IMGAccountRequest accountWithUser:@"me" success:^(IMGAccount *account) {
        
        //should fail request, then attempt refresh, should fail refresh, then attempt code input before retrieving new refresh code and continuing requests
        
        //set bad refresh token
        [[IMGSession sharedInstance].requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", @"BadAccessToken"] forHTTPHeaderField:@"Authorization"];
        [[IMGSession sharedInstance] setRefreshToken:@"blahblahblah"];
        
        //should fail request, then attempt refresh, should fail refresh, then attempt code input before retrieving new refresh code and continuing requests
        [IMGAccountRequest accountWithUser:@"me" success:^(IMGAccount *account) {
            
            //should go here
            isSuccess = YES;
            
        } failure:failBlock];
        
        
    } failure:failBlock];
    
    
    expect(isSuccess).will.beTruthy();
}

-(void)testAccessTokenDateExpiry{
    //test to ensure that upon access token expiry date, we refresh automatically
    
    __block BOOL isAwaitingRefresh = NO;
    __block NSString * oldAccess;
    
    IMGSession * ses = [IMGSession sharedInstance];
    
    [[IMGSession sharedInstance] refreshUserAccount:^(IMGAccount *user) {
        
        oldAccess = ses.accessToken;
        isAwaitingRefresh = YES;
        
        //hijack refresh to expire in 5 seconds rather than 3600
        NSDictionary * tokens = @{@"refresh_token":ses.refreshToken,@"access_token":ses.accessToken,@"expires_in":@5};
        [ses setAuthorizationHeader:tokens];
        
        
    } failure:failBlock];
    
    expect(isAwaitingRefresh).will.beTruthy();
    expect(ses.accessToken != oldAccess).will.beTruthy();
}

-(void)testImageNotFound{
    
    __block BOOL isSuccess = NO;
    
    //should fail request with not found
    
    [IMGImageRequest imageWithID:@"fdsfdsfdsa" success:^(IMGImage *image) {
        
        //should not success
        failBlock([NSError errorWithDomain:IMGErrorDomain code:0 userInfo:nil]);
        
    } failure:^(NSError *error) {
        
        //imgur sometimes responds with previous account requests for some reasons saying it is a cache hit even though it is a different URL
        //in this case this test will fail with code 1 == IMGErrorResponseMissingParameters
        
        expect(error.code == 404).beTruthy();
        
        //should go here
        isSuccess = YES;
        
    }];
    
    expect(isSuccess).will.beTruthy();
}

#pragma mark - Testing Rate Limit tracking

-(void)testTrackingClientRateLimiting{
    
    __block BOOL isSuccess;
    
    //get original copy of credits remaining
    [IMGAccountRequest accountWithUser:@"me" success:^(IMGAccount *account) {
        
        NSInteger remaining = [[IMGSession sharedInstance] creditsClientRemaining];
        
        //imgur doesn't synchronize the counts instantly for some reason so we wait a second until they do
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            //should fail and trigger re-auth
            [IMGAccountRequest accountWithUser:@"me" success:^(IMGAccount *account) {
                
                //ensure counter has gone down since we've done one request
                NSInteger next = [[IMGSession sharedInstance] creditsClientRemaining];
                expect(next).beLessThan(remaining);
                isSuccess = YES;
                
            } failure:failBlock];
        });
        
    } failure:failBlock];
    
    expect(isSuccess).will.beTruthy();
}

@end
