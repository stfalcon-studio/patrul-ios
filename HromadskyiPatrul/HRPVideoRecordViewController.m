
//  HRPVideoRecordViewController.m
//  HromadskyiPatrul
//
//  Created by msm72 on 04.09.15.
//  Copyright (c) 2015 Monastyrskiy Sergey. All rights reserved.
//


#import "HRPVideoRecordViewController.h"
#import "HRPCameraManager.h"
#import "UIColor+HexColor.h"
#import "HRPButton.h"
#import "HRPCollectionViewController.h"


typedef NS_ENUM (NSInteger, HRPVideoRecordViewControllerMode) {
    HRPVideoRecordViewControllerModeStreamVideo,
    HRPVideoRecordViewControllerModeAttentionVideo,
    HRPVideoRecordViewControllerModeDismissed
};


@interface HRPVideoRecordViewController ()

@property (assign, nonatomic) HRPVideoRecordViewControllerMode recordingMode;

@property (strong, nonatomic) IBOutlet UIView *statusView;
@property (strong, nonatomic) IBOutlet UIView *videoView;
@property (strong, nonatomic) IBOutlet HRPButton *controlButton;
@property (strong, nonatomic) IBOutlet UILabel *controlLabel;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *statusViewVerticalSpaceConstraint;
@property (strong, nonatomic) IBOutlet UILabel *timerLabel;

@end


@implementation HRPVideoRecordViewController {
    HRPCameraManager *_cameraManager;
    NSTimer *_timerVideo;

    NSInteger _timerSeconds;
    BOOL _isControlLabelFlashing;

}

#pragma mark - Constructors -
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create camera manager
    _cameraManager                                          =   [HRPCameraManager sharedManager];

    // Set items
    _controlLabel.text                                      =   nil; //NSLocalizedString(@"Attention", nil);
    
    // Set Notification Observers
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUserLogout:)
                                                 name:@"HRPSettingsViewControllerUserLogout"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlerStartVideoSession:)
                                                 name:@"startVideoSession"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlerStartRecordingVideoFile:)
                                                 name:@"didStartRecordingToOutputFileAtURL"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlerFinishRecordingVideoFile:)
                                                 name:@"didFinishRecordingToOutputFileAtURL"
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self showLoaderWithText:NSLocalizedString(@"Start a Video", nil)
          andBackgroundColor:BackgroundColorTypeBlue];

    _recordingMode                                          =   HRPVideoRecordViewControllerModeStreamVideo;

    // Set Status Bar
    UIView *statusBarView                                   =  [[UIView alloc] initWithFrame:CGRectMake(0.f, -20.f, CGRectGetWidth(self.view.frame), 20.f)];
    statusBarView.backgroundColor                           =  [UIColor colorWithHexString:@"0477BD" alpha:1.f];
    [self.navigationController.navigationBar addSubview:statusBarView];

    _timerVideo                                             =   nil;
    _timerSeconds                                           =   0;
    _timerLabel.text                                        =   @"00:00:00";
    _controlButton.enabled                                  =   YES;
    _isControlLabelFlashing                                 =   NO;
    self.navigationItem.title                               =   NSLocalizedString(@"Record a Video", nil);
    
    // Start new camera video & audio session
    [_cameraManager removeAllFolderMediaTempFiles];
    [_cameraManager readAllFolderFile];
    
    [_cameraManager startVideoSession];
    [_videoView.layer insertSublayer:_cameraManager.videoPreviewLayer below:_controlButton.layer];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.HUD.alpha)
        [self hideLoader];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    _recordingMode                                          =   HRPVideoRecordViewControllerModeDismissed;
    
    [_cameraManager stopVideoSession];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - UIViewControllerRotation -
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator {
    _statusViewVerticalSpaceConstraint.constant         =   ([[UIApplication sharedApplication] statusBarOrientation] ==
                                                             UIInterfaceOrientationPortrait) ? 0.f : -20.f;

    [_cameraManager.captureSession beginConfiguration];
    [_cameraManager setVideoSessionOrientation];
    [_cameraManager.captureSession commitConfiguration];

    if (!_cameraManager.isVideoSaving && !_isControlLabelFlashing) {
        [self showLoaderWithText:NSLocalizedString(@"Start a Video", nil)
              andBackgroundColor:BackgroundColorTypeBlue];
        
        [_cameraManager restartStreamVideoRecording];
        
        [_timerVideo invalidate];
        _timerSeconds                                       =   0;
        _timerVideo                                         =   [self createTimer];
    }
}


#pragma mark - Actions -
- (IBAction)actionControlButtonTap:(HRPButton *)sender {
    if (_recordingMode == HRPVideoRecordViewControllerModeStreamVideo) {
        _controlLabel.text                                  =   NSLocalizedString(@"Violation", nil);
        _cameraManager.isVideoSaving                        =   YES;
        self.navigationItem.rightBarButtonItem.enabled      =   NO;
        
        [self startControlLabelFlashing];
        [self startAttentionVideoRecording];
    }
}


