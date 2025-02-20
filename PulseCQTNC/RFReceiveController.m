//
//  ViewController.m
//  CoreGraphicsWaveform
//
//  Created by Syed Haris Ali on 12/1/13.
//  Updated by Syed Haris Ali on 1/23/16.
//  Copyright (c) 2013 Syed Haris Ali. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "RFReceiveController.h"
#include "multimon.h"
#import <NSLogger/NSLogger.h>

//float *convertedBuffer = NULL;
//AudioUnit *audioUnit_ = NULL;



//------------------------------------------------------------------------------
#pragma mark - ViewController (Interface Extension)
//------------------------------------------------------------------------------

@interface RFReceiveController ()
@property (nonatomic, strong) NSArray *inputs;
@end

//------------------------------------------------------------------------------
#pragma mark - ViewController (Implementation)
//------------------------------------------------------------------------------

@implementation RFReceiveController

//------------------------------------------------------------------------------
#pragma mark - View Style
//------------------------------------------------------------------------------

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

//------------------------------------------------------------------------------
#pragma mark - Setup
//------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.microphoneTextLabel.text = @"";
    //
    // Setup the AVAudioSession. EZMicrophone will not work properly on iOS
    // if you don't do this!
    //
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error)
    {
        LoggerApp(1, @"Error setting up audio session category: %@", error.localizedDescription);
    }
    [session setActive:YES error:&error];
    if (error)
    {
        LoggerApp(1, @"Error setting up audio session active: %@", error.localizedDescription);
    }
    
    
    float aBufferLength = COREAUDIO_BUFFER_LENGTH; // In seconds
    AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(aBufferLength), &aBufferLength);

//    NSError *setCategoryError = nil;
//    if (![session setCategory:AVAudioSessionCategoryPlayback
//                  withOptions:AVAudioSessionCategoryOptionMixWithOthers
//                        error:&setCategoryError]) {
//        // handle error
//    }

    
//    double rate = 22050.0;
//    [session setPreferredSampleRate: rate error:&error];
//    [session setPreferredOutputNumberOfChannels: 1 error:&error];
//
    //
    // Customizing the audio plot's look
    //
    
    //
    // Background color
    //
    self.audioPlot.backgroundColor = UIColorFromRGB(0x6d70d4); // [UIColor colorWithRed:0.984 green:0.471 blue:0.525 alpha:1.0];

    //
    // Waveform color
    //
    self.audioPlot.color = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];

    //
    // Plot type
    //
    self.audioPlot.plotType = EZPlotTypeBuffer;

    
    // Multimon customization: set AudioStreamBasicDescription
    AudioStreamBasicDescription streamDescription;
    // You might want to replace this with a different value, but keep in mind that the
    // iPhone does not support all sample rates. 8kHz, 22kHz, and 44.1kHz should all work.
    streamDescription.mSampleRate = 22050;
    // Yes, I know you probably want floating point samples, but the iPhone isn't going
    // to give you floating point data. You'll need to make the conversion by hand from
    // linear PCM <-> float.
    streamDescription.mFormatID = kAudioFormatLinearPCM;
    // This part is important!
    streamDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger |
    kAudioFormatFlagsNativeEndian |
    kAudioFormatFlagIsPacked;
    // Not sure if the iPhone supports recording >16-bit audio, but I doubt it.
    streamDescription.mBitsPerChannel = 16;
    // 1 sample per frame, will always be 2 as long as 16-bit samples are being used
    streamDescription.mBytesPerFrame = 2;
    // Record in mono. Use 2 for stereo, though I don't think the iPhone does true stereo recording
    streamDescription.mChannelsPerFrame = 1;
    streamDescription.mBytesPerPacket = streamDescription.mBytesPerFrame * streamDescription.mChannelsPerFrame;
    // Always should be set to 1
    streamDescription.mFramesPerPacket = 1;
    // Always set to 0, just to be sure
    streamDescription.mReserved = 0;

    //
    // Create the microphone
    //
    self.microphone = [EZMicrophone microphoneWithDelegate:self withAudioStreamBasicDescription: streamDescription];
    [self.microphone initMultimon];

    
    //[self.microphone setAudioStreamBasicDescription: streamDescription];

    

    //
    // Set up the microphone input UIPickerView items to select
    // between different microphone inputs. Here what we're doing behind the hood
    // is enumerating the available inputs provided by the AVAudioSession.
    //
    self.inputs = [EZAudioDevice inputDevices];
    self.microphoneInputPickerView.dataSource = self;
    self.microphoneInputPickerView.delegate = self;

    //
    // Start the microphone
    //
    
    [self.microphone startFetchingAudio];
    //self.microphoneTextLabel.text = @"Audio Input On";
    
    // Init the Multimon
    // LoggerApp(1, @"Init the multimon");
    
    //[self initMultimon];
    
    
    // untoggle microphone if it's not on by default
    if (![[NSUserDefaults standardUserDefaults] boolForKey: NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART]) {
        [self.toggleSwitch setOn: NO];
        [self toggleMicrophone: nil];
        self.microphoneTextLabel.text = @"Audio Input Off";
    } else {
        self.microphoneTextLabel.text = @"Audio Input On";
    }
}

