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


#define SIZE_FACTOR 8  // can be 1,2,4,8
#define MAP_SEED    6

#define WIDTH  (1024/SIZE_FACTOR)
#define HEIGHT  (768/SIZE_FACTOR)
#define DIRECTIONS 8  // can be 4 or 8  

#define DIR_N  0
#define DIR_S  1
#define DIR_E  2
#define DIR_W  3
#define DIR_NW 4
#define DIR_NE 5
#define DIR_SW 6
#define DIR_SE 7

#define MAX_DISTANCE 10000000.0
#define MAX_VERTS (WIDTH*HEIGHT*DIRECTIONS)

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


typedef struct
{
    int x,y;
    DPFTerrain terrain;
    BOOL inPath;
}DPFVert;

typedef struct
{
    DPFVert v1;
    DPFVert v2;
    CGFloat distance;
}DPFEdge;


int xOffsetForDirection(int d)
{
    switch (d) 
    {
        case 0: return  0; // N
        case 1: return  0; // S
        case 2: return  1; // E
        case 3: return -1; // W
        case 4: return -1; // NW
        case 5: return  1; // NE
        case 6: return -1; // SW
        case 7: return  1; // SE
    }
    return 0;
}

int yOffsetForDirection(int d)
{
    switch (d) 
    {
        case 0: return -1; // N
        case 1: return  1; // S
        case 2: return  0; // E
        case 3: return  0; // W
        case 4: return -1; // NW
        case 5: return -1; // NE
        case 6: return  1; // SW
        case 7: return  1; // SE
    }
    return 0;    
}

CGFloat terrainMovementPoints(DPFTerrain terrain)
{
    switch (terrain) 
    {
        case DPFTerrainVoid:     return MAX_DISTANCE;
        case DPFTerrainGround:   return 10.0;
        case DPFTerrainHills:    return 15.0;
        case DPFTerrainWater:    return 80.0;
        case DPFTerrainForest:   return 20.0;
        case DPFTerrainMountain: return 50.0;
        case DPFTerrainSwamp:    return 30.0;
        default: return MAX_DISTANCE;
    }
    return MAX_DISTANCE;
}


@interface DPFTerrainView()
{
    DPFVert map[WIDTH][HEIGHT];
    DPFEdge edge[WIDTH][HEIGHT][DIRECTIONS];
    DPFTerrainColor terrainColor[DPFTerrainCount];
    BOOL thePath[WIDTH][HEIGHT];
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
            if(map[w][h].terrain == DPFTerrainGround)
            {
                map[w][h].terrain = terrain;
                if([self trueForProb])
                    [self spreadOutTerrain:terrain fromX:w andY:h];
            }
        }
}

- (void) fillEdgeFromX:(int)x Y:(int)y direction:(int)d edge:(DPFEdge*)e
{
    e->v1.x = x;
    e->v2.x = x+xOffsetForDirection(d);
    e->v1.y = y;
    e->v2.y = y+yOffsetForDirection(d);
    
    if(e->v2.x < 0 || e->v2.y < 0 || e->v2.x >= WIDTH || e->v2.y >= HEIGHT)
        e->distance = MAX_DISTANCE;
    
    if(e->v1.x==e->v2.x || e->v1.y==e->v2.y)
        e->distance = terrainMovementPoints(map[e->v2.x][e->v2.y].terrain);
}

