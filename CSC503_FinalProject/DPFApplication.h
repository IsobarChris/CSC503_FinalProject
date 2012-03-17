//
//  DPFApplication.h
//  CSC503_FinalProject
//
//  Created by MacBookPro on 3/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DPFTerrainView.h"

@interface DPFApplication : NSApplication

@property (nonatomic,strong) IBOutlet DPFTerrainView  *view;
@property (nonatomic,strong) IBOutlet NSMatrix        *gridSize;
@property (nonatomic,strong) IBOutlet NSMatrix        *algorithm;
@property (nonatomic,strong) IBOutlet NSSlider        *seedField;
@property (nonatomic,strong) IBOutlet NSTextField     *textField;
@property (nonatomic,strong) IBOutlet NSProgressIndicator *progressIndicator;

-(IBAction)generateMapPressed:(id)sender;
-(IBAction)findPathPressed:(id)sender;


@end
