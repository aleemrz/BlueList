//
//  DetailViewController.h
//  bluelist-objective-c
//
//  Created by Samir Shaikh on 12/7/15.
//  Copyright © 2015 IBM. All rights reserved.
//

//#import "PayPal.h"              // imports the PayPal library header file
#import <UIKit/UIKit.h>
#import <CloudantSync.h>

@interface DetailViewController : UIViewController /*<PayPalPaymentDelegate>*/ {

}

//UI elements
@property (weak, nonatomic) IBOutlet UILabel *detailNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *detailLocationLabel;
@property (weak, nonatomic) IBOutlet UILabel *skillsLabel;
@property (weak, nonatomic) IBOutlet UIButton *requestServiceButton;
@property (weak, nonatomic) IBOutlet UILabel *serviceAddress;

@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *serviceRequestTapped;


//Properties from TableViewController
@property CDTDocumentRevision *rev;
@property NSString *addresstext;
@property UITableViewCell *selectedCell;

//-(void)paymentSuccessWithKey:(NSString *)payKey andStatus:(PayPalPaymentStatus)paymentStatus;
//
//-(void)payWithPayPal;

@end
