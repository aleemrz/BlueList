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

#import "TableViewController.h"
#import "AppDelegate.h"
#import <IMFCore/IMFCore.h>
#import <CloudantSync.h>
#import <CloudantSyncEncryption.h>
#import <CoreLocation/CoreLocation.h>
#import "DetailViewController.h"






@interface TableViewController () <UITextFieldDelegate, CDTReplicatorDelegate, CLLocationManagerDelegate>

@property UIImage* highImage;
@property UIImage* mediumImage;
@property UIImage* lowImage;
@property (strong, nonatomic) IBOutlet UISegmentedControl *segmentFilter;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *settingsButton;
- (IBAction)filterTable:(UISegmentedControl *)sender;

// Items in list
@property NSMutableArray *itemList;
@property NSMutableArray* filteredListItems;

// Cloud sync properties
@property CDTDatastoreManager *datastoreManager;
@property CDTDatastore *datastore;

@property CDTReplicatorFactory *replicatorFactory;

@property CDTPullReplication *pullReplication;
@property CDTReplicator *pullReplicator;

@property CDTPushReplication *pushReplication;
@property CDTReplicator *pushReplicator;

@property BOOL doingPullReplication;

//logger property
@property IMFLogger *logger;

@end

@implementation TableViewController {
    CLLocationManager *manager;
    CLGeocoder *geocoder;
    CLPlacemark *placemark;
    CLLocation *currentLocation;
    BOOL debug;
}
@synthesize address;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    debug = YES;
    manager = [[CLLocationManager alloc] init];
    geocoder = [[CLGeocoder alloc] init];

    self.highImage = [UIImage imageNamed:@"priorityHigh.png"];
    self.mediumImage = [UIImage imageNamed:@"priorityMedium.png"];
    self.lowImage = [UIImage imageNamed:@"priorityLow.png"];

    
    self.itemList = [[NSMutableArray alloc]init];
    self.filteredListItems = [[NSMutableArray alloc]init];
    
    // Setting up the refresh control
    self.settingsButton.enabled = false;
    self.refreshControl = [[UIRefreshControl alloc]init];
    [self.refreshControl addTarget:self action:@selector(handleRefreshAction) forControlEvents:UIControlEventValueChanged];
    
    [self.refreshControl beginRefreshing];
    [self setupIMFDatabase];
    
    //logger
    self.logger = [IMFLogger loggerForName:@"BlueList"];
    [self.logger logInfoWithMessages:@"this is a info test log in ListTableViewController:viewDidLoad"];
    
    //location
    manager.delegate = self;
    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
    //    self.manager allowsBackgroundLocationUpdates = YES;
    manager.allowsBackgroundLocationUpdates=NO;
    manager.pausesLocationUpdatesAutomatically=YES;
    manager.distanceFilter=1000.0f;
    
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusDenied ||
        status == kCLAuthorizationStatusAuthorizedWhenInUse ||
        status == kCLAuthorizationStatusNotDetermined) {
        // present an alert indicating location authorization required
        // and offer to take the user to Settings for the app via
        // UIApplication -openUrl: and UIApplicationOpenSettingsURLString
        [manager requestWhenInUseAuthorization];
    }
    
    [manager requestWhenInUseAuthorization];
    [manager startMonitoringSignificantLocationChanges];
    [manager startUpdatingLocation];
//    [manager startUpdatingHeading];


}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"Went to Background");
    // Need to stop regular updates first
    [manager stopUpdatingLocation];
    // Only monitor significant changes
    [manager startMonitoringSignificantLocationChanges];
    [self pushItems];
}

