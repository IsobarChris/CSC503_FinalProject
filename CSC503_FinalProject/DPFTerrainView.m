//
//  DPFTerrainView.m
//  CSC503_FinalProject
//
//  Created by MacBookPro on 3/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DPFTerrainView.h"
#import <QuartzCore/QuartzCore.h>

// size 8, seed 5
// size 4, seed 6
// size 2, seed 6


#define SIZE_FACTOR 2
#define MAP_SEED    6

#define WIDTH  (1024/SIZE_FACTOR)
#define HEIGHT  (768/SIZE_FACTOR)

#define PIX_W  (1024/WIDTH)
#define PIX_H  (768/HEIGHT)

typedef enum
{
    DPFTerrainVoid=0,
    DPFTerrainGround,
    DPFTerrainHills,
    DPFTerrainWater,
    DPFTerrainForest,
    DPFTerrainMountain,
    DPFTerrainSwamp,
    DPFTerrainCount
}DPFTerrain;

typedef struct
{
    CGFloat r;
    CGFloat b;
    CGFloat g;
}DPFTerrainColor;

@interface DPFTerrainView()
{
    DPFTerrain map[WIDTH][HEIGHT];
    DPFTerrainColor terrainColor[DPFTerrainCount];
}

@end

@implementation DPFTerrainView

- (BOOL)trueForProb
{
    if(rand()%100<40)
        return YES;
    return NO;
}

- (void)spreadOutTerrain:(DPFTerrain)terrain fromX:(int)x andY:(int)y
{
    for(int i=-1;i<2;i++)
        for(int j=-1;j<2;j++)
        {
            int w = x+i;
            int h = y+j;
            if(map[w][h] == DPFTerrainGround)
            {
                map[w][h] = terrain;
                if([self trueForProb])
                    [self spreadOutTerrain:terrain fromX:w andY:h];
            }
        }
}

- (void)generateMap
{
    srand(MAP_SEED);
    // make everythign ground to start with, with a void border
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
            if(x==0 || y==0 || x==WIDTH-1 || y==HEIGHT-1)
                map[x][y] = DPFTerrainVoid;                
            else
                map[x][y] = DPFTerrainGround;
    
    
    int terrainCounts[DPFTerrainCount] = {0,0,2*(8/SIZE_FACTOR),2*(8/SIZE_FACTOR),2*(8/SIZE_FACTOR),4*(8/SIZE_FACTOR),6*(8/SIZE_FACTOR)};
    
    // random terrain and spread it out
    for(int t=0;t<DPFTerrainCount;t++)
    {
        DPFTerrain terrain = (DPFTerrain)t;
        for(int i=0;i<terrainCounts[t];i++)
        {
            int x = rand()%WIDTH;
            int y = rand()%HEIGHT;
            if(map[x][y]==DPFTerrainGround)
            {
                map[x][y] = terrain;
                [self spreadOutTerrain:terrain fromX:x andY:y];
            }
        }    
    }
    
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) 
    {
        [self generateMap];
        
        //        DPFTerrainVoid,
        terrainColor[DPFTerrainVoid].r = 0.0;
        terrainColor[DPFTerrainVoid].g = 0.0;
        terrainColor[DPFTerrainVoid].b = 0.0;
        //        DPFTerrainGround,
        terrainColor[DPFTerrainGround].r = 0.0;
        terrainColor[DPFTerrainGround].g = 0.9;
        terrainColor[DPFTerrainGround].b = 0.0;
        //        DPFTerrainHills,
        terrainColor[DPFTerrainHills].r = 0.0;
        terrainColor[DPFTerrainHills].g = 0.6;
        terrainColor[DPFTerrainHills].b = 0.0;
        //        DPFTerrainMountain,
        terrainColor[DPFTerrainMountain].r = 0.6;
        terrainColor[DPFTerrainMountain].g = 0.3;
        terrainColor[DPFTerrainMountain].b = 0.3;
        //        DPFTerrainSwamp,
        terrainColor[DPFTerrainSwamp].r = 0.3;
        terrainColor[DPFTerrainSwamp].g = 0.3;
        terrainColor[DPFTerrainSwamp].b = 0.4;
        //        DPFTerrainForest,
        terrainColor[DPFTerrainForest].r = 0.0;
        terrainColor[DPFTerrainForest].g = 0.8;
        terrainColor[DPFTerrainForest].b = 0.3;
        //        DPFTerrainWater,
        terrainColor[DPFTerrainWater].r = 0.0;
        terrainColor[DPFTerrainWater].g = 0.0;
        terrainColor[DPFTerrainWater].b = 1.0;
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSLog(@"Draw rect!\n");
    // Get the graphics context and clear it
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextClearRect(ctx, dirtyRect);
    
    // Draw a red solid square
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
        {
            CGFloat r = terrainColor[map[x][y]].r;
            CGFloat g = terrainColor[map[x][y]].g;
            CGFloat b = terrainColor[map[x][y]].b;
            //NSLog(@"r=%0.2f g=%0.2f b=%0.2f",r,g,b);
            
            CGContextSetRGBFillColor(ctx, r, g, b, 1);
            CGContextFillRect(ctx, CGRectMake(x*PIX_W, y*PIX_H, PIX_W, PIX_H));
        }
}

@end
