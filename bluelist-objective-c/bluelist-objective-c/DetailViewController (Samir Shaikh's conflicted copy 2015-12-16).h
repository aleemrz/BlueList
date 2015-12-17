//
//  DetailViewController.h
//  bluelist-objective-c
//
//  Created by Samir Shaikh on 12/7/15.
//  Copyright © 2015 IBM. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CloudantSync.h>

@interface DetailViewController : UIViewController

//UI elements
@property (weak, nonatomic) IBOutlet UILabel *detailNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *detailLocationLabel;
@property (weak, nonatomic) IBOutlet UILabel *skillsLabel;
@property (weak, nonatomic) IBOutlet UIButton *requestServiceButton;
@property (weak, nonatomic) IBOutlet UILabel *serviceAddress;



//Properties from TableViewController
@property CDTDocumentRevision *rev;
@property NSString *addresstext;
@property UITableViewCell *selectedCell;

@end
