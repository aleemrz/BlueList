//
//  DetailViewController.m
//  bluelist-objective-c
//
//  Created by Samir Shaikh on 12/7/15.
//  Copyright © 2015 IOT NewCo. All rights reserved.
//

#import "DetailViewController.h"
#import "TableViewController.h"


@implementation DetailViewController {
    BOOL debug;
    
}
@synthesize detailNameLabel;
@synthesize rev;
@synthesize skillsLabel;
@synthesize detailLocationLabel;
@synthesize requestServiceButton;
@synthesize serviceAddress;
@synthesize addresstext;
@synthesize selectedCell;


-(void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"%@ %@", rev, serviceAddress);

    detailNameLabel.text = rev.body[PROPERTIES_FIELD][NAME_FIELD];
    detailLocationLabel.text = [NSString stringWithFormat:@"Available %@", selectedCell.detailTextLabel.text];
    //Add more skill checks here//this needs to  move to the server.
    skillsLabel.text = [NSString stringWithFormat:@"Known for:\n%@%@%@%@%@%@%@%@%@",
    [detailNameLabel.text rangeOfString:@"Plumb"].location!=NSNotFound?@"Plumber\n":@"",
    [detailNameLabel.text rangeOfString:@"Elect"].location!=NSNotFound?@"Electrician\n":@"",
    [detailNameLabel.text rangeOfString:@"Handy"].location!=NSNotFound?@"Handyman\n":@"",
    [detailNameLabel.text rangeOfString:@"Math"].location!=NSNotFound?@"Math Tutor\n":@"",
    [detailNameLabel.text rangeOfString:@"English"].location!=NSNotFound?@"English Tutor\n":@"",
    [detailNameLabel.text rangeOfString:@"Kumon"].location!=NSNotFound?@"English Tutor\nMath Tutor\n":@"",
    [detailNameLabel.text rangeOfString:@"Lawyer"].location!=NSNotFound?@"Legal Services\n":@"",
    [detailNameLabel.text rangeOfString:@"Clean"].location!=NSNotFound?@"Cleaning Services\n":@"",
    [detailNameLabel.text rangeOfString:@"Java"].location!=NSNotFound?@"Java Programmer\n":@""]
    
    ;
    serviceAddress.text = [NSString stringWithFormat:@"%@: %@", @"Service Address", addresstext];
}

@end