- (void)willEnterForeground:(UIApplication *)application
{
    [manager stopMonitoringSignificantLocationChanges];
    [manager startUpdatingLocation];
    [self pullItems];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Data Management

- (void) setupIMFDatabase {
    BOOL encryptionEnabled = NO;
    //Read the bluelist.plist
    NSString *configurationPath = [[NSBundle mainBundle]pathForResource:@"bluelist" ofType:@"plist"];
    NSDictionary *configuration = [NSDictionary dictionaryWithContentsOfFile:configurationPath];
    NSString *encryptionPassword = configuration[@"encryptionPassword"];
    if(!encryptionPassword || [encryptionPassword isEqualToString:@""]){
        encryptionEnabled = NO;
    }
    else{
        encryptionEnabled = YES;
        self.dbName = [self.dbName stringByAppendingString:@"secure"];
    }

    //create CDTEncryptionKeyProvider
    id<CDTEncryptionKeyProvider> keyProvider=nil;
    NSError *error = nil;
    
    
    // Create CDTDatastoreManager
    NSFileManager *fileManager= [NSFileManager defaultManager];
    NSURL *documentsDir = [[fileManager URLsForDirectory:NSDocumentDirectory
                                               inDomains:NSUserDomainMask] lastObject];
    NSLog(@"documentdir: %@", [documentsDir absoluteString]);
    NSURL *storeURL = [documentsDir URLByAppendingPathComponent: @"bluelistdir"];
    NSLog(@"storeURL: %@", [documentsDir absoluteString]);
    
    BOOL isDir;
    BOOL exists = [fileManager fileExistsAtPath:[storeURL path] isDirectory:&isDir];
    
    if (exists && !isDir) {
        if (error) {
            NSLog(@"DBCreationFailure: Could not create CDTDatastoreManager with directory %@.", documentsDir);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"DBCreationFailure: Could not create CDTDatastoreManager with directory %@", documentsDir ] delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil, nil];
            [alert show];
        }
        return;
    }
    
    if (!exists) {
        [fileManager createDirectoryAtURL:storeURL withIntermediateDirectories:YES attributes:nil error:&error];
        if(error){
            NSLog(@"DBCreationFailure: Could not create CDTDatastoreManager with directory %@.", documentsDir);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"DBCreationFailure: Could not create CDTDatastoreManager with directory %@", documentsDir ] delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil, nil];
            [alert show];
            return;
        }
    }
    
    self.datastoreManager = [[CDTDatastoreManager alloc] initWithDirectory:[storeURL path] error:&error];
    if(error){
        NSLog(@"DBCreationFailure: Could not create CDTDatastoreManager with directory %@.", documentsDir);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"DBCreationFailure: Could not create CDTDatastoreManager with directory %@", documentsDir ] delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil, nil];
        [alert show];
        return;
    }
    
    //create a local data store. Encrypt the local store if the setting is enabled
    if(encryptionEnabled){
        //Initalize the key provider
        keyProvider = [CDTEncryptionKeychainProvider providerWithPassword:encryptionPassword forIdentifier:@"bluelist"];
        NSLog(@"Attempting to create an ecrypted local data store");
        //Initialize an encrypted local store
        self.datastore = [self.datastoreManager datastoreNamed:self.dbName withEncryptionKeyProvider:keyProvider error:&error];
    }else{
        self.datastore = [self.datastoreManager datastoreNamed:self.dbName error:&error];
    }
    
    NSString* idxname =@"datatypeindex";
    if(debug) {
        NSLog(@"setup index %@", idxname);
        [self.datastore deleteIndexNamed:idxname]; //uncomment for testing, comment otherwise.
    }
    // Setup required indexes for Query
//    [self.datastore ensureIndexed:@[DATATYPE_FIELD, @"type", @"properties.name", @"properties.address"] withName:idxname type:@"json"];
    
