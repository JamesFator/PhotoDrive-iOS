//
//  ViewController.m
//  Photo Drive
//
//  Created by James Fator on 2/9/15.
//  Copyright (c) 2015 JamesFator. All rights reserved.
//

#import "ViewController.h"

static NSString *const kPhotosFolder = @"Phone_Upload";
static NSString *const kAutoCompleteOn = @"kAutoCompleteOn";
static NSString *const kCompleted = @"kCompleted";
static NSString *const kKeychainItemName = @"Photo Drive";
static NSString *const kClientID = @"CLIENT_ID";
static NSString *const kClientSecret = @"CLIENT_SECRET";

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _defaults = [NSUserDefaults standardUserDefaults];
    _autoBackupOn = [_defaults boolForKey:kAutoCompleteOn];
    [_autoBackupSwitch setOn:_autoBackupOn];
    [_backupButton setHidden:_autoBackupOn];
    
    // Initialize the drive service & load existing credentials from the keychain if available
    _driveService = [[GTLServiceDrive alloc] init];
    _driveService.authorizer = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                         clientID:kClientID
                                                                                     clientSecret:kClientSecret];
    
    _syncLock = [[NSCondition alloc] init];
    _isSyncing = NO;
    
    _dateFormat = [[NSDateFormatter alloc] init];
    [_dateFormat setDateFormat:@"YYYY-MM-dd HH.mm.ss"];
    
    _numAssets = @0;
    _numUploadedAssets = @0;
    
    [_totalAssetsLabel setText:[_numAssets stringValue]];
    [_uplodadedAssetsLabel setText:[_numUploadedAssets stringValue]];
    
    [_progressView  setProgress:0.0];
    
    _assetQueue = [[NSMutableArray alloc] init];
    _assetLibrary = [[ALAssetsLibrary alloc] init];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    if (![self isAuthorized]) {
        // Request authorization
        [self presentViewController:[self createAuthController] animated:YES completion:nil];
    } else {
        if (_autoBackupOn) {
            // Start the sync
            [self initBackup:self];
        }
    }
}

// Helper to check if user is authorized
- (BOOL)isAuthorized
{
    return [((GTMOAuth2Authentication *)_driveService.authorizer) canAuthorize];
}

// Creates the auth controller for authorizing access to Google Drive.
- (GTMOAuth2ViewControllerTouch *)createAuthController
{
    GTMOAuth2ViewControllerTouch *authController;
    authController = [[GTMOAuth2ViewControllerTouch alloc] initWithScope:kGTLAuthScopeDriveFile
                                                                clientID:kClientID
                                                            clientSecret:kClientSecret
                                                        keychainItemName:kKeychainItemName
                                                                delegate:self
                                                        finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    return authController;
}

// Handle completion of the authorization process, and updates the Drive service
// with the new credentials.
- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)authResult
                 error:(NSError *)error
{
    if (error != nil)
    {
        [self showAlert:@"Authentication Error" message:error.localizedDescription];
        _driveService.authorizer = nil;
    } else {
        _driveService.authorizer = authResult;
        if (_autoBackupOn) {
            [self initBackup:self];
        }
    }
}

- (IBAction)initBackup:(id)sender
{
    @synchronized(self) {
        if (_isSyncing) {
            return;
        }
        _isSyncing = YES;
        NSLog(@"BEGINNING SYNC.");
    }
    
    if (!_folderIdentifier) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Initialize the folder and acquire it's identifier before we move on
            [self getFolderId];
        });
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Wait for the identifier
        while(!_folderIdentifier) {
            [NSThread sleepForTimeInterval:0.01];
        }
        // Identifier acquired
        [self getAssets];
    });
}

- (void)getFolderId
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Checking for existing folder.");
        NSString *parentId = @"root";
        
        GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];
        query.q = [NSString stringWithFormat:@"'%@' in parents", parentId];
        [_driveService executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                                  GTLDriveFileList *files,
                                                                  NSError *error) {
            if (error == nil) {
                for (GTLDriveFile *child in files.items) {
                    if ([child.title isEqualToString:kPhotosFolder]) {
                        _folderIdentifier = [NSString stringWithString:child.identifier];
                        return;
                    }
                }
                // We need to create the folder
                NSLog(@"Folder not found.");
                [self createFolder];
            } else {
                NSLog(@"An error occurred: %@", error);
                return;
            }
        }];
    });
}

- (void)createFolder
{
    NSLog(@"Creating folder.");
    GTLDriveFile *folder = [GTLDriveFile object];
    folder.title = kPhotosFolder;
    folder.mimeType = @"application/vnd.google-apps.folder";
    
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:folder uploadParameters:nil];
    [_driveService executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                              GTLDriveFile *updatedFile,
                                                              NSError *error) {
        if (error == nil) {
            NSLog(@"Folder created.");
            _folderIdentifier = updatedFile.identifier;
        } else {
            NSLog(@"An error occurred: %@", error);
        }
    }];

}