- (void)generateMap
{
    srand(MAP_SEED);
    // make everything ground to start with, with a void border
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
        {
            thePath[x][y] = NO;
            map[x][y].x = x;
            map[x][y].y = y;
            if(x==0 || y==0 || x==WIDTH-1 || y==HEIGHT-1)
                map[x][y].terrain = DPFTerrainVoid;                
            else
                map[x][y].terrain = DPFTerrainGround;
        }
    
    
    int terrainCounts[DPFTerrainCount] = {0,0,2*(8/SIZE_FACTOR),2*(8/SIZE_FACTOR),2*(8/SIZE_FACTOR),4*(8/SIZE_FACTOR),6*(8/SIZE_FACTOR)};
    
    // random terrain and spread it out
    for(int t=0;t<DPFTerrainCount;t++)
    {
        DPFTerrain terrain = (DPFTerrain)t;
        for(int i=0;i<terrainCounts[t];i++)
        {
            int x = rand()%WIDTH;
            int y = rand()%HEIGHT;
            if(map[x][y].terrain==DPFTerrainGround)
            {
                map[x][y].terrain = terrain;
                [self spreadOutTerrain:terrain fromX:x andY:y];
            }
        }    
    }
    
    int edge_count = 0;
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
            for(int d=0;d<DIRECTIONS;d++)
            {
                [self fillEdgeFromX:x Y:y direction:d edge:&edge[x][y][d]];
                edge_count++;
            }
    NSLog(@"Created %d edge",edge_count);
}

DPFVert* allVerts[MAX_VERTS];
int allVertsCount;

CGFloat distance[MAX_VERTS];
DPFVert* prevVerts[MAX_VERTS];

DPFVert* pathVerts[MAX_VERTS];
int pathVertsCount;

- (int)extractMinDistanceIndexFromVertsToSearch
{
    int foundVertIndex = -1;
    
    // TODO: find min distance
    
    
    return foundVertIndex;
}

- (void)Dijkstra
{
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
        {
            allVerts[y*HEIGHT+x] = &map[x][y];
            allVertsCount = 0;
            map[x][y].inPath = NO;
        }    
    
    for(int i=0;i<MAX_VERTS;i++)
    {
        distance[i]=-1;
        prevVerts[i]=NULL;     // pie
        pathVerts[i]=NULL;     // S
    }
 
    distance[0] = 0.0f; // vert 0 is the start point
        
    while(allVertsCount>0)
    {
        int uIndex = [self extractMinDistanceIndexFromVertsToSearch];
        if(distance[uIndex]==-1)
            break;
        
        DPFVert *u = allVerts[uIndex];
        allVerts[uIndex] = NULL;
        allVertsCount--;
        
        for(int d=0;d<DIRECTIONS;d++)
        {
            int xOff = u->x+xOffsetForDirection(d);
            int yOff = u->y+yOffsetForDirection(d);
            if(xOff<0 || yOff<0 || xOff>=WIDTH || yOff>=HEIGHT)
                continue;
            
            DPFVert *v = &map[xOff][yOff];
            int vIndex = yOff*HEIGHT+xOff;
            if(v->inPath)
                continue;
            
            CGFloat distToV = distance[uIndex] + terrainMovementPoints(v->terrain);
            if(distToV < distance[vIndex])
            {
                distance[vIndex] = distToV;
                prevVerts[vIndex] = u;
                // decrease key
            
            }
            
            
            
        }


    }
}

- (void)findPath
{
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
        {
            if(x==(int)((float)y*((float)WIDTH/(float)HEIGHT)))
                thePath[x][y] = YES;
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
        
        [self findPath];
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSLog(@"Draw rect!\n");
    // Get the graphics context and clear it
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextClearRect(ctx, dirtyRect);
    
    // Draw the map
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
        {
            CGFloat r = terrainColor[map[x][y].terrain].r;
            CGFloat g = terrainColor[map[x][y].terrain].g;
            CGFloat b = terrainColor[map[x][y].terrain].b;
            //NSLog(@"r=%0.2f g=%0.2f b=%0.2f",r,g,b);
            
            CGContextSetRGBFillColor(ctx, r, g, b, 1);
            CGContextFillRect(ctx, CGRectMake(x*PIX_W, y*PIX_H, PIX_W, PIX_H));
        }

    
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
        {
            if(thePath[x][y])
            {
                CGContextSetRGBFillColor(ctx, 1, 1, 0, 1);
                CGContextFillEllipseInRect(ctx, CGRectMake(x*PIX_W, y*PIX_H, PIX_W, PIX_H));                
            }
        }
}

@end
