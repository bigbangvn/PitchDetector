//
//  ListenerViewController.m
//  SafeSound
//
//  Created by Demetri Miller on 10/25/10.
//  Copyright 2010 Demetri Miller. All rights reserved.
//

#import "ListenerViewController.h"
#import "RIOInterface.h"
#import "KeyHelper.h"

@implementation ListenerViewController

@synthesize currentPitchLabel, currentBandsLabel, listenButton, key, prevChar, isListening, rioRef;
@synthesize currentFrequency, imageView,drawMode, colorStepper, scaleSlider;

#pragma mark -
#pragma mark Listener Controls
- (IBAction)toggleListening:(id)sender {
	if (isListening) {
		[self stopListener];
		[listenButton setTitle:@"Start" forState:UIControlStateNormal];
	} else {
		[self startListener];
		[listenButton setTitle:@"Stop" forState:UIControlStateNormal];
	}
	
	isListening = !isListening;
}

- (void)startListener {
	[rioRef startListening:self];
}

- (void)stopListener {
	[rioRef stopListening];
}



#pragma mark -
#pragma mark Lifecycle
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    rioRef = [RIOInterface sharedInstance];
    
    currentFrame = 0;
    
    scale = 8.0;
    scaleSlider.value = 8.0;
    
    colorMode = DRAW_WHITE;
    waveDrawMode = WAVE_LINE;
    
    
    for(int i = 0; i < 1024; i++)
    {
        for(int j = 0; j < 1024; j++)
        {
            outputData[i][j][0] = 0x00;
            outputData[i][j][1] = 0x00;
            outputData[i][j][2] = 0x00;
            outputData[i][j][3] = 0xFF;
        }
    }
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	currentPitchLabel = nil;
    listenButton = nil;
    [super viewDidUnload];
}

- (void)dealloc {
    
	[super dealloc];
}

#pragma mark -
#pragma mark Key Management
// This method gets called by the rendering function. Update the UI with
// the character type and store it in our string.
- (void)frequencyChangedWithValue:(float)newFrequency{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	self.currentFrequency = newFrequency;
	[self performSelectorInBackground:@selector(updateFrequencyLabel) withObject:nil];
	
    
	/*
	 * If you want to display letter values for pitches, uncomment this code and
	 * add your frequency to pitch mappings in KeyHelper.m
     
     
     KeyHelper *helper = [KeyHelper sharedInstance];
     NSString *closestChar = [helper closestCharForFrequency:newFrequency];
     
     // If the new sample has the same frequency as the last one, we should ignore
     // it. This is a pretty inefficient way of doing comparisons, but it works.
     if (![prevChar isEqualToString:closestChar]) {
     self.prevChar = closestChar;
     if ([closestChar isEqualToString:@"0"]) {
     //	[self toggleListening:nil];
     }
     [self performSelectorInBackground:@selector(updateFrequencyLabel) withObject:nil];
     NSString *appendedString = [key stringByAppendingString:closestChar];
     self.key = [NSMutableString stringWithString:appendedString];
     }
     */
	
	[pool drain];
	pool = nil;
	
}

- (void)bandsChangedWithValue:(float*)newBands:(int)n
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    float maxValItr = 0.0;
    int maxBandItr = 0;
    
    currentFrame++;
    currentFrame = (currentFrame % 1024);
    
    for ( int i = 0; i < n; i+=2 )
    {
        currentBands[currentFrame][i/2] = newBands[i];
        
        float val = log2(newBands[i]);
        if(val > 256)
            val = 256;
        
        outputData[currentFrame][i/2][0] = (Byte) val;
        outputData[currentFrame][i/2][1] = (Byte) 255-val;
        outputData[currentFrame][i/2][2] = (Byte) 128-val;
        outputData[currentFrame][i/2][3] = 0xFF;
        
        if(currentBands[currentFrame][i/2] > maxValItr )
        {
            maxValItr = currentBands[currentFrame][i/2];
            maxBandItr = i;
        }
    }
    self->maxBand = maxBandItr;
    self->maxPeak = maxValItr;
    
	[self performSelectorInBackground:@selector(updateBandsLabel) withObject:nil];
	[self performSelectorInBackground:@selector(drawRect) withObject:nil];
    
	[pool drain];
	pool = nil;
    
}

- (void)updateFrequencyLabel {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	self.currentPitchLabel.text = [NSString stringWithFormat:@"%f", self.currentFrequency];
	[self.currentPitchLabel setNeedsDisplay];
	[pool drain];
	pool = nil;
}

