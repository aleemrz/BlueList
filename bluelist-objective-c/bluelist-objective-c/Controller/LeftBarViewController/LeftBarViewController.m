//
//  LeftBarViewController.m
//  bluelist-objective-c
//
//  Created by MacBook Pro on 18/12/2015.
//  Copyright © 2015 IBM. All rights reserved.
//
#import <IMFCore/IMFCore.h>

#import "LeftBarViewController.h"

@interface LeftBarViewController ()

@property (weak, nonatomic) IBOutlet UIButton *editButton;
@property (weak, nonatomic) IBOutlet UILabel *userName;
@property (weak, nonatomic) IBOutlet UILabel *phoneNumber;
@property (weak, nonatomic) IBOutlet UILabel *creditCardNumber;
@property (weak, nonatomic) IBOutlet UISwitch *notificationSwitch;

@end

@implementation LeftBarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    NSLog(@"%@",[IMFAuthorizationManager sharedInstance].userIdentity);
    NSString * userName = [[IMFAuthorizationManager sharedInstance].userIdentity objectForKey:@"displayName"];
    [self.userName setText:userName];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)editButton:(id)sender {
    UIViewController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"EditUserViewController"];
    [self.navigationController pushViewController:controller animated:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
