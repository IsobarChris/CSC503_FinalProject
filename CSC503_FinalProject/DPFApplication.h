//
//  DPFApplication.h
//  CSC503_FinalProject
//
//  Created by MacBookPro on 3/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DPFApplication : NSApplication

@property (nonatomic,strong) IBOutlet NSView *view;

-(IBAction)buttonPressed:(id)sender;


@end