//    @"textIdxName": @{ @"fields": @[ @"field1", @"field2" ],
//                       @"type": @"text",
//                       @"name": @"textIdxName",
//                       @"settings": @"{tokenize: simple}"  },
    [self.datastore ensureIndexed:@[@"properties.name", @"properties.address"]
                         withName:idxname type:@"text" settings:@{@"tokenize":@"simple"}];
   
    if (error) {
        NSLog(@"DBCreationFailure: Could not create DB with name %@.", self.dbName);
        if(encryptionEnabled){
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Could not create an encrypted local store with credentials provided. Check the encryptionPassword in the bluelist.plist file." delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil, nil];
            [alert show];
        }
    }
    else{
            NSLog(@"Local data store created successfully");
    }

    
    
    //create a replication push and pull objects using the local datastore and remote datastore url
    self.replicatorFactory = [[CDTReplicatorFactory alloc]initWithDatastoreManager:self.datastoreManager];
    
    self.pullReplication = [CDTPullReplication replicationWithSource:self.remotedatastoreurl target:self.datastore];
    [self.pullReplication addInterceptor:self.cloudantHttpInterceptor];
    
    self.pushReplication = [CDTPushReplication replicationWithSource:self.datastore target:self.remotedatastoreurl];
    [self.pushReplication addInterceptor:self.cloudantHttpInterceptor];
    
    [self pullItems];
}
//
//- (NSString *) getDataFrom{
//    
//    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
//    [request setHTTPMethod:@"GET"];
//    [request setURL:[NSURL URLWithString:self.remotedatastoreurl]];
//    
//    NSError *error = [[NSError alloc] init];
//    NSHTTPURLResponse *responseCode = nil;
//    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
//    
//    [NSURLConnection sendAsynchronousRequest:request
//                                                               queue:queue
//                                                   completionHandler:^(NSURLResponse* response,
//                                                                       NSData *oResponseData ,
//                                                                       NSError* error)
//    {
//        if (oResponseData) {
//            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
//            // check status code and possibly MIME type (which shall start with "application/json"):
//            NSRange range = [response.MIMEType rangeOfString:@"application/json"];
//            
//            if (httpResponse.statusCode == 200 /* OK */ && range.length != 0) {
//                NSError* error;
//                id jsonObject = [NSJSONSerialization JSONObjectWithData:oResponseData options:0 error:&error];
//                if (jsonObject) {
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        // self.model = jsonObject;
//                        NSLog(@"jsonObject: %@", jsonObject);
//                    });
//                } else {
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        //[self handleError:error];
//                        NSLog(@"ERROR: %@", error);
//                    });
//                }
//            }
//            else {
//                // status code indicates error, or didn't receive type of data requested
//                NSString* desc = [[NSString alloc] initWithFormat:@"HTTP Request failed with status code: %d (%@)",
//                                  (int)(httpResponse.statusCode),
//                                  [NSHTTPURLResponse localizedStringForStatusCode:httpResponse.statusCode]];
//                NSError* error = [NSError errorWithDomain:@"HTTP Request"
//                                                     code:-1000
//                                                 userInfo:@{NSLocalizedDescriptionKey: desc}];
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    //[self handleError:error];  // execute on main thread!
//                    NSLog(@"ERROR: %@", error);
//                });
//            }
//        }
//        else {
//            // request failed - error contains info about the failure
//            dispatch_async(dispatch_get_main_queue(), ^{
//                //[self handleError:error]; // execute on main thread!
//                NSLog(@"ERROR: %@", error);
//            });
//        }
//    }];
//    
//}

- (void)listItems2: (void(^)(void)) cb
{
    [self.logger logDebugWithMessages:@"listItems2 called"];
    NSLog(@"listItems2 called");
    
    NSDictionary *indexes = [self.datastore listIndexes];
    NSLog(@"indexes %@", indexes);
    
//    https://4f35ceb4-d741-4ea0-bfac-0022c103f798-bluemix.cloudant.com/printerlistdb/_design/geodd/_geo/geoidx?lon=-122.03369603&lat=37.33477977&radius=10000&stale=ok&include_docs=true&limit=10&relation=contains
    
    NSString *geoddurl =
    [NSString stringWithFormat:@"%@/_design/geodd/_geo/geoidx?lon=%f&lat=%f&radius=%d&stale=ok&include_docs=true&limit=%i&relation=contains", self.remotedatastoreurl, currentLocation.coordinate.longitude, currentLocation.coordinate.latitude, 10000, 10];
    
    NSLog(@"remotedataurl %@", geoddurl);
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"GET"];
    [request setURL:[NSURL URLWithString:geoddurl]];
    
    NSError *error = [[NSError alloc] init];
    NSHTTPURLResponse *responseCode = nil;
    
    NSData *oResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseCode error:&error];

    NSMutableArray *results;

    if([responseCode statusCode] != 200){
        NSLog(@"Error getting %@, HTTP status code %li", geoddurl, (long)[responseCode statusCode]);
    }
    else {
        results = [NSKeyedUnarchiver unarchiveObjectWithData:oResponseData];

    }
    
    NSLog(@"Count: %lu", (unsigned long)[results count]);
    
    self.itemList = results;
    [self reloadLocalTableData];
    
    if (cb) {
        cb();
    }
}

