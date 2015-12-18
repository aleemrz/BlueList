//
//  DetailViewController.m
//  bluelist-objective-c
//
//  Created by Samir Shaikh on 12/7/15.
//  Copyright © 2015 IOT NewCo. All rights reserved.
//

#import "DetailViewController.h"
#import "TableViewController.h"
//#import "PayPalPayment.h"


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
    skillsLabel.text = [NSString stringWithFormat:@"Skills: %@%@%@%@%@%@%@%@%@",
                        [detailNameLabel.text rangeOfString:@"Plumb"].location!=NSNotFound?@"Plumber,":@"",
                        [detailNameLabel.text rangeOfString:@"Elect"].location!=NSNotFound?@"Electrician,":@"",
                        [detailNameLabel.text rangeOfString:@"Handy"].location!=NSNotFound?@"Handyman,":@"",
                        [detailNameLabel.text rangeOfString:@"Math"].location!=NSNotFound?@"Math Tutor,":@"",
                        [detailNameLabel.text rangeOfString:@"English"].location!=NSNotFound?@"English Tutor,":@"",
                        [detailNameLabel.text rangeOfString:@"Kumon"].location!=NSNotFound?@"English Tutor,Math Tutor,":@"",
                        [detailNameLabel.text rangeOfString:@"Lawye"].location!=NSNotFound?@"Lawyer,":@"",
                        [detailNameLabel.text rangeOfString:@"Clean"].location!=NSNotFound?@"Cleaner,":@"",
                        [detailNameLabel.text rangeOfString:@"Java"].location!=NSNotFound?@"Java,":@""]
    
    ;
    serviceAddress.text = [NSString stringWithFormat:@"%@: %@", @"Service Address", addresstext];
    
//    [PayPal initializeWithAppID:@"APP-80W284485P519543T"
//                 forEnvironment:ENV_SANDBOX];
//    
//    UIButton *paypalbutton = [[PayPal getPayPalInst]
//                        getPayButtonWithTarget:self
//                        andAction:@selector(payWithPayPal)
//                        andButtonType:BUTTON_278x43
//                        andButtonText:BUTTON_TEXT_PAY];
//    [self.view addSubview:paypalbutton];
    
    
    
}

- (IBAction)requestServiceNowButtonTapped:(UITapGestureRecognizer *)sender {
    NSLog(@"requestServiceNowButtonTapped tapped!");
//    [self payWithPayPal];
    
}

- (IBAction)requestUpdateTapped:(UITapGestureRecognizer *)sender {
    NSLog(@"requestUpdateButtonTapped tapped!");
    
}
- (IBAction)payButtonTapped:(UITapGestureRecognizer *)sender {
    NSLog(@"payButtonTapped tapped!");
}
//
//-(void)payWithPayPal {
//    NSLog(@"payWithPayPal called");
//    PayPalPayment *currentPayment = [PayPalPayment new];
//    [currentPayment setPaymentType:TYPE_SERVICE];
//    [currentPayment setRecipient:@"pay@slabtile.com"];
//    [currentPayment setSubTotal:[NSDecimalNumber decimalNumberWithString:@"105.50" ]];
//    [currentPayment setPaymentCurrency:@"USD"];
//    [currentPayment setCustomId:@"190903430943904390"];//put userIdentity.userId here.
//    [currentPayment setDescription:[NSString stringWithFormat:@"Service at %@", serviceAddress.text]];
//    [currentPayment setMerchantName:@"Printer List"];
//    
//    
//    [[PayPal getPayPalInst] checkoutWithPayment:currentPayment];
//    
//}
//
////PayPalPaymentDelegate methods:
//-(void)paymentSuccessWithKey:(NSString *)payKey andStatus:(PayPalPaymentStatus)paymentStatus {
//    
//    NSLog(@"paymentSuccessWithKey called");
//}
//
//
//
////paymentFailedWithCorrelationID:andErrorCode:andErrorMessage:
//// Record the payment as failed and perform associated bookkeeping.
//// Make no UI updates.
////
////correlationID is a string that uniquely identifies to PayPal the failed transaction.
////errorCode is generally (but not always) a numerical code associated with the error.
////errorMessage is a human-readable string describing the error that occurred.
////- (void)paymentFailedWithCorrelationID:
////    (NSString *)correlationID andErrorCode:
////    (NSString *)errorCode andErrorMessage:
////    (NSString *)errorMessage {
////    //    status = PAYMENTSTATUS_FAILED;
////}
//
//-(void)paymentFailedWithCorrelationID:(NSString *)correlationID {
//    NSLog(@"paymentFailedWithCorrelationID called");
//
//}
//
//-(void)paymentLibraryExit{
//    NSLog(@"paymentLibraryExit called");
//
//}
//
////paymentCanceled is required. Record the payment as canceled by
//// the user and perform associated bookkeeping. No UI updates.
//- (void)paymentCanceled {
//    //    status = PAYMENTSTATUS_CANCELED;
//    NSLog(@"paymentCanceled called");
//
//}

@end
