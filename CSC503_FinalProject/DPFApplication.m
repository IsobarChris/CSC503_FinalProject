//
//  DPFApplication.m
//  CSC503_FinalProject
//
//  Created by MacBookPro on 3/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DPFApplication.h"

@implementation DPFApplication

@synthesize view;
@synthesize seedField;
@synthesize gridSize;
@synthesize algorithm;
@synthesize textField;
@synthesize progressIndicator;

- (void)awakeFromNib
{
    [super awakeFromNib];
}

-(IBAction)slid:(id)sender
{
    self.seedField.stringValue = [NSString stringWithFormat:@"%d",seedField.intValue];
}

-(IBAction)generateMapPressed:(id)sender
{
    NSLog(@"make the map!!  %d  %d",(int)gridSize.selectedColumn,(int)seedField.intValue);
    CGFloat size = 64;
    for(int i=0;i<gridSize.selectedColumn;i++)
        size /= 2;
    [view generateMapOfSize:size andSeed:seedField.intValue];
}

-(IBAction)findPathPressed:(id)sender
{
    self.view.textField = self.textField;
    self.textField.stringValue = [NSString stringWithFormat:@"Finding Path..."];
    
    //[self.progressIndicator setHidden:NO];
    [self.progressIndicator startAnimation:nil];
    
    NSLog(@"find path!! %d",(int)algorithm.selectedColumn);
    [view findPathWithAlgorithm:algorithm.selectedColumn];
    
    [self.progressIndicator stopAnimation:nil];
    //[self.progressIndicator setHidden:YES];
}

@end