- (void)updateBandsLabel {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	self.currentBandsLabel.text = [NSString stringWithFormat:@"max %f.2 (%d)", self->maxPeak, self->maxBand];
	[self.currentBandsLabel setNeedsDisplay];
	[pool drain];
	pool = nil;
}

- (void)drawRect
{
    
    UIGraphicsBeginImageContext(imageView.frame.size);
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    
    // fill the background of the square with grey
    CGContextSetRGBFillColor(currentContext, 0.5,0.5,0.5,1.0);
    //CGContextFillRect(currentContext, imageView.image.size);
    
    CGAffineTransform flipVertical =
    CGAffineTransformMake(1, 0, 0, -1, 0, imageView.image.size.height);
    CGContextConcatCTM(currentContext, flipVertical);
    
    
    float width = imageView.frame.size.width;
    
    if( waveDrawMode == WAVE_LINE )
    {
        
        float width_convert = width / 1024;
        
        CGFloat pointColor[] = { 1.0f, 1.0f, 1.0f, 1.0f };
        
        for(int i = 0; i < 1024; i++)
        {
            CGContextBeginPath(currentContext);
            
            // determine color for drawing mode
            if( colorMode == DRAW_WHITE )
            {
                [self getPointColor:pointColor forValue:currentBands[currentFrame][i]];
                
                CGContextSetRGBStrokeColor(currentContext, pointColor[0],
                                           pointColor[1], pointColor[2], pointColor[3]);
            }
            else if( colorMode == PEAK_HIGHLIGHT )
            {
                UIColor* segColor = [[UIColor alloc] initWithHue:currentBands[currentFrame][i]/maxPeak + 0.5
                                                      saturation:1.0
                                                      brightness:1.0
                                                           alpha:1.0];
                CGContextSetStrokeColorWithColor(currentContext, segColor.CGColor);
            }
            else if( colorMode == CHROMATIC_SCALE )
            {
                UIColor* segColor = [[UIColor alloc] initWithHue:(float)i/1024.0
                                                      saturation:1.0
                                                      brightness:1.0
                                                           alpha:1.0];
                CGContextSetStrokeColorWithColor(currentContext, segColor.CGColor);
            }
            
            // draw this line segment
            CGContextMoveToPoint(currentContext, i * width_convert, 0.0f);
            CGContextAddLineToPoint(currentContext, i * width_convert, scale * log2(currentBands[currentFrame][i]) );
            CGContextStrokePath(currentContext);
            
        }
        
        UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
        imageView.image = newImage;
        
    }
    
    if(waveDrawMode == WAVE_TEXTURE)
    {
        const int w = 1024;
        const int h = 1024;
        CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
        CGContextRef bitmapContext=CGBitmapContextCreate(outputData, w, h, 8, 4*w, colorSpace,  kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
        CFRelease(colorSpace);
        CGImageRef cgImage=CGBitmapContextCreateImage(bitmapContext);
        CGContextRelease(bitmapContext);
        
        UIImage * newImage = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
        
        imageView.image = newImage;
        
    }
    
    
    UIGraphicsEndImageContext(); // Add this line.
}

-(void) getPointColor:(CGFloat*)out_color
             forValue:(float)voltage
{
    
    if(voltage > 150)
    {
        out_color[0] = 1.0;
        out_color[1] = 0.2;
        out_color[2] = 0.2;
        out_color[3] = 1.0;
    }
    else if(voltage > 50)
    {
        out_color[0] = 0.3;
        out_color[1] = 1.0;
        out_color[2] = 0.2;
        out_color[3] = 1.0;
    }
    else if(voltage > 10)
    {
        out_color[0] = 0.3;
        out_color[1] = 0.15;
        out_color[2] = 1.0;
        out_color[3] = 1.0;
    }
    else if(voltage > 0)
    {
        out_color[0] = 0.1;
        out_color[1] = 0.0;
        out_color[2] = 0.8;
        out_color[3] = 1.0;
    }
}

-(IBAction)sliderValueChanged:(UISlider *)sender
{
    scale = sender.value;
}

- (IBAction)drawModeChangedAction:(id)sender
{
    if (drawMode.selectedSegmentIndex == 0)
        waveDrawMode = WAVE_LINE;
    else
        waveDrawMode = WAVE_TEXTURE;
}

-(IBAction)colorModeChangedAction:(id)sender
{
    if(colorStepper.value == 0)
        colorMode = PEAK_HIGHLIGHT;
    else if(colorStepper.value == 1)
        colorMode = CHROMATIC_SCALE;
    else if(colorStepper.value == 2)
        colorMode = DRAW_WHITE;
}


@end
