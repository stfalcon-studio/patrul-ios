//
//  HRPVideoRecordViewController.m
//  HromadskyiPatrul
//
//  Created by msm72 on 04.09.15.
//  Copyright (c) 2015 Monastyrskiy Sergey. All rights reserved.
//


#import "HRPVideoRecordViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIColor+HexColor.h"
#import "HRPButton.h"
#import "MBProgressHUD.h"

typedef enum : NSUInteger {
    HRPVideoRecordViewControllerModeStreamVideo,
    HRPVideoRecordViewControllerModeAttentionVideo
} HRPVideoRecordViewControllerMode;


@interface HRPVideoRecordViewController () <AVCaptureFileOutputRecordingDelegate, AVAudioRecorderDelegate, AVAudioPlayerDelegate>

@property (assign, nonatomic) HRPVideoRecordViewControllerMode recordingMode;

@property (strong, nonatomic) IBOutlet UIView *statusView;
@property (strong, nonatomic) IBOutlet UIView *videoView;
@property (strong, nonatomic) IBOutlet UIView *testTopView;

@property (strong, nonatomic) IBOutlet HRPButton *controlButton;
@property (strong, nonatomic) IBOutlet UILabel *controlLabel;
@property (strong, nonatomic) IBOutlet UIButton *resetButton;

@property (strong, nonatomic) IBOutlet NSLayoutConstraint *statusViewVerticalSpaceConstraint;

@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureConnection *videoConnection;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (strong, nonatomic) AVCaptureMovieFileOutput *videoFileOutput;
@property (strong, nonatomic) AVAudioRecorder *audioRecorder;
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;
@property (strong, nonatomic) AVAudioSession *audioSession;
@property (strong, nonatomic) AVMutableComposition *composition;

@property (strong, nonatomic) IBOutlet UILabel *timerLabel;

- (void)startStreamVideoRecording;
- (void)startAttentionVideoRecording;

@end


@implementation HRPVideoRecordViewController {
    MBProgressHUD *progressHUD;

    NSTimer *timerVideo;
    NSString *mediaFolderPath;
    NSInteger timerSeconds;
    NSInteger snippetNumber;
    NSInteger sessionDuration;
    UIImage *videoImageOriginal;
    NSArray *videoFilesNames;
    NSArray *audioFilesNames;
    NSDictionary *audioRecordSettings;
}

#pragma mark - Constructors -
- (void)viewDidLoad {
    [super viewDidLoad];

    // NSLog(@"self.statusView.bounds 0 = %@", NSStringFromCGRect(self.statusView.frame));
    
    // Set Session Duration
    sessionDuration                                     =   7;
    
    // Test Top View
    self.testTopView.alpha                              =   1.f;
    
    // App Folder
    mediaFolderPath                                     =   [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];

    // Set Media session parameters
    snippetNumber                                       =   0;
    videoFilesNames                                     =   @[@"snippet_video_0.mp4", @"snippet_video_1.mp4", @"snippet_video_2.mp4"];
    audioFilesNames                                     =   @[@"snippet_audio_0.caf", @"snippet_audio_1.caf", @"snippet_audio_2.caf"];
    self.recordingMode                                  =   HRPVideoRecordViewControllerModeStreamVideo;
    
    audioRecordSettings                                 =   [NSDictionary dictionaryWithObjectsAndKeys:
                                                                [NSNumber numberWithInt:kAudioFormatLinearPCM],     AVFormatIDKey,
                                                                [NSNumber numberWithInt:AVAudioQualityMax],         AVEncoderAudioQualityKey,
                                                                [NSNumber numberWithInt:32],                        AVEncoderBitRateKey,
                                                                [NSNumber numberWithInt:2],                         AVNumberOfChannelsKey,
                                                                [NSNumber numberWithFloat:44100.f],                 AVSampleRateKey, nil];

    // Create ProgressHUD
    progressHUD                                         =   [[MBProgressHUD alloc] init];

//    [self deleteFolder];
    [self readAllFolderFile];
    
    // Set items
//    self.controlButton.tag                              =   0;
//    self.controlLabel.text                              =   NSLocalizedString(@"Start", nil);
    self.timerLabel.text                                =   @"00:00:00";
    
    [self.resetButton setTitle:NSLocalizedString(@"Cancel", nil) forState:UIControlStateNormal];
    
    // Start new camera video & audio session
    [self startCameraSession];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Set Landscape orientation
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationLandscapeLeft]
                                forKey:@"orientation"];
    
    [self startStreamVideoRecording];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Remove the video preview layer from the viewPreview view's layer.
    [self.captureSession stopRunning];
    [self.videoPreviewLayer removeFromSuperlayer];

    self.videoPreviewLayer                              =   nil;
    self.captureSession                                 =   nil;
    self.videoFileOutput                                =   nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - UIViewControllerRotation -
