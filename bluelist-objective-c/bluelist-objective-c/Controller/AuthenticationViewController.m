// Copyright 2014, 2015 IBM Corp. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


#import <Foundation/Foundation.h>
#import "AuthenticationViewController.h"
#import "AppDelegate.h"
#import "TableViewController.h"
#import <IMFCore/IMFCore.h>
#import "CloudantHttpInterceptor.h"

@interface AuthenticationViewController() 



@end

@implementation AuthenticationViewController

@synthesize progressLabel;
@synthesize errorTextView;
//@synthesize userIdentity;
@synthesize remotedatastoreurl;
@synthesize dbName;
@synthesize cloudantHttpInterceptor;
@synthesize logger;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self authenticateUser];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)authenticateUser {
    [self.logger logInfoWithMessages:@"Trying to authenticateUser"];
    self.progressLabel.text = @"Authenticating";
    if ([self checkIMFClient] && [self checkAuthenticationConfig]) {
        [self getAuthToken];
    }
}

- (void) getAuthToken {
    self.progressLabel.text = @"1/2 Authenticating with Printer List";
    IMFAuthorizationManager *authManager = [IMFAuthorizationManager sharedInstance];
    [authManager obtainAuthorizationHeaderWithCompletionHandler:^(IMFResponse *response, NSError *error) {
        NSMutableString *errorMsg = [[NSMutableString alloc] init];
        if (error != nil) {
            [errorMsg appendString:@"Error obtaining Authentication Header.\nCheck to see if Authentication settings in the Info.plist match exactly to the ones in MCA, or check the applicationId and applicationRoute in bluelist.plist\n\n"];
            if (response != nil) {
                [errorMsg appendString:response.responseText];
            }
            if (error != nil && error.userInfo != nil) {
                [errorMsg appendString:error.userInfo.description];
            }
            [self invalidAuthentication:errorMsg];

        } else {
            //lets make sure we have an user id before transitioning
            if (authManager.userIdentity != nil) {
                NSLog(@"User identity: %@", authManager.userIdentity);
//                self.userIdentity = authManager.userIdentity;
                NSString *userIdlocal = [authManager.userIdentity valueForKey:@"id"];
                if (userIdlocal != nil) {
                    [self.logger logInfoWithMessages:@"Authenticated user with id %@",userIdlocal];
                    self.progressLabel.text = [NSString stringWithFormat:@"2/2 Auth successful. \n Connecting to Printer List.." ];
                    [self enrollUser:userIdlocal completionHandler:^(NSString *dbname, NSError *error) {
                        if(error){
//                            self.progressLabel.text = [NSString stringWithFormat:@"Sorry, the system is overloaded. Please retry after 5 minutes." ];
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                [self invalidAuthentication:[NSString stringWithFormat:@"Sorry, the system is overloaded. Please retry after 5 minutes id %@.  Error connecting to database: %@", userIdlocal, error]]; });
                        }else{
                            //user is authenticated show main UI
                            UIApplication *mainApplication = [UIApplication sharedApplication];
                            if (mainApplication.delegate != nil) {
                                AppDelegate *delegate = mainApplication.delegate;
                                delegate.isUserAuthenticated = YES;
                            }
                            [self showMainApplication];
                        }
                    }];
                } else {
                    [self invalidAuthentication:@"Valid Authentication Header and userIdentity, but id not found"];
                }
            } else {
                [self invalidAuthentication:@"Valid Authentication Header, but userIdentity not found. You have to configure one of the methods available in Advanced Mobile Service on Bluemix, such as Facebook, Google, or Custom "];
                //[self invalidAuthentication:@"Valid Authentication Header, but userIdentity not found."];
            }
        }
    }];
}

-(void) enrollUser: (NSString*) userId completionHandler: (void(^) (NSString*dbname, NSError *error)) completionHandler
{
    NSString *enrollUrlString = [NSString stringWithFormat:@"%@/bluelist/enroll", [IMFClient sharedInstance].backendRoute];
    NSURL *enrollUrl = [NSURL URLWithString:enrollUrlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:enrollUrl];
    request.HTTPMethod = @"PUT";
    [request addValue:[[IMFAuthorizationManager sharedInstance]cachedAuthorizationHeader] forHTTPHeaderField:@"Authorization"];
    
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if(error){
            completionHandler(nil, error);
            return;
        }
        
        NSInteger httpStatus = ((NSHTTPURLResponse*)response).statusCode;
        if(httpStatus != 200){
            dispatch_sync(dispatch_get_main_queue(), ^{
               completionHandler(nil ,[NSError errorWithDomain:@"BlueList" code:42 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Invalid HTTP Status %ld.  Check NodeJS application on Bluemix", httpStatus]}]);
            });
            return;
        }
        
        if(data){
            NSError *jsonError = nil;
            NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData: data options:0 error: &jsonError];
            if(!jsonError && jsonObject){
                NSDictionary *cloudantAccess = jsonObject[@"cloudant_access"];
                NSString *cloudantHost = cloudantAccess[@"host"];
                NSString *cloudantPort = cloudantAccess[@"port"];
                NSString *cloudantProtocol = cloudantAccess[@"protocol"];
                self.dbName = jsonObject[@"database"];
                NSString *sessionCookie = jsonObject[@"sessionCookie"];
                
                
                self.remotedatastoreurl = [NSURL URLWithString: [NSString stringWithFormat:@"%@://%@:%@/%@", cloudantProtocol, cloudantHost, cloudantPort, self.dbName]];
                
                NSString *refreshUrlString = [NSString stringWithFormat:@"%@/bluelist/sessioncookie", [IMFClient sharedInstance].backendRoute];
                self.cloudantHttpInterceptor = [[CloudantHttpInterceptor alloc]initWithSessionCookie:sessionCookie refreshUrl:[NSURL URLWithString:refreshUrlString]];
                
                completionHandler(self.dbName, nil);
            }else{
                completionHandler(nil, jsonError);
            }
        }else{
            completionHandler(nil, [NSError errorWithDomain:@"BlueList" code:42 userInfo:@{NSLocalizedDescriptionKey : @"No JSON data returned from enroll call.  Check NodeJS application on Bluemix"}]);
        }

    }] resume];
}