//------------------------------------------------------------------------------
#pragma mark - UIPickerViewDataSource
//------------------------------------------------------------------------------

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

//------------------------------------------------------------------------------

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component
{
    EZAudioDevice *device = self.inputs[row];
    return device.name;
}

//------------------------------------------------------------------------------

- (NSAttributedString *)pickerView:(UIPickerView *)pickerView
             attributedTitleForRow:(NSInteger)row
                      forComponent:(NSInteger)component
{
    EZAudioDevice *device = self.inputs[row];
    UIColor *textColor = [device isEqual:self.microphone.device] ? self.audioPlot.backgroundColor : [UIColor blackColor];
    return  [[NSAttributedString alloc] initWithString:device.name
                                            attributes:@{ NSForegroundColorAttributeName : textColor }];
}

//------------------------------------------------------------------------------

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.inputs.count;
}

//------------------------------------------------------------------------------

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    EZAudioDevice *device = self.inputs[row];
    [self.microphone setDevice:device];
}

//------------------------------------------------------------------------------
#pragma mark - Actions
//------------------------------------------------------------------------------

- (void)changePlotType:(id)sender
{
    NSInteger selectedSegment = [sender selectedSegmentIndex];
    switch (selectedSegment)
    {
        case 0:
            [self drawBufferPlot];
            break;
        case 1:
            [self drawRollingPlot];
            break;
        default:
            break;
    }
}

//------------------------------------------------------------------------------

- (void)toggleMicrophone:(id)sender
{
    BOOL isOn = [sender isOn];
    if (!isOn)
    {
        [self.microphone stopFetchingAudio];
        self.microphoneTextLabel.text = @"Audio Input Off";
    }
    else
    {
        [self.microphone startFetchingAudio];
        self.microphoneTextLabel.text = @"Audio Input On";
    }
}

//------------------------------------------------------------------------------

- (void)toggleMicrophonePickerView:(id)sender
{
    BOOL isHidden = self.microphoneInputPickerViewTopConstraint.constant != 0.0;
    [self setMicrophonePickerViewHidden:!isHidden];
}

//------------------------------------------------------------------------------

- (void)setMicrophonePickerViewHidden:(BOOL)hidden
{
    CGFloat pickerHeight = CGRectGetHeight(self.microphoneInputPickerView.bounds);
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.55
                          delay:0.0
         usingSpringWithDamping:0.6
          initialSpringVelocity:0.5
                        options:(UIViewAnimationOptionBeginFromCurrentState|
                                 UIViewAnimationOptionCurveEaseInOut|
                                 UIViewAnimationOptionLayoutSubviews)
                     animations:^{
                         weakSelf.microphoneInputPickerViewTopConstraint.constant = hidden ? -pickerHeight : 0.0f;
                         [weakSelf.view layoutSubviews];
                     } completion:nil];
}

//------------------------------------------------------------------------------
#pragma mark - Utility
//------------------------------------------------------------------------------

//
// Give the visualization of the current buffer (this is almost exactly the
// openFrameworks audio input eample)
//
- (void)drawBufferPlot
{
    self.audioPlot.plotType = EZPlotTypeBuffer;
    self.audioPlot.shouldMirror = NO;
    self.audioPlot.shouldFill = NO;
}

//------------------------------------------------------------------------------

//
// Give the classic mirrored, rolling waveform look
//
-(void)drawRollingPlot
{
    self.audioPlot.plotType = EZPlotTypeRolling;
    self.audioPlot.shouldFill = YES;
    self.audioPlot.shouldMirror = YES;
}