- (double) computeDistance: (NSArray*) coordinates
{
    CLLocation *locB = [[CLLocation alloc] initWithLatitude:[[coordinates objectAtIndex:1] doubleValue] longitude:[[coordinates objectAtIndex:0] doubleValue]];
    
    CLLocationDegrees dist = [currentLocation distanceFromLocation:locB]/1609.34; // compute and convert to miles
    
    if(debug) {
        NSLog(@"distance: %f", dist);
    }
    return dist;
}

- (void)listItems: (void(^)(void)) cb
{
    [self.logger logDebugWithMessages:@"listItems called"];
    NSLog(@"listItems called");
    
    NSDictionary *indexes = [self.datastore listIndexes];
    NSLog(@"indexes %@", indexes);
    
    NSLog(@"remotedataurl %@", self.remotedatastoreurl);
    
    CDTQResultSet *resultSet = [self.datastore  find:@{DATATYPE_FIELD : DATATYPE_VALUE} skip:0 limit:100 fields:@[PROPERTIES_FIELD, GEOLOCATION_FIELD] sort:nil];
//    @{ @"$or": @[ @{ @"pet.species": @{ @"$eq": @"dog" } },
//                  @{ @"age": @{ @"$lt": @30 } }
//                  ]};
//    NSDictionary* searchquery = @{@"$or":@[
//                                          @{@"$text" : @{@"$search" : @"plumb*"}},
//                                          @{@"$text" : @{@"$search" : @"elect*"}}
//                                  ]};
//    NSLog(@"search: %@", searchquery);
//    CDTQResultSet *resultSet = [self.datastore find:searchquery];
    
    NSMutableArray *results = [NSMutableArray array];
    
    [resultSet enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger idx, BOOL *stop) {
        if(!rev.deleted) {
            [results addObject:rev];
        }
    }];
    if(debug) {
        NSLog(@"Count: %lu", (unsigned long)[results count]);
    }

    self.itemList = results;
    [self reloadLocalTableData];
    
    if (cb) {
        cb();
    }
}

- (void) createItem: (CDTDocumentRevision*) item
{
    //save will perform a create because the item object does not exist yet in the DB.
    NSError *error = nil;
    NSLog(@"createItem called");
    [self.datastore createDocumentFromRevision:item error:&error];
    
    if (error) {
        [self.logger logErrorWithMessages:@"createItem failed with error: %@", error];
    } else {
        [self listItems:nil];
    }
    NSLog(@"createItem return");
}
- (void) updateItem: (CDTDocumentRevision*) item
{
    //save will perform a create because the CDTDocumentRevision already exists.
    NSError *error = nil;
    [self.datastore updateDocumentFromRevision:item error:&error];
    
    if (error) {
        [self.logger logErrorWithMessages:@"update failed with error: %@", error];
    } else {
        [self listItems:nil];
    }
}
//-(void) deleteItem: (CDTDocumentRevision*) item
//{
//    NSLog(@"deleteItem called");
////    [self.datastore deleteDocumentFromRevision:item error:&error];
////    NSString *dataTypeValue = [item.body[DELETED_FIELD] stringValue];
////    NSLog(@"Delete Flag Found: %@", dataTypeValue);
//    item.body[DELETED_FIELD] = [NSString stringWithFormat:@"%@", DELETED_VALUE];
//    NSLog(@"Delete Flag now: %@", item.body[DELETED_FIELD] );
//    [self updateItem:item];
//
//    NSLog(@"deleteItem returned");
//}

