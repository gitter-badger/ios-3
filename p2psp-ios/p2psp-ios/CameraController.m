//
//  CameraController.m
//  p2psp-ios
//
//  Created by Jorge on 17/3/16.
//  Copyright © 2016 P2PSP. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import "CameraController.h"
#import "HTTPClient.h"

@interface CameraController ()
@property(weak, nonatomic) IBOutlet UIToolbar *tbClose;
@property(weak, nonatomic) IBOutlet UIToolbar *tbRecord;
@property(nonatomic) IBOutlet UIBarButtonItem *bbiRecord;
@property(nonatomic) IBOutlet UIBarButtonItem *bbiStop;
@property(weak, nonatomic) IBOutlet UIView *vCameraPreviewContainer;

@property(nonatomic) HTTPClient *mediaSender;
@property(nonatomic) VideoRecorder *videoRecorder;
@property(nonatomic, weak) IBOutlet UIView *preview;

@property(nonatomic) NSString *address;
@end

@implementation CameraController

- (void)viewDidLoad {
  [[UIDevice currentDevice]
      setValue:[NSNumber numberWithInt:UIInterfaceOrientationPortrait]
        forKey:@"orientation"];

  // Set toolbars transparent
  [self.tbClose setBackgroundImage:[UIImage new]
                forToolbarPosition:UIBarPositionAny
                        barMetrics:UIBarMetricsDefault];
  [self.tbClose setShadowImage:[UIImage new]
            forToolbarPosition:UIToolbarPositionAny];

  [self.tbRecord setBackgroundImage:[UIImage new]
                 forToolbarPosition:UIBarPositionAny
                         barMetrics:UIBarMetricsDefault];
  [self.tbRecord setShadowImage:[UIImage new]
             forToolbarPosition:UIToolbarPositionAny];

  // Hide navigation bar
  [self.navigationController setNavigationBarHidden:YES];

  self.bbiStop = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemCamera
                           target:self
                           action:@selector(onStop:)];

  [self.bbiStop setTintColor:[UIColor redColor]];

  self.bbiRecord = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemCamera
                           target:self
                           action:@selector(onRecord:)];

  [self.bbiRecord setTintColor:[UIColor whiteColor]];

  [self updateBarButtonItem:self.bbiRecord inToolbar:self.tbRecord];

  // Setup video recorder and http client
  self.mediaSender = [[HTTPClient alloc] init];
}

- (void)viewWillAppear:(BOOL)animated {
}

- (void)viewDidAppear:(BOOL)animated {
  // [UIView setAnimationsEnabled:YES];
  _videoRecorder =
      [[VideoRecorder alloc] initWithWidth:self.view.bounds.size.width
                                 andHeight:self.view.bounds.size.height];
  [_videoRecorder setDelegate:self];
  _videoRecorder.preview.frame = self.vCameraPreviewContainer.bounds;
  [self.vCameraPreviewContainer addSubview:[_videoRecorder preview]];
}

/**
 *  System override function to specify when should the status bar be hidden
 *
 *  @return Whether it should be hidden or not
 */
- (BOOL)prefersStatusBarHidden {
  return YES;
}

- (void)updateBarButtonItem:(UIBarButtonItem *)bbi
                  inToolbar:(UIToolbar *)toolbar {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSMutableArray *tbItems =
        [[NSMutableArray alloc] initWithArray:[toolbar items]];
    [tbItems replaceObjectAtIndex:1 withObject:bbi];

    [toolbar setItems:tbItems];
  });
}

- (IBAction)onRecord:(id)sender {
  NSLog(@"Recording...");
  [self updateBarButtonItem:self.bbiStop inToolbar:self.tbRecord];

  [self deleteTempDirFile];

  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.mediaSender
            createConnection:
                [NSURL URLWithString:[NSString
                                         stringWithFormat:@"http://%@/api/emit",
                                                          self.address]]];
      });

  [_videoRecorder
      startRecordingForDropFileWithSeconds:1
                                 frameRate:30
                              captureWidth:self.vCameraPreviewContainer.bounds
                                               .size.width
                             captureHeight:self.vCameraPreviewContainer.bounds
                                               .size.height];
}

- (IBAction)onStop:(id)sender {
  NSLog(@"Stop");
  [self updateBarButtonItem:self.bbiRecord inToolbar:self.tbRecord];
  [self.videoRecorder stopRecording];
}

- (IBAction)deleteTempDirFile {
  NSError *err = nil;
  NSArray *filesArray = [[NSFileManager defaultManager]
      contentsOfDirectoryAtPath:NSTemporaryDirectory()
                          error:&err];
  for (NSString *str in filesArray) {
    NSString *path =
        [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), str];
    if (![[NSFileManager defaultManager] removeItemAtPath:path error:&err]) {
      NSLog(@"Error deleting existing file");
    }
  }
}

#pragma mark VideoRecorderDelegate

- (void)videoRecorder:(VideoRecorder *)videoRecorder
    recoringDidFinishToOutputFileURL:(NSURL *)outputFileURL
                               error:(NSError *)error {
  NSLog(@"recording finished URL: %@", outputFileURL);

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                 ^{
                   [self.mediaSender postVideo:outputFileURL];
                 });

  // [self saveToCameraRoll:outputFileURL];
}

// TODO: This selector is to be able to watch recorded videos
- (void)saveToCameraRoll:(NSURL *)srcURL {
  NSLog(@"srcURL: %@", srcURL);

  ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
  ALAssetsLibraryWriteVideoCompletionBlock videoWriteCompletionBlock = ^(
      NSURL *newURL, NSError *error) {
    if (error) {
      NSLog(@"Error writing image with metadata to Photo Library: %@", error);
    } else {
      NSLog(@"Wrote image with metadata to Photo Library %@",
            newURL.absoluteString);
    }
  };

  if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:srcURL]) {
    [library writeVideoAtPathToSavedPhotosAlbum:srcURL
                                completionBlock:videoWriteCompletionBlock];
  }
}

- (void)setServerAddress:(NSString *)address {
  self.address = address;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  [self.videoRecorder stopRecording];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
  return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate {
  // [UIView setAnimationsEnabled:NO];
  return [super shouldAutorotate];
}

@end
