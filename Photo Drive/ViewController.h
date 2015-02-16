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

@interface ViewController : UIViewController

@property (nonatomic, retain) NSNumber *numAssets;
@property (nonatomic, retain) NSNumber *numUploadedAssets;

@property (nonatomic, retain) GTLServiceDrive *driveService;
@property (nonatomic, retain) NSString *folderIdentifier;

@property (atomic, retain) ALAssetsLibrary *assetLibrary;
@property (atomic, retain) NSMutableArray *assetQueue;
@property (atomic, retain) NSUserDefaults *defaults;

@property (atomic, retain) NSNumber *threads;
@property (atomic, retain) NSCondition *syncLock;
@property (atomic) BOOL isSyncing;
@property (atomic) BOOL autoBackupOn;

@property (nonatomic, retain) NSDateFormatter *dateFormat;

@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UISwitch *autoBackupSwitch;
@property (weak, nonatomic) IBOutlet UIButton *backupButton;
@property (weak, nonatomic) IBOutlet UILabel *uplodadedAssetsLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalAssetsLabel;

- (IBAction)initBackup:(id)sender;
- (IBAction)autoBackupToggled:(id)sender;

@end

