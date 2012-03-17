//
//  DPFTerrainView.h
//  CSC503_FinalProject
//
//  Created by MacBookPro on 3/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DPFTerrainView : NSView

@property (nonatomic,strong) NSTextField *textField;

-(void)generateMapOfSize:(CGFloat)sizeFactor andSeed:(NSInteger)seed;
-(void)findPathWithAlgorithm:(NSInteger)algorithm;

@end
