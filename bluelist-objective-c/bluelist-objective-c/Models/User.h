//
//  User.h
//  bluelist-objective-c
//
//  Created by MacBook Pro on 19/12/2015.
//  Copyright © 2015 IBM. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface User : NSObject

@property (nonatomic, strong) NSString *userFullName;
@property (nonatomic, strong) NSString *firstName;
@property (nonatomic, strong) NSString *lastName;
@property (nonatomic, strong) NSString *userID;
@property (nonatomic, strong) NSString *emailAddress;
@property (nonatomic, strong) NSString *gender;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSString *profileImage;


@end