-(void) deleteItem: (CDTDocumentRevision*) item
{
    NSLog(@"deleteItem called");
    NSError *error = nil;
    [self.datastore deleteDocumentFromRevision:item error:&error];
    
    if (error != nil) {
        [self.logger logErrorWithMessages:@"deleteItem failed with error: %@", error];
    } else {
        [self listItems:nil];
    }
    NSLog(@"deleteItem returned");
}

#pragma mark - Cloud Sync
// Replicate from the remote to local datastore
- (void)pullItems
{
    NSError *error = nil;
    self.pullReplicator = [self.replicatorFactory oneWay:self.pullReplication error:&error];
    if(error != nil){
        [self.logger logErrorWithMessages:@"Error creating oneWay pullReplicator %@", error];
    }
    
    self.pullReplicator.delegate = self;
    self.doingPullReplication = YES;
    self.refreshControl.attributedTitle = [[NSAttributedString alloc]initWithString:@"Pulling Items from Printer List"];
    
    error = nil;
    NSLog(@"Replicating data with Printer List");
    [self.pullReplicator startWithError:&error];
    if(error != nil){
        [self.logger logErrorWithMessages:@"error starting pull replicator: %@", error];
    }
    
}
// Replicate data & logs from the local to remote
- (void)pushItems
{
    NSError *error = nil;
    self.pushReplicator = [self.replicatorFactory oneWay:self.pushReplication error:&error];
    if(error != nil){
        [self.logger logErrorWithMessages:@"error creating one way push replicator: %@", error];
    }
    
    self.pushReplicator.delegate = self;
    
    self.doingPullReplication = NO;
   self.refreshControl.attributedTitle = [[NSAttributedString alloc]initWithString:@"Pushing Items to Printer List"];
    
    error = nil;
    [self.pushReplicator startWithError:&error];
    if(error != nil){
        [self.logger logErrorWithMessages:@"error starting push replicator: %@", error];
    }
    else {
        NSLog(@"replication complete %@",error);
    }
}
/**
 * Called when the replicator changes state.
 */
-(void) replicatorDidChangeState:(CDTReplicator*)replicator
{
    [self.logger logInfoWithMessages:@"replicatorDidChangeState %@",[CDTReplicator stringForReplicatorState:replicator.state]];
}

/**
 * Called whenever the replicator changes progress
 */
-(void) replicatorDidChangeProgress:(CDTReplicator*)replicator
{
    [self.logger logInfoWithMessages:@"replicatorDidChangeProgress %@",[CDTReplicator stringForReplicatorState:replicator.state]];
}

/**
 * Called when a state transition to COMPLETE or STOPPED is
 * completed.
 */
- (void)replicatorDidComplete:(CDTReplicator*)replicator
{
    [self.logger logInfoWithMessages:@"replicatorDidComplete %@",[CDTReplicator stringForReplicatorState:replicator.state]];
    if(self.doingPullReplication){
        //done doing pull, lets start push
        [self pushItems];
    } else {
        //doing push, push is done read items from local data store and end the refresh UI
        [self listItems:^{
            self.refreshControl.attributedTitle = [[NSAttributedString alloc]initWithString:@"  "];
            [self.logger logInfoWithMessages:@"Done refreshing table after replication"];
            [self.refreshControl performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:YES];
            self.settingsButton.enabled = true;
        }];
    }
    
}

/**
 * Called when a state transition to ERROR is completed.
 */