- (void)getAssets
{
    _numUploadedAssets = @0;
    _numAssets = @0;
    [_assetLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
        usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            [group enumerateAssetsUsingBlock:^(ALAsset *asset, NSUInteger index, BOOL *stop) {
                if (asset) {
                    _numAssets = [NSNumber numberWithInt:_numAssets.intValue + 1];
                    NSString *filename = [[asset defaultRepresentation] filename];
                    __block BOOL previouslyBackup;
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        previouslyBackup = [_defaults boolForKey:filename];
                    });
                    if (!previouslyBackup) {
                        [_assetQueue addObject:[asset valueForProperty:ALAssetPropertyAssetURL]];
                    } else {
                        _numUploadedAssets = [NSNumber numberWithInt:_numUploadedAssets.intValue + 1];
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_totalAssetsLabel setText:[_numAssets stringValue]];
                    [_uplodadedAssetsLabel setText:[_numUploadedAssets stringValue]];
                    NSLog(@"Progress: %f", _numUploadedAssets.doubleValue / _numAssets.doubleValue);
                    [_progressView  setProgress:_numUploadedAssets.doubleValue / _numAssets.doubleValue];
                });
            }];
            dispatch_async(dispatch_get_main_queue(), ^{
                [_totalAssetsLabel setText:[NSString stringWithFormat:@"%d", _numAssets.intValue]];
                [_uplodadedAssetsLabel setText:[NSString stringWithFormat:@"%d", _numUploadedAssets.intValue]];
            });
            [self uploadAssets];
        } failureBlock:^(NSError *error) {
            if (error.code == ALAssetsLibraryAccessUserDeniedError) {
                NSLog(@"user denied access, code: %i",error.code);
            } else {
                NSLog(@"Other error code: %i",error.code);
            }
            @synchronized(self) {
                // Cannot continue without access to the assets
                _isSyncing = NO;
                NSLog(@"ENDING SYNC.");
            }
        }];
}

- (void)uploadAssets
{
    while (TRUE) {
        [_syncLock lock];
        if ([_assetQueue count] == 0) {
            [_syncLock unlock];
            break;
        }
        
        int maxThreads = MIN(5, [_assetQueue count]);
        _threads = [NSNumber numberWithInt:maxThreads];
        
        @synchronized(_threads) {
            for (; _threads.intValue > 0; ) {
                __block int thread;
                @synchronized(_threads) {
                    _threads = [NSNumber numberWithInt:_threads.intValue - 1];
                    thread = _threads.intValue;
                }
                // Spawn new thread to perform the uploading
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // Get the asset from it's URL
                    [_assetLibrary assetForURL:[_assetQueue objectAtIndex:thread]
                        resultBlock:^(ALAsset *asset) {
                            [self uploadAsset:asset];
                        } failureBlock:^(NSError *error) {
                            NSLog(@"Error retreiving asset from URL: %i", error.code);
                            @synchronized(_threads) {
                                _threads = [NSNumber numberWithInt:_threads.intValue + 1];
                            }
                            [_syncLock signal];
                        }];
                });
            }
        }
        // Wait until the upload threads complete
        while (_threads.intValue < maxThreads) {
            [_syncLock wait];
        }
        // Pop the last asset off the queue and loop
        for (int t = 0; t < maxThreads; t++) {
            _numUploadedAssets = [NSNumber numberWithInt:_numUploadedAssets.intValue + 1];
            [_progressView  setProgress:_numUploadedAssets.doubleValue / _numAssets.doubleValue];
            [_assetQueue removeObjectAtIndex:0];
        }
        [_syncLock unlock];
    }
    
    @synchronized(self) {
        // No more assets to upload. Scheduled completion.
        _isSyncing = NO;
        NSLog(@"ENDING SYNC.");
    }
}

- (void)uploadAsset:(ALAsset*)asset
{
    ALAssetRepresentation *imgRep = [asset defaultRepresentation];
    __block NSString *filename = [NSString stringWithString:[imgRep filename]];
    NSString *fileType = [filename substringFromIndex:[filename length] - 4];
    NSString *assetTitle = [_dateFormat stringFromDate:[asset valueForProperty:ALAssetPropertyDate]];
    assetTitle = [NSString stringWithFormat:@"%@%@", assetTitle, fileType];
    
    Byte *buffer = (Byte*)malloc((unsigned long)imgRep.size);
    NSUInteger buffered = [imgRep getBytes:buffer fromOffset:0.0 length:(unsigned long)imgRep.size error:nil];
    NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
    
    GTLDriveFile *file = [GTLDriveFile object];
    file.title = assetTitle;
    
    GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
    parentRef.identifier = _folderIdentifier;
    file.parents = @[parentRef];
    
    GTLUploadParameters *uploadParameters = [GTLUploadParameters uploadParametersWithData:data
                                                                                 MIMEType:file.mimeType];
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:file
                                                       uploadParameters:uploadParameters];
    
    
    [_driveService executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                          GTLDriveFile *insertedFile,
                                                          NSError *error) {
        if (error == nil) {
            NSLog(@"Uploaded %@", filename);
            [_defaults setBool:YES forKey:filename];
            [_defaults synchronize];
        } else {
            NSLog(@"An error occurred: %@", error);
        }
        // Signal previous thread that we're all set
        @synchronized(_threads) {
            _threads = [NSNumber numberWithInt:_threads.intValue + 1];
        }
        [_syncLock signal];
    }];
}

// Helper for showing an alert
- (void)showAlert:(NSString *)title message:(NSString *)message
{
    UIAlertView *alert;
    alert = [[UIAlertView alloc] initWithTitle: title
                                       message: message
                                      delegate: nil
                             cancelButtonTitle: @"OK"
                             otherButtonTitles: nil];
    [alert show];
}

- (IBAction)autoBackupToggled:(id)sender
{
    _autoBackupOn = [_autoBackupSwitch isOn];
    [_backupButton setHidden:_autoBackupOn];
    @synchronized(_defaults) {
        [_defaults setBool:_autoBackupOn forKey:kAutoCompleteOn];
        [_defaults synchronize];
    }
}
@end
