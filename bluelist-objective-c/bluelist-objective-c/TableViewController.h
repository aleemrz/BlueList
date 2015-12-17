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

#import <UIKit/UIKit.h>
#import <CloudantSync.h>
#import <IMFCore/IMFCore.h>
#import <CloudantSync.h>
#import <CloudantSyncEncryption.h>
#import <CoreLocation/CoreLocation.h>


@interface TableViewController : UITableViewController
#define DATATYPE_FIELD @"@datatype"
#define DATATYPE_VALUE @"TodoItem"
#define DELETED_VALUE @"deleted"


#define NAME_FIELD @"name"
#define PRIORITY_FIELD @"priority"
#define ADDRESS_FIELD @"address"
#define LATITUDE_FIELD @"latitude"
#define LONGITUDE_FIELD @"longitude"
#define DELETED_FIELD @"deleted"
#define USER_ID @"userid"

//GEO FIELDS FOR INDEXING IN DB

#define GEOLOCATION_FIELD @"geometry"
#define COORDINATES_FIELD @"coordinates"
#define TYPE_FIELD @"type"
#define PROPERTIES_FIELD @"properties"

@property NSString *dbName;
@property NSURL *remotedatastoreurl;
@property id<CDTHTTPInterceptor> cloudantHttpInterceptor;
@property (weak, nonatomic) IBOutlet UILabel *address;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;


@end