- (void)replicatorDidError:(CDTReplicator*)replicator info:(NSError*)info
{
    self.refreshControl.attributedTitle = [[NSAttributedString alloc]initWithString:@"Error replicating with Printer List"];
    NSLog(@"replicatorDidError %@",replicator.error);
    [self listItems:^{
        [self.refreshControl performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:YES];
    }];
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
       return self.filteredListItems.count;
    } else {
        //add section
        return 1;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    if( indexPath.section == 0) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"ItemCell" forIndexPath:indexPath];
        CDTDocumentRevision *item = (CDTDocumentRevision*)self.filteredListItems[indexPath.row];
        for (UIView *view in [cell.contentView subviews]) {
            if([view isKindOfClass:[UITextField class]]){
                ((UITextField*)view).text = (item.body[PROPERTIES_FIELD][NAME_FIELD])?item.body[PROPERTIES_FIELD][NAME_FIELD]:item.body[NAME_FIELD];
//                ((UITextField*)view).tag = indexPath.row;
            }
            else if([view isKindOfClass:[UILabel class]]) {
                UILabel *lbl = (UILabel *)view;
                if(lbl.tag == 1){
                    ((UITextField*)view).text = (item.body[PROPERTIES_FIELD][NAME_FIELD])?item.body[PROPERTIES_FIELD][NAME_FIELD]:item.body[NAME_FIELD];
                //                ((UITextField*)view).tag = indexPath.row;
                    NSLog(@"name: %@ ", ((UITextField*)view).text );
                       }
                else {
                    cell.textLabel.text = (item.body[PROPERTIES_FIELD][NAME_FIELD])?item.body[PROPERTIES_FIELD][NAME_FIELD]:item.body[NAME_FIELD];
                    
                    CLLocationDistance dist = [self computeDistance:item.body[GEOLOCATION_FIELD][COORDINATES_FIELD]];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"at: %.1fmi loc: %@", dist, (item.body[PROPERTIES_FIELD][ADDRESS_FIELD])?item.body[PROPERTIES_FIELD][ADDRESS_FIELD]:item.body[ADDRESS_FIELD]];

                    NSLog(@"item location %ld, %@, %.1f", (long)indexPath.row, item.body[GEOLOCATION_FIELD][COORDINATES_FIELD], dist);
//                ((UILabel*)view).text =
//                ((UILabel*)view).tag = indexPath.row;
                }
            }
            
        }
        cell.imageView.image = [self getPriorityImageForPriority:[item.body[PROPERTIES_FIELD][PRIORITY_FIELD]? item.body[PROPERTIES_FIELD][PRIORITY_FIELD]:item.body[PRIORITY_FIELD] integerValue]];
        cell.contentView.tag = 0;
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:@"AddCell" forIndexPath:indexPath];
        //later use to check if it's add textField
        cell.contentView.tag = 1;
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    //not show delete button
//    return indexPath.section == 0;
    return NO;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [self deleteItem:self.filteredListItems[indexPath.row]];
        [self.filteredListItems removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    //ADD Code here to start Request service.
    if (indexPath.section == 0) {
        [self changePriorityForCell:[self.tableView cellForRowAtIndexPath:indexPath]];
//    
//        DetailViewController* detailViewController = [self.storyboard class:DetailViewController];
//        detailViewController = [segue]
//    
//        detailViewController.detailNameLabel.text = [self.tableView cellForRowAtIndexPath:indexPath].textLabel.text;
    }
    
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender{
    NSLog(@"should perform seque %@, %@", identifier, sender);
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSLog(@"prepare for segue %@ %@", segue, sender);
    if([[segue identifier] isEqualToString:@"DetailViewController"]) {
        DetailViewController* dest = [segue destinationViewController];
        NSIndexPath* indexPath = [self.tableView indexPathForSelectedRow];
        UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath];
    
        CDTDocumentRevision* itemf = [self.filteredListItems objectAtIndex:indexPath.row];
        [dest setRev:itemf];
        [dest setAddresstext:address.text];
        [dest setSelectedCell:selectedCell];
    }
    
}