#pragma mark - EZMicrophoneDelegate
#warning Thread Safety
//
// Note that any callback that provides streamed audio data (like streaming
// microphone input) happens on a separate audio thread that should not be
// blocked. When we feed audio data into any of the UI components we need to
// explicity create a GCD block on the main thread to properly get the UI
// to work.
//
- (void)microphone:(EZMicrophone *)microphone
  hasAudioReceived:(float **)buffer
    withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels
{
    //
    // Getting audio data as an array of float buffer arrays. What does that mean?
    // Because the audio is coming in as a stereo signal the data is split into
    // a left and right channel. So buffer[0] corresponds to the float* data
    // for the left channel while buffer[1] corresponds to the float* data
    // for the right channel.
    //

    //
    // See the Thread Safety warning above, but in a nutshell these callbacks
    // happen on a separate audio thread. We wrap any UI updating in a GCD block
    // on the main thread to avoid blocking that audio flow.
    //
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        //
        // All the audio plot needs is the buffer data (float*) and the size.
        // Internally the audio plot will handle all the drawing related code,
        // history management, and freeing its own resources.
        // Hence, one badass line of code gets you a pretty plot :)
        //
        [weakSelf.audioPlot updateBuffer:buffer[0] withBufferSize:bufferSize];
        
        
        
//        for (int i = 0; (unsigned int) i <  NUMDEMOD; i++)
//            if (MASK_ISSET(i) && dem[i]->demod)
//            {
//                buffer_t b = {bufferSize, buffer};
//                dem[i]->demod(dem_st+i, b, bufferSize);
//            }
    });
}

//------------------------------------------------------------------------------

- (void)microphone:(EZMicrophone *)microphone hasAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription
{
    //
    // The AudioStreamBasicDescription of the microphone stream. This is useful
    // when configuring the EZRecorder or telling another component what
    // audio format type to expect.
    //
    [EZAudioUtilities printASBD:audioStreamBasicDescription];
}

//------------------------------------------------------------------------------

- (void)microphone:(EZMicrophone *)microphone
     hasBufferList:(AudioBufferList *)buffers //bufferList
    withBufferSize:(UInt32)numFrames // bufferSize
withNumberOfChannels:(UInt32)numberOfChannels
{
    // Load the code directly to EZMicrophone.m > EZAudioMicrophoneCallback instead!
    
    //__weak typeof (self) weakSelf = self;
    /*
    dispatch_async(dispatch_get_main_queue(), ^{
        //
        // Getting audio data as a buffer list that can be directly fed into the
        // EZRecorder or EZOutput. Say whattt...
        //
        if(convertedBuffer == NULL) {
            // Lazy initialization of this buffer is necessary because we don't
            // know the frame count until the first callback
            convertedBuffer = (float*)malloc(sizeof(float) * numFrames);
        }

        SInt16 *inputFrames = (SInt16*)(buffers->mBuffers->mData);

        for(int i = 0; i < numFrames; i++) {
            convertedBuffer[i] = (float)inputFrames[i] / 32768.0f;
        }

        for (int i = 0; (unsigned int) i <  NUMDEMOD; i++)
            if (MASK_ISSET(i) && dem[i]->demod)
            {
                buffer_t b = {inputFrames, convertedBuffer};
                dem[i]->demod(dem_st+i, b, numFrames);
            }

    });
    */
    
}

//------------------------------------------------------------------------------

- (void)microphone:(EZMicrophone *)microphone changedDevice:(EZAudioDevice *)device {
    //NSLog(@"Microphone changed device: %@", device.name);
    //
    // Called anytime the microphone's device changes
    //
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *name = device.name;
        NSString *tapText = @" (Tap To Change)";
        NSString *microphoneInputToggleButtonText = [NSString stringWithFormat:@"%@%@", device.name, tapText];
        NSRange rangeOfName = [microphoneInputToggleButtonText rangeOfString:name];
        NSMutableAttributedString *microphoneInputToggleButtonAttributedText = [[NSMutableAttributedString alloc] initWithString:microphoneInputToggleButtonText];
        [microphoneInputToggleButtonAttributedText addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:13.0f] range:rangeOfName];
        [weakSelf.microphoneInputToggleButton setAttributedTitle:microphoneInputToggleButtonAttributedText forState:UIControlStateNormal];

        //
        // Reset the device list (a device may have been plugged in/out)
        //
        weakSelf.inputs = [EZAudioDevice inputDevices];
        [weakSelf.microphoneInputPickerView reloadAllComponents];
        [weakSelf setMicrophonePickerViewHidden:YES];
    });
}


@end
