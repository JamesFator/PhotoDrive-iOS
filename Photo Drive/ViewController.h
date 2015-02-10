//
//  ViewController.h
//  Photo Drive
//
//  Created by James Fator on 2/9/15.
//  Copyright (c) 2015 JamesFator. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLDrive.h"

@interface ViewController : UINavigationController

@property (nonatomic, retain) GTLServiceDrive *driveService;
@property (nonatomic, retain) NSString *folderIdentifier;

@property (atomic, retain) ALAssetsLibrary *assetLibrary;
@property (atomic, retain) NSMutableArray *assetQueue;
@property (atomic, retain) NSUserDefaults *defaults;

@property (atomic, retain) NSNumber *threads;
@property (atomic, retain) NSCondition *syncLock;
@property (atomic) BOOL isSyncing;

@property (nonatomic, retain) NSDateFormatter *dateFormat;

@end

