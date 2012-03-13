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

#define DRAW_STEPS 0

#define SIZE_FACTOR 2  // can be 1,2,4,8
#define MAP_SEED    5

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
#define MAX_VERTS (WIDTH*HEIGHT)

#define PIX_W  (1024/WIDTH)
#define PIX_H  (768/HEIGHT)

typedef enum
{
    DPFTerrainVoid=0,
    DPFTerrainWater,
    DPFTerrainGround,
    DPFTerrainHills,
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
    int  index;
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
        case DPFTerrainVoid:     return 9999;
        case DPFTerrainGround:   return 1.0;
        case DPFTerrainHills:    return 2.0;
        case DPFTerrainWater:    return 8.0;
        case DPFTerrainForest:   return 3.0;
        case DPFTerrainMountain: return 5.0;
        case DPFTerrainSwamp:    return 4.0;
        default: return 9999;
    }
    return 9999;
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
            if(map[w][h].terrain == DPFTerrainWater)
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
            map[x][y].inPath = NO;
            map[x][y].index = y*WIDTH+x;
            if(x==0 || y==0 || x==WIDTH-1 || y==HEIGHT-1)
                map[x][y].terrain = DPFTerrainVoid;                
            else
                map[x][y].terrain = DPFTerrainWater;
        }
    
    
    int terrainCounts[DPFTerrainCount] = {0,0,2*(8/SIZE_FACTOR),2*(8/SIZE_FACTOR),2*(8/SIZE_FACTOR),3*(8/SIZE_FACTOR)+1,5*(8/SIZE_FACTOR)+1};
    
    // random terrain and spread it out
    for(int t=0;t<DPFTerrainCount;t++)
    {
        DPFTerrain terrain = (DPFTerrain)t;
        for(int i=0;i<terrainCounts[t];i++)
        {
            int x = rand()%WIDTH;
            int y = rand()%HEIGHT;
            if(map[x][y].terrain==DPFTerrainWater)
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
int allVertsCount=0;

DPFVert* unsettledVerts[MAX_VERTS];
int unsettledVertCount=0;

CGFloat dist[MAX_VERTS];
DPFVert* prev[MAX_VERTS];

DPFVert* settledVerts[MAX_VERTS];
int settledVertCount=0;

- (int)extractMinDistanceIndexFromVertsToSearch
{
    int foundVertIndex = -1;
    CGFloat minDist = MAX_DISTANCE;
    
    for(int i=0;i<unsettledVertCount;i++)
    {
        DPFVert *vert = unsettledVerts[i];
        if(minDist > dist[vert->index])
        {
            minDist = dist[vert->index];
            foundVertIndex = i;
        }
    }
    
    if(foundVertIndex>=0)
    {
        DPFVert *temp = unsettledVerts[foundVertIndex];
        unsettledVerts[foundVertIndex] = unsettledVerts[unsettledVertCount-1];
        unsettledVerts[unsettledVertCount-1] = temp;
        foundVertIndex = unsettledVertCount-1;
    }
    
    return foundVertIndex;
}

- (void)resetDijkstra
{
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
        {
            if(&map[x][y]==NULL)
                NSLog(@"Null map vert.");
            allVerts[y*WIDTH+x] = &map[x][y];
            allVertsCount++;
            map[x][y].inPath = NO;
            map[x][y].index = y*WIDTH+x;
        }    
    
    for(int i=0;i<MAX_VERTS;i++)
    {
        dist[i]=MAX_DISTANCE;
        prev[i]=NULL;
        settledVerts[i]=NULL;
    }
    
    DPFVert *startVert = allVerts[WIDTH+1];
    int startIndex = startVert->index;
    
    unsettledVerts[unsettledVertCount++] = allVerts[startIndex];
    dist[startIndex] = 0.0f; // vert 0 is the start point
}

- (BOOL)Dijkstra
{
    if(unsettledVertCount==0)
        return NO;
    
    int qIndex = [self extractMinDistanceIndexFromVertsToSearch];
    
    DPFVert *v = NULL;
    DPFVert *u = unsettledVerts[qIndex];
    int uIndex = u->index;
    if(dist[uIndex]==MAX_DISTANCE)
        return NO;
    
    unsettledVerts[qIndex] = NULL;
    unsettledVertCount--;
    settledVerts[settledVertCount++] = u;
    
    if(u->x==WIDTH-2 && u->y==HEIGHT-2)
        return NO;
    
    //u->inPath = YES;
    //NSLog(@"Removing Vert %04d @(%d,%d) from unsettledVerts(%d) to settledVerts(%d).",u->index,u->x,u->y,unsettledVertCount,settledVertCount);
    
    // check each adjacent vert
    for(int d=0;d<DIRECTIONS;d++)
    {
        int xOff = u->x+xOffsetForDirection(d);
        int yOff = u->y+yOffsetForDirection(d);
        if(xOff<0 || yOff<0 || xOff>=WIDTH || yOff>=HEIGHT)
            continue;
        
        v = &map[xOff][yOff];
        int vIndex = v->index;
        //if(v->inPath)
        //    continue;
        
        CGFloat distToV = terrainMovementPoints(v->terrain);
        if(u->x!=v->x && u->y!=v->y)
            distToV *= 1.4;
        
        if(dist[vIndex] > dist[uIndex] + distToV)
        {
            dist[vIndex] = dist[uIndex] + distToV;
            prev[vIndex] = u;
            unsettledVerts[unsettledVertCount++] = v;
            //NSLog(@"Adding   Vert %04d @(%d,%d) to unsettledVerts(%d).",v->index,v->x,v->y,unsettledVertCount);
        }
    }
    
    return YES;
}

- (void)findPath
{
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
        {
            //if(x==(int)((float)y*((float)WIDTH/(float)HEIGHT)))
            //    thePath[x][y] = YES;
            thePath[x][y] = NO;
        }
    
    DPFVert *current = allVerts[(HEIGHT-2)*WIDTH+(WIDTH-2)];
    while(current)
    {
        thePath[current->x][current->y] = YES;
        current = prev[current->index];
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
        
        [self resetDijkstra];
        [self setNeedsDisplay:YES];
        
        if(DRAW_STEPS)
            [NSTimer scheduledTimerWithTimeInterval:0.025f target:self selector:@selector(step:) userInfo:nil repeats:YES];
        else
        {
            while([self Dijkstra]);
            [self findPath];
            [self setNeedsDisplay:YES];
        }
    }
    
    return self;
}


- (void)step:(NSTimer*)timer
{
    if(![self Dijkstra])
    {
        [timer invalidate];
        [self findPath];
    }
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
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
    
    
    char buff[64];
    CGContextSelectFont(ctx, "Courier", SIZE_FACTOR/3, kCGEncodingMacRoman);
    CGContextSetTextDrawingMode(ctx, kCGTextFill);
    CGAffineTransform xform = CGAffineTransformMake(1.0,  0.0,
                                                    0.0,  1.0,
                                                    0.0,  0.0);
    CGContextSetTextMatrix(ctx, xform);
    
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
        {
            if(thePath[x][y])
            {
                CGContextSetRGBFillColor(ctx, 1, 1, 0, 1);
                CGContextFillEllipseInRect(ctx, CGRectMake(x*PIX_W, y*PIX_H, PIX_W, PIX_H));
            }
            // Draw the text TrailsintheSand.com in light blue
            if(dist[y*WIDTH+x]>=MAX_DISTANCE)
                snprintf(buff, 64, "-00-");
            else if((int)dist[y*WIDTH+x]>=9999)
                snprintf(buff, 64, "----");
            else
                snprintf(buff, 64, "%04d",(int)dist[y*WIDTH+x]);
            CGContextSetRGBFillColor(ctx, 0, 0, 0, 1);
            CGContextShowTextAtPoint(ctx, x*PIX_W +SIZE_FACTOR/10 , y*PIX_H + PIX_H/2, buff, strlen(buff));                            
        }
}

@end