- (BOOL)shouldAutorotate {
    AVCaptureVideoOrientation newOrientation;
    
    self.videoPreviewLayer.frame                        =   self.videoView.bounds;
    
    self.statusViewVerticalSpaceConstraint.constant     =   ([[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationPortrait) ?
                                                            0.f : -20.f;
    
    switch ([[UIDevice currentDevice] orientation]) {
        case UIDeviceOrientationPortrait:
            newOrientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            newOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft:
            newOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight:
            [self.videoView.layer setAffineTransform:CGAffineTransformIdentity];
            break;
        default:
            newOrientation = AVCaptureVideoOrientationPortrait;
    }
    
    self.videoPreviewLayer.connection.videoOrientation  =   newOrientation;

    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscape;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return [[UIApplication sharedApplication] statusBarOrientation];
}


#pragma mark - Actions -
- (IBAction)actionControlButtonTap:(HRPButton *)sender {
    [self startAttentionVideoRecording];
}

/* TESTED
- (IBAction)actionControlButtonTap:(HRPButton *)sender {
    [UIView animateWithDuration:0.05f
                     animations:^{
                         sender.fillColor               =   [UIColor colorWithHexString:@"05A9F4" alpha:0.4f];
                         sender.borderColor             =   [UIColor colorWithHexString:@"FF464D" alpha:0.4f];
                     } completion:^(BOOL finished) {
                         sender.fillColor               =   [UIColor colorWithHexString:@"05A9F4" alpha:0.8f];
                         sender.borderColor             =   [UIColor colorWithHexString:@"FF464D" alpha:0.8f];
                     }];
    
    // Start record stream video & audio session
    if (sender.tag == 0) {
        self.controlLabel.text                          =   NSLocalizedString(@"Attention", nil);
        sender.tag                                      =   1;
        
        [self startStreamVideoWithAudioRecord];
    }
    
    // Start record attention video & audio session
    else if (sender.tag == 1) {
        sender.tag                                      =   0;
        
        [self startAttentionVideoRecord];
    }
}
*/

- (IBAction)actionResetButtonTap:(UIButton *)sender {
    [self.captureSession stopRunning];
    [self.videoFileOutput stopRecording];
    [self removeAllFolderMediaTempFiles];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

// TEST
- (IBAction)actionTest:(UIButton *)sender {
    [self readAllFolderFile];
}

- (IBAction)actionDELETE:(id)sender {
    [self removeAllFolderMediaTempFiles];
    [self readAllFolderFile];
}

- (IBAction)actiomMERGE:(id)sender {
    [self mergeAndSaveVideoFile];
}

- (IBAction)actionPLAY:(id)sender {
    if (!_audioRecorder.recording) {
        NSError *error;
        
        if (self.textField.text.length > 0)
            snippetNumber = [self.textField.text integerValue];
        
        _audioRecorder                  =   [[AVAudioRecorder alloc] initWithURL:[self setNewAudioFileURL:snippetNumber]
                                                                        settings:audioRecordSettings
                                                                           error:&error];
        
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:_audioRecorder.url error:&error];
        _audioPlayer.delegate = self;
        [_audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
        
        if (error)
            NSLog(@"Error: %@", [error localizedDescription]);
        
        else [_audioPlayer play];
    }
}


#pragma mark - UIGestureRecognizer -
- (IBAction)tapGesture:(id)sender {
    [self.textField resignFirstResponder];
}

    
#pragma mark - Methods -
- (void)startCameraSession {
    NSError *error;
    
    // Initialize the Session object
    self.captureSession                                 =   [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset                   =   AVCaptureSessionPresetHigh;

    // Initialize a Camera object
    AVCaptureDevice *videoDevice                        =   [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *videoInput                    =   [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    self.videoConnection                                =   [self.videoFileOutput connectionWithMediaType:AVMediaTypeVideo];
    AVCaptureVideoStabilizationMode stabilizationMode   =   AVCaptureVideoStabilizationModeCinematic;
    
    if ([videoDevice.activeFormat isVideoStabilizationModeSupported:stabilizationMode])
        [self.videoConnection setPreferredVideoStabilizationMode:stabilizationMode];
    
    [self.captureSession addInput:videoInput];
    
    // VIDEO
    // Add output file
    self.videoFileOutput                                =   [[AVCaptureMovieFileOutput alloc] init];

    if ([self.captureSession canAddOutput:self.videoFileOutput])
        [self.captureSession addOutput:self.videoFileOutput];
    
    // Initialize the video preview layer
    self.videoPreviewLayer                              =   [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [self.videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [self.videoPreviewLayer setFrame:self.videoView.layer.bounds];
   
    [self.videoView.layer insertSublayer:self.videoPreviewLayer below:self.controlButton.layer];
    [self.captureSession startRunning];
}

- (void)startAudioRecording {
    if (!_audioRecorder.recording) {
        [self setNewAudioRecorder];
        
        [_audioRecorder record];
    }
}

- (void)startStreamVideoRecording {
    [self startAudioRecording];
    [self.videoFileOutput startRecordingToOutputFileURL:[self setNewVideoFileURL:snippetNumber] recordingDelegate:self];
}

- (void)startAttentionVideoRecording {
    // Stop video capture and make the capture session object nil
    timerSeconds                                        =   0;
    self.controlButton.userInteractionEnabled           =   NO;
    self.recordingMode                                  =   HRPVideoRecordViewControllerModeAttentionVideo;
    
    [self.videoFileOutput stopRecording];
}

- (void)stopAudioRecording {
    if (_audioRecorder.recording)
        [_audioRecorder stop];
}

- (NSURL *)setNewVideoFileURL:(NSInteger)count {
    NSString *videoFilePath                             =   [mediaFolderPath stringByAppendingPathComponent:videoFilesNames[count]];
    NSURL *videoFileURL                                 =   [NSURL fileURLWithPath:videoFilePath];
    
    return videoFileURL;
}

- (NSURL *)setNewAudioFileURL:(NSInteger)count {
    NSString *audioFilePath                             =   [mediaFolderPath stringByAppendingPathComponent:audioFilesNames[count]];
    NSURL *audioFileURL                                 =   [NSURL fileURLWithPath:audioFilePath];
    
    return audioFileURL;
}

- (void)setNewAudioRecorder {
    NSError *error                                      =   nil;
    
    _audioSession                                       =   [AVAudioSession sharedInstance];
    [_audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
    
    _audioRecorder                                      =   [[AVAudioRecorder alloc] initWithURL:[self setNewAudioFileURL:snippetNumber]
                                                                                        settings:audioRecordSettings
                                                                                           error:&error];
    
    if (error)
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Alert error API title", nil)
                                    message:[error localizedDescription]
                                   delegate:nil
                          cancelButtonTitle:nil
                          otherButtonTitles:NSLocalizedString(@"Alert error button Ok", nil), nil] show];
    
    else
        [_audioRecorder prepareToRecord];
}

- (NSTimer *)createTimer {
    return [NSTimer scheduledTimerWithTimeInterval:1.f
                                            target:self
                                          selector:@selector(timerTicked:)
                                          userInfo:nil
                                           repeats:YES];
}

- (void)timerTicked:(NSTimer *)timer {
    timerSeconds++;
    
    if (timerSeconds == sessionDuration) {
        if (self.recordingMode == HRPVideoRecordViewControllerModeStreamVideo)
            timerSeconds                                =   0;
        else {
            [timerVideo invalidate];
            timerSeconds                                =   0;
        }
        
        [self.videoFileOutput stopRecording];
    }
    
    self.timerLabel.text                                =   [self formattedTime:timerSeconds];
}

- (NSString *)formattedTime:(NSInteger)secondsTotal {
    NSInteger seconds                                   =   secondsTotal % 60;
    NSInteger minutes                                   =   (secondsTotal / 60) % 60;
    NSInteger hours                                     =   secondsTotal / 3600;
    
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
}

- (NSInteger)countVideoSnippets {
    NSArray *allFolderFiles                             =   [[NSFileManager defaultManager] contentsOfDirectoryAtPath:mediaFolderPath error:nil];
    NSPredicate *predicate                              =   [NSPredicate predicateWithFormat:@"SELF contains[cd] %@", @"snippet"];
    
    NSLog(@"HRPVideoRecordViewController (323): COUNT = %ld", (long)[[allFolderFiles filteredArrayUsingPredicate:predicate] count]);
    
    return [[allFolderFiles filteredArrayUsingPredicate:predicate] count];
}

- (void)deleteFolder {
    if ([[NSFileManager defaultManager] removeItemAtPath:mediaFolderPath error:nil])
        NSLog(@"HRPVideoRecordViewController (352): DELETE");
    else
        NSLog(@"HRPVideoRecordViewController (354): NOT DELETE");
}

- (void)removeAllFolderMediaTempFiles {
    NSArray *allFolderFiles                             =   [[NSFileManager defaultManager] contentsOfDirectoryAtPath:mediaFolderPath error:nil];
    
    for (NSString *fileName in allFolderFiles) {
        if ([fileName containsString:@"snippet_"] ||
            [fileName containsString:@"attention_video"])
            [[NSFileManager defaultManager] removeItemAtPath:[mediaFolderPath stringByAppendingPathComponent:fileName] error:nil];
    }
    
    // Start new video & audio session
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [self startCameraSession];
}

- (void)removeMediaSnippets {
    NSArray *allFolderFiles                             =   [[NSFileManager defaultManager] contentsOfDirectoryAtPath:mediaFolderPath error:nil];
    
    for (NSString *fileName in allFolderFiles) {
        if ([fileName containsString:@"snippet_video_1.mp4"] ||
            [fileName containsString:@"snippet_audio_1.caf"])
            [[NSFileManager defaultManager] removeItemAtPath:[mediaFolderPath stringByAppendingPathComponent:fileName] error:nil];
    }
}

- (void)readAllFolderFile {
    NSArray *allFolderFiles                             =   [[NSFileManager defaultManager] contentsOfDirectoryAtPath:mediaFolderPath error:nil];
  
    NSLog(@"HRPVideoRecordViewController (335): FOLDER FILES = %@", allFolderFiles);
}

- (void)mergeAndSaveVideoFile {
    if (!progressHUD.alpha) {
        progressHUD                                     =   [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        progressHUD.labelText                           =   NSLocalizedString(@"Merge & Save video", nil);
        progressHUD.color                               =   [UIColor colorWithHexString:@"05A9F4" alpha:0.8f];
        progressHUD.yOffset                             =   0.f;
    }

    // Create the AVMutable composition to add tracks
    self.composition                                    =   [AVMutableComposition composition];
    
    // Create the mutable composition track with video media type
    [self mergeAudioAndVideoFiles];
    
    // Create the export session to merge and save the video
    AVAssetExportSession *videoExportSession            =   [[AVAssetExportSession alloc] initWithAsset:self.composition
                                                                                             presetName:AVAssetExportPresetHighestQuality];
    
    NSString *videoFileName                             =   @"attention_video.mov";
    
    NSURL *videoURL                                     =   [[NSURL alloc] initFileURLWithPath:
                                                             [mediaFolderPath stringByAppendingPathComponent:videoFileName]];
    
    videoExportSession.outputURL                        =   videoURL;
    videoExportSession.outputFileType                   =   @"com.apple.quicktime-movie";
    videoExportSession.shouldOptimizeForNetworkUse      =   YES;
    
    [videoExportSession exportAsynchronouslyWithCompletionHandler:^{
        switch (videoExportSession.status) {
            case AVAssetExportSessionStatusFailed:
                NSLog(@"HRPVideoRecordViewController (449): Failed to export video");
                break;
                
            case AVAssetExportSessionStatusCancelled:
                NSLog(@"HRPVideoRecordViewController (453): export cancelled");
                break;
                
            case AVAssetExportSessionStatusCompleted: {
                // Here you go you have got the merged video :)
                NSLog(@"HRPVideoRecordViewController (458): Merging completed");
                [self exportDidFinish:videoExportSession];
            }
                break;
                
            default:
                break;
        }
    }];
}

- (void)mergeAudioAndVideoFiles {
    AVMutableCompositionTrack *videoCompositionTrack    =   [self.composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                                          preferredTrackID:kCMPersistentTrackID_Invalid];
    
    AVMutableCompositionTrack *audioCompositionTrack    =   [self.composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                                          preferredTrackID:kCMPersistentTrackID_Invalid];

    // Create assets URL's for videos snippets
    NSArray *allFolderFiles                             =   [[NSFileManager defaultManager] contentsOfDirectoryAtPath:mediaFolderPath error:nil];
    NSPredicate *predicateVideo                         =   [NSPredicate predicateWithFormat:@"SELF contains[cd] %@", @"snippet_video_"];
    NSMutableArray *allVideoTempSnippets                =   [NSMutableArray arrayWithArray:[allFolderFiles filteredArrayUsingPredicate:predicateVideo]];
    NSPredicate *predicateAudio                         =   [NSPredicate predicateWithFormat:@"SELF contains[cd] %@", @"snippet_audio_"];
    NSMutableArray *allAudioTempSnippets                =   [NSMutableArray arrayWithArray:[allFolderFiles filteredArrayUsingPredicate:predicateAudio]];
    
    // Sort arrays
    NSSortDescriptor *sortDescription                   =   [[NSSortDescriptor alloc] initWithKey:nil ascending:NO];
    allVideoTempSnippets                                =   [NSMutableArray arrayWithArray:
                                                             [allVideoTempSnippets sortedArrayUsingDescriptors:@[sortDescription]]];
    
    allAudioTempSnippets                                =   [NSMutableArray arrayWithArray:
                                                             [allAudioTempSnippets sortedArrayUsingDescriptors:@[sortDescription]]];

    for (int i = 0; i < allVideoTempSnippets.count; i++) {
        NSString *videoSnippetFilePath                  =   [mediaFolderPath stringByAppendingPathComponent:allVideoTempSnippets[i]];
        AVURLAsset *videoSnippetAsset                   =   [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:videoSnippetFilePath] options:nil];
        NSString *audioSnippetFilePath                  =   [mediaFolderPath stringByAppendingPathComponent:allAudioTempSnippets[i]];
        AVURLAsset *audioSnippetAsset                   =   [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:audioSnippetFilePath] options:nil];
        
        // Set the video snippet time ranges in composition
        [videoCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoSnippetAsset.duration)
                                       ofTrack:[[videoSnippetAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                                        atTime:kCMTimeZero
                                         error:nil];
        
        if (audioSnippetAsset)
            [audioCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioSnippetAsset.duration)
                                           ofTrack:[[audioSnippetAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                                            atTime:kCMTimeZero
                                             error:nil];
    }
}

- (void)exportDidFinish:(AVAssetExportSession*)session {
    if (session.status == AVAssetExportSessionStatusCompleted) {
        NSURL *outputURL                                =   session.outputURL;
        ALAssetsLibrary *library                        =   [[ALAssetsLibrary alloc] init];
       
        // Save merged video to album
        if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputURL]) {
            [library writeVideoAtPathToSavedPhotosAlbum:outputURL
                                        completionBlock:^(NSURL *assetURL, NSError *error) {
                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                if (error)
                                                    [self showAlertViewWithTitle:NSLocalizedString(@"Alert error email title", nil)
                                                                      andMessage:NSLocalizedString(@"Alert error saving video message", nil)];
                                                else
                                                    [self removeAllFolderMediaTempFiles];
                                            });
                                        }];
        }
    }
}

- (void)extractFirstFrameFromVideoFilePath:(NSURL *)filePathURL {
    NSError *err                                        =   NULL;
    
    AVURLAsset *movieAsset                              =   [[AVURLAsset alloc] initWithURL:filePathURL options:nil];
    AVAssetImageGenerator *imageGenerator               =   [[AVAssetImageGenerator alloc] initWithAsset:movieAsset];
    imageGenerator.appliesPreferredTrackTransform       =   YES;
    CMTime time                                         =   CMTimeMake(1, 2);
    CGImageRef oneRef                                   =   [imageGenerator copyCGImageAtTime:time actualTime:NULL error:&err];

    UIImageOrientation imageOrientation;
    
    if ([[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationPortrait)
        imageOrientation                                =   UIImageOrientationUp;
    else if ([[UIApplication sharedApplication] statusBarOrientation] == UIDeviceOrientationLandscapeRight)
        imageOrientation                                =   UIImageOrientationRight;
    else if ([[UIApplication sharedApplication] statusBarOrientation] == UIDeviceOrientationLandscapeLeft)
        imageOrientation                                =   UIImageOrientationLeft;

    videoImageOriginal                                  =   [[UIImage alloc] initWithCGImage:oneRef scale:1.f orientation:imageOrientation];
    
    if (videoImageOriginal)
        [self mergeAndSaveVideoFile];
}

- (void)showAlertViewWithTitle:(NSString *)titleText andMessage:(NSString *)messageText {
   [[[UIAlertView alloc] initWithTitle:titleText
                               message:messageText
                              delegate:nil
                     cancelButtonTitle:nil
                     otherButtonTitles:NSLocalizedString(@"Alert error button Ok", nil), nil] show];
}
                                                           

#pragma mark - AVCaptureFileOutputRecordingDelegate -
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
      fromConnections:(NSArray *)connections {
    if (!timerSeconds)
        timerSeconds                                    =   0;
    
    if (!timerVideo)
        timerVideo                                      =   [self createTimer];
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
      fromConnections:(NSArray *)connections error:(NSError *)error {
    // START Button taped
    if (self.recordingMode == HRPVideoRecordViewControllerModeStreamVideo) {
        snippetNumber                                   =   (snippetNumber == 0) ? 1 : 0;
        
        [self stopAudioRecording];
        [self startStreamVideoRecording];
        
        // Delete media snippets_1
        if (snippetNumber == 0)
            [self removeMediaSnippets];
    }
    
    // ATTENTION Button taped
    else if (self.recordingMode == HRPVideoRecordViewControllerModeAttentionVideo) {
        // Get first video frame image
        if (snippetNumber == 2) {
            snippetNumber                               =   0;
            [self stopAudioRecording];
            
            [self extractFirstFrameFromVideoFilePath:outputFileURL];
        }
        
        else {
            snippetNumber                               =   2;

            [self stopAudioRecording];
            [self startStreamVideoRecording];
        }
    }
}


#pragma mark - AVAudioRecorderDelegate -
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
}


#pragma mark - AVAudioPlayerDelegate -
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
}


#pragma mark - UITextFieldDelegate -
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    return YES;
}

@end