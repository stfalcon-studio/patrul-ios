/*
 Copyright (c) 2015 - 2016. Stepan Tanasiychuk
 This file is part of Gromadskyi Patrul is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by the Free Software Found ation, version 3 of the License, or any later version.
 If you would like to use any part of this project for commercial purposes, please contact us
 for negotiating licensing terms and getting permission for commercial use. Our email address: info@stfalcon.com
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General Public License along with this program.
 If not, see http://www.gnu.org/licenses/.
 */
// https://github.com/stfalcon-studio/patrol-android/blob/master/app/build.gradle
//
//
//  HRPVideoRecordViewController.m
//  HromadskyiPatrul
//
//  Created by msm72 on 19.12.15.
//  Copyright © 2015 Monastyrskiy Sergey. All rights reserved.
//

#import "HRPVideoRecordViewController.h"
#import "HRPCollectionViewController.h"
#import "HRPViolationManager.h"


@interface HRPVideoRecordViewController ()

@end


@implementation HRPVideoRecordViewController {
    UIView *_statusView;
    
    __weak IBOutlet UILabel *_timerLabel;
}

#pragma mark - Constructors -
- (void)viewDidLoad {
    [super viewDidLoad];
    
    _cameraManager = [HRPCameraManager sharedManager];
    _cameraManager.timerLabel = _timerLabel;

    // Create violations array
    [[HRPViolationManager sharedManager] customizeManagerSuccess:^(BOOL isSuccess) {
        [self startVideoRecord];
    }];

    // Hide Back bar button
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@""
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:nil
                                                                            action:nil];
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    // Set Notification Observers
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlerStartVideoSession:)
                                                 name:@"startVideoSession"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlerMergeAndSaveVideo:)
                                                 name:@"showMergeAndSaveAlertMessage"
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    _violationLabel.hidden = YES;
    CGSize size = [[UIScreen mainScreen] bounds].size;
    
    if (UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation]) ||
        ([[UIDevice currentDevice] orientation] == UIDeviceOrientationFaceUp && size.width < size.height)) {
        _statusView = [self customizeStatusBar];
        [[UINavigationBar appearance] addSubview:_statusView];
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [_cameraManager.locationsService.manager stopUpdatingLocation];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Actions -
- (void)handlerRightBarButtonTap:(UIBarButtonItem *)sender {
    [self showLoaderWithText:NSLocalizedString(@"Close", nil)
          andBackgroundColor:BackgroundColorTypeBlue
                     forTime:100.f];
    
    sender.enabled = NO;
    [_cameraManager stopVideoSession];
    
    [[HRPViolationManager sharedManager] customizeManagerSuccess:^(BOOL isSuccess) {
        // Transition to Collection Scene
        if (self.isStartAsRecorder) {
            HRPCollectionViewController *collectionVC = [self.storyboard instantiateViewControllerWithIdentifier:@"CollectionVC"];
            _cameraManager.videoSessionMode = NSTimerVideoSessionModeStream;
            
            [self.navigationController pushViewController:collectionVC animated:YES];
            [self hideLoader];
            NSLog(@"1. CollectionVC pushed");
        }
        
        else {
            [self.navigationController popViewControllerAnimated:YES];
            [self hideLoader];
            NSLog(@"1. RecordVC poped");
        }
    }];
}


#pragma mark - NSNotification -
- (void)handlerStartVideoSession:(NSNotification *)notification {
    self.navigationItem.rightBarButtonItem.enabled = YES;
    _cameraManager.isVideoSaving = NO;
    _cameraManager.videoSessionMode = NSTimerVideoSessionModeStream;
    
    [_cameraManager startStreamVideoRecording];
    
    if (!_cameraManager.timer.isValid)
        [_cameraManager createTimer];
    
    if (self.HUD.alpha)
        [self hideLoader];
    
    self.view.userInteractionEnabled = YES;
}

- (void)handlerMergeAndSaveVideo:(NSNotification *)notification {
    _violationLabel.text = nil;
    _violationLabel.isLabelFlashing = NO;
    
    [self showLoaderWithText:NSLocalizedString(@"Merge & Save video", nil)
          andBackgroundColor:BackgroundColorTypeBlue
                     forTime:300];
}


#pragma mark - UIGestureRecognizer -
- (IBAction)tapGesture:(id)sender {
    if ([_cameraManager.locationsService isEnabled]) {
        _cameraManager.locationsService.manager.delegate = _cameraManager;
        
        [_cameraManager.locationsService.manager startUpdatingLocation];
        
        if (_cameraManager.videoSessionMode == NSTimerVideoSessionModeStream && !_cameraManager.isVideoSaving) {
            _violationLabel.hidden = NO;
            _violationLabel.text = NSLocalizedString(@"Violation", nil);
            _cameraManager.isVideoSaving = YES;
            _cameraManager.videoSessionMode = NSTimerVideoSessionModeViolation;
            _cameraManager.violationTime = [_cameraManager getCurrentTimerValue];
            _cameraManager.sessionDuration = _cameraManager.violationTime + 10;
            self.navigationItem.rightBarButtonItem.enabled = NO;
            
            [_violationLabel startFlashing];
            self.view.userInteractionEnabled = NO;
        }
    }
}


#pragma mark - Methods -
- (void)startVideoRecord {
    [_cameraManager removeMediaSnippets];
    [_cameraManager.locationsService.manager startUpdatingLocation];
    
    // Set View frame
    self.view.frame = [UIScreen mainScreen].bounds;
    
    [self showLoaderWithText:NSLocalizedString(@"Start a Video", nil)
          andBackgroundColor:BackgroundColorTypeBlue
                     forTime:2];
    
    [self customizeNavigationBarWithTitle:NSLocalizedString(@"Record a Video", nil)
                    andLeftBarButtonImage:[UIImage new]
                        withActionEnabled:NO
                   andRightBarButtonImage:[UIImage imageNamed:@"icon-action-close"]
                        withActionEnabled:YES];
    
    //    [_cameraManager readPhotosCollectionFromFile];
    _cameraManager.violations = [HRPViolationManager sharedManager].violations;
    _cameraManager.images = [HRPViolationManager sharedManager].images;
    [_cameraManager createCaptureSession];
    
    //Preview Layer
    _cameraManager.videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_cameraManager.captureSession];
    [_cameraManager.videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [_cameraManager setVideoPreviewLayerOrientation:self.view.frame.size];
    
    [self.view.layer setMasksToBounds:YES];
    [self.view layoutIfNeeded];
    
    [self.view.layer insertSublayer:_cameraManager.videoPreviewLayer below:_violationLabel.layer];
    
    [self customizeViewStyle];
    
    _cameraManager.videoSessionMode = NSTimerVideoSessionModeStream;
    
    [_cameraManager.captureSession startRunning];
    [_cameraManager startStreamVideoRecording];
    self.view.userInteractionEnabled = YES;
}

- (void)customizeViewStyle {
    _violationLabel.hidden = YES;
    
    if (!_cameraManager.timer)
        [_cameraManager createTimer];
}


#pragma mark - UIViewControllerRotation -
- (BOOL)shouldAutorotate {
    return (_cameraManager.videoSessionMode == NSTimerVideoSessionModeStream);
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    if (UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation]) ||
        ([[UIDevice currentDevice] orientation] == UIDeviceOrientationFaceUp && size.width < size.height)) {
        _statusView = [self customizeStatusBar];
        [[UINavigationBar appearance] addSubview:_statusView];
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
    }
    
    else {
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
    }
    
    [_cameraManager setVideoPreviewLayerOrientation:size];

    if (_cameraManager.videoSessionMode == NSTimerVideoSessionModeStream) {
        [_cameraManager stopVideoRecording];
        [_cameraManager removeMediaSnippets];
        
        // Stop Timer
        [_cameraManager.timer invalidate];
        _cameraManager.timer = nil;
    }
    
    // Restart Timer only in Stream Video mode
    if (_cameraManager.videoSessionMode == NSTimerVideoSessionModeStream && !_cameraManager.isVideoSaving) {
        _cameraManager.videoSessionMode = NSTimerVideoSessionModeStream;
    }
}

@end