#pragma mark - NSNotification -
- (void)handleUserLogout:(NSNotification *)notification {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)handlerStartVideoSession:(NSNotification *)notification {
    if (self.HUD.alpha)
        [self hideLoader];
    
    [_cameraManager.captureSession beginConfiguration];
    [_cameraManager setVideoSessionOrientation];
    [_cameraManager.captureSession commitConfiguration];
    
    [_cameraManager startStreamVideoRecording];
    
    _timerVideo                                             =   [self createTimer];
    self.navigationItem.rightBarButtonItem.enabled          =   YES;
    _cameraManager.isVideoSaving                            =   NO;
    _isControlLabelFlashing                                 =   NO;
}

- (void)handlerStartRecordingVideoFile:(NSNotification *)notification {
    if (self.HUD.alpha)
        [self hideLoader];

    if (!_timerSeconds)
        _timerSeconds                                       =   0;
    
    if (!_timerVideo)
        _timerVideo                                         =   [self createTimer];
}

- (void)handlerFinishRecordingVideoFile:(NSNotification *)notification {
    // START Button taped
    if (self.recordingMode == HRPVideoRecordViewControllerModeStreamVideo) {
        _cameraManager.snippetNumber                        =   (_cameraManager.snippetNumber == 0) ? 1 : 0;
        
        [_cameraManager stopAudioRecording];
        [_cameraManager startStreamVideoRecording];
        
        // Delete media snippets_1
        if (_cameraManager.snippetNumber == 0)
            [_cameraManager removeMediaSnippets];
    }
    
    // ATTENTION Button taped
    else if (self.recordingMode == HRPVideoRecordViewControllerModeAttentionVideo) {
        // Get first video frame image
        if (_cameraManager.snippetNumber == 2) {
            [self showLoaderWithText:NSLocalizedString(@"Merge & Save video", nil)
                  andBackgroundColor:BackgroundColorTypeBlue];

            _controlLabel.text                              =   nil;
            
            _cameraManager.snippetNumber                    =   0;
            [_cameraManager stopAudioRecording];
            
            NSString *videoFilePath                         =   [_cameraManager.mediaFolderPath stringByAppendingPathComponent:_cameraManager.videoFilesNames[2]];
            NSURL *videoFileURL                             =   [NSURL fileURLWithPath:videoFilePath];
            _recordingMode                                  =   HRPVideoRecordViewControllerModeStreamVideo;
            
            [_cameraManager extractFirstFrameFromVideoFilePath:videoFileURL];
        }
        
        else {
            _cameraManager.snippetNumber                    =   2;
            
            [_cameraManager stopAudioRecording];
            [_cameraManager startStreamVideoRecording];
        }
    }
}


#pragma mark - UIGestureRecognizer -
- (IBAction)tapGesture:(id)sender {
    if (!_cameraManager.isVideoSaving || !_isControlLabelFlashing)
        [self actionControlButtonTap:_controlButton];
}

    
#pragma mark - Methods -
- (void)startControlLabelFlashing {
    if (_isControlLabelFlashing)
        return;
    
    _isControlLabelFlashing                                 =   YES;
    self.controlLabel.alpha                                 =   1.f;
    
    [UIView animateWithDuration:0.10f
                          delay:0.f
                        options:UIViewAnimationOptionCurveEaseInOut |
                                UIViewAnimationOptionRepeat         |
                                UIViewAnimationOptionAutoreverse    |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         self.controlLabel.alpha            =   0.f;
                     }
                     completion:nil];
}

- (void)startAttentionVideoRecording {
    // Stop video capture and make the capture session object nil
    _timerSeconds                                           =   0;
    _recordingMode                                          =   HRPVideoRecordViewControllerModeAttentionVideo;
    
    [_cameraManager.videoFileOutput stopRecording];
}

- (NSTimer *)createTimer {
    return [NSTimer scheduledTimerWithTimeInterval:1.f
                                            target:self
                                          selector:@selector(timerTicked:)
                                          userInfo:nil
                                           repeats:YES];
}

- (void)timerTicked:(NSTimer *)timer {
    _timerSeconds++;
    
    if (_timerSeconds == _cameraManager.sessionDuration) {
        if (_recordingMode == HRPVideoRecordViewControllerModeStreamVideo)
            _timerSeconds                                   =   0;
        
        else {
            [_timerVideo invalidate];
            _timerSeconds                                   =   0;
        }
        
        [_cameraManager.videoFileOutput stopRecording];
    }
    
    _timerLabel.text                                        =   [self formattedTime:_timerSeconds];
}

- (NSString *)formattedTime:(NSInteger)secondsTotal {
    NSInteger seconds                                       =   secondsTotal % 60;
    NSInteger minutes                                       =   (secondsTotal / 60) % 60;
    NSInteger hours                                         =   secondsTotal / 3600;
    
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
}

- (void)showAlertViewWithTitle:(NSString *)titleText andMessage:(NSString *)messageText {
   [[[UIAlertView alloc] initWithTitle:titleText
                               message:messageText
                              delegate:nil
                     cancelButtonTitle:nil
                     otherButtonTitles:NSLocalizedString(@"Alert error button Ok", nil), nil] show];
}
                                                           

#pragma mark - UITextFieldDelegate -
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    return YES;
}

@end