- (BOOL) checkIMFClient {
    IMFClient *imfclient = [IMFClient sharedInstance];
    NSString *route = imfclient.backendRoute;
    NSString *uid = imfclient.backendGUID;
    
    if (route == nil || route.length == 0) {
        [self invalidAuthentication:@"Invalid Route.\n Check applicationRoute in bluelist.plist"];
        return false;
    }
    if (uid == nil || uid.length == 0) {
        [self invalidAuthentication:@"Invalid UID.\n Check applicationId in bluelist.plist"];
        return false;
    }
    return true;
}

- (BOOL) checkAuthenticationConfig {
    if ([self isFacebookConfigured]) {
        self.progressLabel.text = @"Facebook Login";
        return true;
    }
    else if ([self isCustomConfigured]) {
        self.progressLabel.text = @"Custom Login";
        return true;
    }
    else if ([self isGoogleConfigured]) {
        self.progressLabel.text = @"Google Login";
        return true;
    }
    
    
    [self invalidAuthentication:@"Authentication is not configured in Info.plist. You have to configure Info.plist with the same Authentication method configured on Bluemix such as Facebook, Google, or Custom. Check the README.md file for more instructions"];
    return false;
}

-(BOOL) isFacebookConfigured {
    self.progressLabel.text = @"Checking Facebook Configuration...";
    NSString *facebookAppId = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"FacebookAppID"];
    NSString *facebookDisplayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"FacebookDisplayName"];
    NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    NSDictionary *urlTypes0 = urlTypes[0];
    NSArray *urlSchemes = urlTypes0[@"CFBundleURLSchemes"];
    NSString *facebookURLScheme = urlSchemes[0];
    
    if (facebookAppId == nil || [facebookAppId isEqualToString:@""] || [facebookAppId isEqualToString:@"123456789"]) {
        return false;
    }
    if (facebookDisplayName == nil || [facebookDisplayName isEqualToString:@""]) {
        return false;
    }
    if (facebookURLScheme == nil || [facebookURLScheme isEqualToString:@""] || [facebookURLScheme isEqualToString:@"fb123456789"] || ![facebookURLScheme hasPrefix:@"fb"]) {
        return false;
    }
    [self.logger logInfoWithMessages:@"Facebook Authentication Configured:\nFacebookAppID %@\nFacebookDisplayName %@\nFacebookURLScheme %@",facebookAppId,facebookDisplayName,facebookURLScheme];
    
    self.progressLabel.text = @"Facebook Configuration Complete";

    
    return true;
}

-(BOOL) isGoogleConfigured {
    NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    NSDictionary *urlTypes1 = urlTypes[1];
    NSString *urlIdentifier = urlTypes1[@"CFBundleURLName"];
    NSArray *urlSchemes = urlTypes1[@"CFBundleURLSchemes"];
    NSString *googleURLScheme = urlSchemes[0];
    
    if (urlIdentifier == nil || [urlIdentifier isEqualToString:@""]) {
        return false;
    }
    if (googleURLScheme == nil || googleURLScheme.length == 0 || ![googleURLScheme isEqualToString:urlIdentifier]) {
        return false;
    }
    [self.logger logInfoWithMessages:@"Google Authentication Configured:\nURL Identifier %@\nURL Scheme %@",urlIdentifier,googleURLScheme];
    return true;
}

-(BOOL) isCustomConfigured {
    NSString *customAuthenticationRealm = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CustomAuthenticationRealm"];
    if (customAuthenticationRealm == nil || [customAuthenticationRealm isEqualToString:@""]) {
        return false;
    }
    [self.logger logInfoWithMessages:@"Custom Authentication Configured:\nCustomAuthenticationRealm %@",customAuthenticationRealm];
    return true;
}

-(void) invalidAuthentication:(NSString *)message {
    self.progressLabel.text = @"Error Authenticating";
    self.errorTextView.text = @"";
    self.errorTextView.text = [self.errorTextView.text stringByAppendingString:message];
    [self.logger logErrorWithMessages:message];
    
    if([[UIApplication sharedApplication] delegate] != nil) {
        AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
        [delegate clearKeychain];
    }
}

-(void) showMainApplication {
    [self performSegueWithIdentifier:@"authenticationSegue" sender:self];
}

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSLog(@"prepare for segue %@ %@", segue, sender);
    UINavigationController *navVC = segue.destinationViewController;
    TableViewController *listTableVC = (TableViewController *) navVC.topViewController;
    listTableVC.dbName = self.dbName;
    listTableVC.remotedatastoreurl = self.remotedatastoreurl;
    listTableVC.cloudantHttpInterceptor = self.cloudantHttpInterceptor;
}

@end