-(void) changePriorityForCell:(UITableViewCell *) cell{
    NSInteger selectedPriority;
    NSInteger newPriority = 0;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if(debug)  {
        NSLog(@"indexPath: %@", indexPath);
        NSLog(@"indexPath.row: %i", (int)indexPath.row);
        NSLog(@"filteredListItems: %@", self.filteredListItems);
    }
    CDTDocumentRevision *itemf = [self.filteredListItems objectAtIndex:indexPath.row];
    CDTDocumentRevision *item = [itemf copy];
    selectedPriority = [item.body[PROPERTIES_FIELD][PRIORITY_FIELD] integerValue];
    newPriority = [self getNextPriority:selectedPriority];
    item.body[PROPERTIES_FIELD][PRIORITY_FIELD] = [NSNumber numberWithInteger:newPriority];
    cell.imageView.image = [self getPriorityImageForPriority:newPriority];
    [self updateItem:item];
}

-(NSInteger) getNextPriority:(NSInteger) currentPriority{
    NSInteger newPriority;
    switch (currentPriority) {
        case 2:
            newPriority = 0;
            break;
        case 1:
            newPriority = 2;
            break;
        default:
            newPriority = 1;
            break;
    }
    return newPriority;
}

-(UIImage*) getPriorityImageForPriority:(NSInteger)priority{
    
    UIImage* resultImage;
    
    switch (priority) {
        case 2:
            resultImage = self.highImage;
            break;
        case 1:
            resultImage = self.mediumImage;
            break;
            
        default:
            resultImage = self.lowImage;
            break;
    }
    return resultImage;
}

-(NSInteger) getPriorityForString:(NSString *) priorityString{
    NSInteger priority;
    if([priorityString isEqualToString:@"Handy"]){
        priority = 4;
    } else if([priorityString isEqualToString:@"Cleaner"]){
        priority = 3;
    } else if([priorityString isEqualToString:@"Electrician"]){
        priority = 2;
    } else if ([priorityString isEqualToString:@"Plumber"]){
        priority = 1;
    } else {
        priority = 0;
    }
    return priority;
}


-(void) filterContentForPriority:(NSString *)scope {
    NSLog(@"filtering %@", scope);
    
    NSInteger priority = [self getPriorityForString:scope];
    
    if(priority >= 1){
        //filter base on priority
//        NSIndexSet *matchSet = [self.itemList indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
//            return [((CDTDocumentRevision *)obj).body[PRIORITY_FIELD] integerValue] == priority;
//        }];
        
        NSIndexSet *matchSet = [self.itemList indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            NSString *name = ((CDTDocumentRevision *)obj).body[PROPERTIES_FIELD][NAME_FIELD]?((CDTDocumentRevision *)obj).body[PROPERTIES_FIELD][NAME_FIELD]:((CDTDocumentRevision *)obj).body[NAME_FIELD];
            return [name containsString:[scope substringToIndex:5]];
        }];
        
        [self.filteredListItems removeAllObjects];
        self.filteredListItems = [NSMutableArray arrayWithArray:[self.itemList objectsAtIndexes:matchSet]];
    } else {
        //don't filter select all
        [self.filteredListItems removeAllObjects];
        self.filteredListItems = [NSMutableArray arrayWithArray:self.itemList];
    }
}

- (IBAction)filterTable:(UISegmentedControl *)sender {
    [self reloadLocalTableData];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField{
    [self handleTextFields:textField];
    return YES;
}

- (void) handleTextFields:(UITextField *)textField{
    if (textField.superview.tag == 1 && textField.text.length > 0) {
        [self addItemFromtextField:textField];
    } else {
        [self updateItemFromtextField:textField];
    }
    [textField resignFirstResponder];
}

- (void) updateItemFromtextField:(UITextField *)textField{
    UITableViewCell *cell = (UITableViewCell *)textField.superview.superview;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    CDTDocumentRevision *item = [self.filteredListItems[indexPath.row] mutableCopy];
    item.body[PROPERTIES_FIELD][NAME_FIELD] = textField.text;
    [self updateItem:item];
}


- (void) addItemFromtextField:(UITextField *)textField{
    NSInteger priority = [self getPriorityForString:[self.segmentFilter titleForSegmentAtIndex:self.segmentFilter.selectedSegmentIndex]];
    NSString *name = textField.text;
    CDTDocumentRevision *item = [CDTDocumentRevision revision];
    
//    NSDictionary* geoDict = [self geoRepresentation];
    
    //ADD new fields to the storage here.
    
    item.body = @{
                  
                  DATATYPE_FIELD : DATATYPE_VALUE,
                  GEOLOCATION_FIELD: @{
                          TYPE_FIELD : @"Point",
                          COORDINATES_FIELD : @[
                                  [NSNumber numberWithDouble:currentLocation.coordinate.longitude],
                                  [NSNumber numberWithDouble:currentLocation.coordinate.latitude]
                                ],
                          },
                  TYPE_FIELD: @"Feature",
                  PROPERTIES_FIELD : @{
                          NAME_FIELD : name,
                          PRIORITY_FIELD : [NSNumber numberWithInteger:priority],
                          ADDRESS_FIELD : self.address.text,
//                          LATITUDE_FIELD : [NSNumber numberWithDouble:currentLocation.coordinate.latitude],
//                          LONGITUDE_FIELD : [NSNumber numberWithDouble:currentLocation.coordinate.longitude],
                      },
                  };
    
    for (id key in item.body) {
        NSLog(@"key: %@, value: %@ \n", key, [item.body objectForKey:key]);
    }
    
    [self createItem:item];
    textField.text = @"";
}

-(void) reloadLocalTableData
{
    [self filterContentForPriority:[self.segmentFilter titleForSegmentAtIndex:self.segmentFilter.selectedSegmentIndex]];
    [self.filteredListItems sortUsingComparator:^NSComparisonResult(CDTDocumentRevision* item1, CDTDocumentRevision* item2) {
        return [item1.body[NAME_FIELD] caseInsensitiveCompare:item2.body[NAME_FIELD]];
    }];
    
    [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

-(void) handleRefreshAction
{
    if(IBM_SYNC_ENABLE){
        [self pullItems];
    } else {
        [self listItems:^{
            [self.refreshControl performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:NO];
        }];
    }
}

#pragma mark CLLocationManagerDelegates Methods

-(void) locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"failed getting location %@", error);
}

-(void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    NSLog(@"Location: %@", [locations lastObject]);
    currentLocation = [locations lastObject];
    if(currentLocation!=nil) {
//        self.address.text = [NSString stringWithFormat:@"(%.8f, %.8f)", currentLocation.coordinate.latitude, currentLocation.coordinate.longitude];
        NSLog(@"%@", [NSString stringWithFormat:@"(%.8f, %.8f)", currentLocation.coordinate.latitude, currentLocation.coordinate.longitude]);
    
        [geocoder reverseGeocodeLocation:currentLocation completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
            if (error == nil && [placemarks count] > 0)
            {
                placemark = [placemarks lastObject];
            
                self.address.text = [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@",
                                     placemark.subThoroughfare?:@"", placemark.thoroughfare?:@"",
                                     placemark.locality?:@"", /*currentLocation.coordinate.latitude?:@"", currentLocation.coordinate.longitude?:@"",*/
                                     placemark.administrativeArea?:@"",
                                     placemark.postalCode?:@"", placemark.ISOcountryCode?:@""];
                
//                NSLog(@"Current country: %@", [[placemarks objectAtIndex:0] country]);
//                NSLog(@"Current country code: %@", [[placemarks objectAtIndex:0] ISOcountryCode]);
            //            NSLog(@"CountryCode=%@",GetContryCode);
            //
            //            SetContryCode
            //            setBoolForCountryCode(YES);
            //            NSLog(@"CountryCode=%@",GetContryCode);
            }
        }];
    }
}


@end
