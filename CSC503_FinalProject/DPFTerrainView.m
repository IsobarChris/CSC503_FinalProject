//
//  DPFTerrainView.m
//  CSC503_FinalProject
//
//  Created by MacBookPro on 3/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DPFTerrainView.h"
#import <QuartzCore/QuartzCore.h>
#include <OpenCL/opencl.h>

// size 8, seed 5
// size 4, seed 6
// size 2, seed 6

#define DRAW_STEPS 0

CGFloat   SIZE_FACTOR = 64.0f;
NSInteger   MAP_SEED  = 9;
//#define SIZE_FACTOR 32.0f  // can be 1,2,4,8
//#define MAP_SEED    9

#define WIDTH  ((int)(1024.0f/SIZE_FACTOR))
#define HEIGHT  ((int)(768.0f/SIZE_FACTOR))
#define DIRECTIONS 8  // can be 4 or 8  

#define xstr(s) str(s)
#define str(s) #s

#define DIR_N  0
#define DIR_S  1
#define DIR_E  2
#define DIR_W  3
#define DIR_NW 4
#define DIR_NE 5
#define DIR_SW 6
#define DIR_SE 7

#define MAX_DISTANCE 10000000.0
//#define MAX_VERTS (WIDTH*HEIGHT)
#define MAX_VERTS (2048*1536)

#define PIX_W  (1024.0f/(float)WIDTH)
#define PIX_H  (768.0f/(float)HEIGHT)

#define WH(x,y) (y*(WIDTH)+x)

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

float terrainMovementPoints(DPFTerrain terrain)
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
    DPFVert map[MAX_VERTS];
    DPFTerrainColor terrainColor[DPFTerrainCount];
    BOOL thePath[MAX_VERTS];
}

@end

@implementation DPFTerrainView

@synthesize textField;

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
            if(map[WH(w,h)].terrain == DPFTerrainWater)
            {
                map[WH(w,h)].terrain = terrain;
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
        e->distance = terrainMovementPoints(map[WH(e->v2.x,e->v2.y)].terrain);
}

- (void)generateMap
{
    srand(MAP_SEED);
    // make everything ground to start with, with a void border
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
        {
            thePath[WH(x,y)] = NO;
            map[WH(x,y)].x = x;
            map[WH(x,y)].y = y;
            map[WH(x,y)].index = y*WIDTH+x;
            if(x==0 || y==0 || x==WIDTH-1 || y==HEIGHT-1)
                map[WH(x,y)].terrain = DPFTerrainVoid;                
            else
                map[WH(x,y)].terrain = DPFTerrainWater;
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
            if(map[WH(x,y)].terrain==DPFTerrainWater)
            {
                map[WH(x,y)].terrain = terrain;
                [self spreadOutTerrain:terrain fromX:x andY:y];
            }
        }    
    }
    /*
    int edge_count = 0;
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
            for(int d=0;d<DIRECTIONS;d++)
            {
                [self fillEdgeFromX:x Y:y direction:d edge:&edge[x][y][d]];
                edge_count++;
            }
    NSLog(@"Created %d edge",edge_count);
    */ 
}

DPFVert* allVerts[MAX_VERTS];
int allVertsCount=0;

int unsettledVertsHeap[MAX_VERTS];
int unsettledVertCount=0;

float   dist[MAX_VERTS];
int     prev[MAX_VERTS];

DPFVert* settledVerts[MAX_VERTS];
int settledVertCount=0;

// min heap source drawn from: http://en.wikibooks.org/wiki/Data_Structures/Min_and_Max_Heaps
#define LEFT(i)  (2*i)
#define RIGHT(i) (2*i+1)
- (void)insertVert:(DPFVert*)vert
{
    unsettledVertsHeap[unsettledVertCount++] = vert->index;
    int i = unsettledVertCount-1;
    while(i>0)
    {
        if(dist[unsettledVertsHeap[i/2]] < dist[unsettledVertsHeap[i]])
            break;
        int temp = unsettledVertsHeap[i/2];
        unsettledVertsHeap[i/2] = unsettledVertsHeap[i];
        unsettledVertsHeap[i] = temp;        
        i/=2;
    }
    
    if(0)
    {
        for(int k=0;k<100;k++)
            for(int i=0;i<100;i++)
                   slowDown = k * i;                            
        
    }
}

dispatch_semaphore_t semaphore = NULL;
- (void)insertVertP1:(DPFVert*)vert
{
    if(semaphore==NULL)
         semaphore = dispatch_semaphore_create(1);
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    //NSLog(@"insert %d start",vert->index);
    unsettledVertsHeap[unsettledVertCount++] = vert->index;
    int i = unsettledVertCount-1;
    while(i>0)
    {
        if(dist[unsettledVertsHeap[i/2]] < dist[unsettledVertsHeap[i]])
            break;
        int temp = unsettledVertsHeap[i/2];
        unsettledVertsHeap[i/2] = unsettledVertsHeap[i];
        unsettledVertsHeap[i] = temp;        
        i/=2;
    }
    
    if(0)
    {
        for(int k=0;k<100;k++)
            for(int i=0;i<100;i++)
                slowDown = k * i;                            
        
    }
    //NSLog(@"insert %d end",vert->index);
    dispatch_semaphore_signal(semaphore);
}

static int slowDown;
- (DPFVert*)removeMinVert
{
    int savedMinVert = unsettledVertsHeap[0];
    unsettledVertsHeap[0] = unsettledVertsHeap[--unsettledVertCount];
    unsettledVertsHeap[unsettledVertCount] = -1;
    int i=0;
    while(i<unsettledVertCount)
    {
        int minIndex = i;
        if(LEFT(i)<unsettledVertCount && dist[unsettledVertsHeap[LEFT(i)]] < dist[unsettledVertsHeap[minIndex]])
            minIndex = LEFT(i);
        if(RIGHT(i)<unsettledVertCount && dist[unsettledVertsHeap[RIGHT(i)]] < dist[unsettledVertsHeap[minIndex]])
            minIndex = RIGHT(i);
        if(minIndex!=i)
        {
            int temp = unsettledVertsHeap[i];
            unsettledVertsHeap[i] = unsettledVertsHeap[minIndex];
            unsettledVertsHeap[minIndex] = temp;
            i = minIndex;
        }
        else
            break;
    }
    
    return allVerts[savedMinVert];
}

- (void)resetDijkstra
{
    allVertsCount=0;
    unsettledVertCount=0;
    settledVertCount=0;    
    
    for(int i=0;i<MAX_VERTS;i++)
        unsettledVertsHeap[i] = -1;
        
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
        {
            if(&map[WH(x,y)]==NULL)
                NSLog(@"Null map vert.");
            allVerts[y*WIDTH+x] = &map[WH(x,y)];
            allVertsCount++;
            map[WH(x,y)].index = y*WIDTH+x;
        }    
    
    for(int i=0;i<MAX_VERTS;i++)
    {
        dist[i]=MAX_DISTANCE;
        prev[i]=-1;
        settledVerts[i]=NULL;
    }
    
    DPFVert *startVert = allVerts[WIDTH+1];
    int startIndex = startVert->index;
    
    [self insertVert:allVerts[startIndex]];
    dist[startIndex] = 0.0f; // vert 0 is the start point
}

- (BOOL)Dijkstra
{
    if(unsettledVertCount==0)
        return NO; // nothing to do
    
    DPFVert *u = [self removeMinVert];
    
    DPFVert *v = NULL;
    int uIndex = u->index;
    if(dist[uIndex]==MAX_DISTANCE)
        return NO;

    // Add this node to the list of settled verts, it's as short as it gets
    settledVerts[settledVertCount++] = u;
    
    // This is the end node, we're done
    if(u->x==WIDTH-2 && u->y==HEIGHT-2)
        return NO;
    
    // check each adjacent vert, there are 4 or 8 edges (based on the directions define), check them all
    for(int d=0;d<DIRECTIONS;d++)
    {
        int xOff = u->x+xOffsetForDirection(d);
        int yOff = u->y+yOffsetForDirection(d);
        if(xOff<0 || yOff<0 || xOff>=WIDTH || yOff>=HEIGHT)
            continue; // off the grid, ignore this edge
        
        v = &map[WH(xOff,yOff)];
        int vIndex = v->index;
        
        CGFloat distToV = terrainMovementPoints(v->terrain);
        if(u->x!=v->x && u->y!=v->y)
            distToV *= 1.4;
        
        if(dist[vIndex] > dist[uIndex] + distToV)
        {
            dist[vIndex] = dist[uIndex] + distToV;
            prev[vIndex] = uIndex;
            [self insertVert:v];
        }
    }
    
    return YES;
}

static dispatch_queue_t queue = NULL;

- (BOOL)DijkstraP1
{
    if(unsettledVertCount==0)
        return NO; // nothing to do
    
    if(!queue)
        queue = dispatch_queue_create("Direction Concurrent Queue", DISPATCH_QUEUE_CONCURRENT);
    
    DPFVert *u = [self removeMinVert];
    
    int uIndex = u->index;
    if(dist[uIndex]==MAX_DISTANCE)
        return NO;
    
    // Add this node to the list of settled verts, it's as short as it gets
    settledVerts[settledVertCount++] = u;
    
    // This is the end node, we're done
    if(u->x==WIDTH-2 && u->y==HEIGHT-2)
        return NO;
    
    dispatch_apply(8, queue, ^(size_t d) 
    {
        int xOff = u->x+xOffsetForDirection(d);
        int yOff = u->y+yOffsetForDirection(d);
        if(xOff<0 || yOff<0 || xOff>=WIDTH || yOff>=HEIGHT)
            return; // off the grid, ignore this edge
        
        DPFVert *v = &map[WH(xOff,yOff)];
        int vIndex = v->index;
        
        CGFloat distToV = terrainMovementPoints(v->terrain);
        if(u->x!=v->x && u->y!=v->y)
            distToV *= 1.4;
        
        if(dist[vIndex] > dist[uIndex] + distToV)
        {
            dist[vIndex] = dist[uIndex] + distToV;
            prev[vIndex] = uIndex;
            [self insertVertP1:v];
        }
    });
    
    return YES;
}

typedef struct
{
    DPFTerrain terrain;
    char       shouldProcess;
    float      distanceFromSource;
    int        nearestNeighborIndex;
}DPFNode;

DPFNode altMap[MAX_VERTS];

- (void)findAltPath
{
    NSLog(@"Finding Path...");
    
    int currentIndex = (HEIGHT-1)*WIDTH-2;
    for(int i=0;i<WIDTH*HEIGHT;i++)
    {
        dist[i] = altMap[i].distanceFromSource;
        thePath[i] = NO;
    }

    thePath[WIDTH+1] = YES;
    thePath[currentIndex] = YES;
    
    
    while(currentIndex != WIDTH+1)
    {
        currentIndex = altMap[currentIndex].nearestNeighborIndex;
        thePath[currentIndex] = YES;
    }
    
    
    NSLog(@"Done finding path.");
     
    if(0)
    {
        //printf("Current Index: %d,%d\n",currentIndex%WIDTH,currentIndex/WIDTH); 

        int minIndex = currentIndex;
        float minDistance = MAX_DISTANCE;
        
        for(int x=-1;x<2;x++)
            for(int y=-1;y<2;y++)
                if(x || y)
                {
                    int neighborIndex = currentIndex + y*WIDTH+x;
                    //printf("  Checking Index: %d,%d  (%0.1f)\n",neighborIndex%WIDTH,neighborIndex/WIDTH,altMap[neighborIndex].distanceFromSource);
                    
                    if(altMap[neighborIndex].distanceFromSource < minDistance)
                    {
                        minIndex = neighborIndex;
                        minDistance = altMap[neighborIndex].distanceFromSource;
                    }
                }
        
        //printf("  Selecting Index: %d,%d  (%0.1f)\n",minIndex%WIDTH,minIndex/WIDTH,altMap[minIndex].distanceFromSource);
        thePath[minIndex] = YES;
        currentIndex = minIndex;
    }
}

-(void)setupAltDijkstra
{
    for(int i=0;i<WIDTH*HEIGHT;i++)
    {
        altMap[i].terrain = map[i].terrain;
        altMap[i].shouldProcess = 1;
        altMap[i].distanceFromSource = MAX_DISTANCE;
        altMap[i].nearestNeighborIndex = i; // set to self for now
    }
    
    altMap[WIDTH+1].distanceFromSource = 0;
}

const char *altKernelSource = "\n" \
"                                                                                      \n" \
"typedef struct                                                                        \n" \
"{                                                                                     \n" \
"    int        terrain;                                                               \n" \
"    char       shouldProcess;                                                         \n" \
"    float      distanceFromSource;                                                    \n" \
"    int        nearestNeighborIndex;                                                  \n" \
"}DPFNode;                                                                             \n" \
"                                                                                      \n" \
"  float terrainMovementPoints(int terrain)                                            \n" \
"  {                                                                                   \n" \
"      switch (terrain)                                                                \n" \
"      {                                                                               \n" \
"          case 0: return 9999.0;                                                      \n" \
"          case 2: return 1.0;                                                         \n" \
"          case 3: return 2.0;                                                         \n" \
"          case 1: return 8.0;                                                         \n" \
"          case 4: return 3.0;                                                         \n" \
"          case 5: return 5.0;                                                         \n" \
"          case 6: return 4.0;                                                         \n" \
"          default: return 9999.0;                                                     \n" \
"      }                                                                               \n" \
"      return 9999.0;                                                                  \n" \
"  }                                                                                   \n" \
"                                                                                      \n" \
"                                                                                      \n" \
"__kernel void altDijkstraWork(                                                        \n" \
"__global DPFNode* Grid,                                                               \n" \
"__global int*     widthB,                                                             \n" \
"__global int*     heightB,                                                            \n" \
"__global int*     done                                                                \n" \
"                          )                                                           \n" \
"{                                                                                     \n" \
"   int k = get_global_id(0);                                                          \n" \
"   int width = *widthB;                                                               \n" \
"   int height = *heightB;                                                             \n" \
"                                                                                      \n" \
"   if(Grid[k].shouldProcess)                                                          \n" \
"   {                                                                                  \n" \
"    *done = 0;                                                                        \n" \
"                                                                                      \n" \
"    int notifyNeighbors = 0;                                                          \n" \
"    for(int x=-1;x<2;x++)                                                             \n" \
"        for(int y=-1;y<2;y++)                                                         \n" \
"            if(x || y)                                                                \n" \
"            {                                                                         \n" \
"                int index = k+y*width+x;                                              \n" \
"                if(index>0 && index<width*height)                                     \n" \
"                {                                                                     \n" \
"                    float newDistance = Grid[index].distanceFromSource;               \n" \
"                    if(x!=0 && y!=0) // diagonal movement                             \n" \
"                        newDistance += (terrainMovementPoints(Grid[k].terrain)*1.4);  \n" \
"                    else                                                              \n" \
"                        newDistance += terrainMovementPoints(Grid[k].terrain);        \n" \
"                    if(newDistance < Grid[k].distanceFromSource)                      \n" \
"                    {                                                                 \n" \
"                        Grid[k].distanceFromSource = newDistance;                     \n" \
"                        Grid[k].nearestNeighborIndex = index;                         \n" \
"                        notifyNeighbors = 1;                                          \n" \
"                    }                                                                 \n" \
"                }                                                                     \n" \
"            }                                                                         \n" \
"                                                                                      \n" \
"    if(notifyNeighbors)                                                               \n" \
"        for(int x=-1;x<2;x++)                                                         \n" \
"            for(int y=-1;y<2;y++)                                                     \n" \
"                if(x || y)                                                            \n" \
"                {                                                                     \n" \
"                    int index = k+y*width+x;                                          \n" \
"                    if(index>0 && index<width*height)                                 \n" \
"                        Grid[index].shouldProcess = 1;                                \n" \
"                }                                                                     \n" \
"                                                                                      \n" \
"    Grid[k].shouldProcess = 0;                                                        \n" \
"   }                                                                                  \n" \
"}                                                                                     \n" \
"\n";

void blah(DPFNode *Grid,int done)
{
    int k=0;
    
    int notifyNeighbors = 0;
    for(int x=-1;x<2;x++)
        for(int y=-1;y<2;y++)
            if(x || y)
            {
                int index = k+y*WIDTH+x;
                if(index>0 && index<WIDTH*HEIGHT)
                {
                    float newDistance = Grid[index].distanceFromSource;
                    if(x!=0 && y!=0) // diagonal movement
                        newDistance += (terrainMovementPoints(Grid[k].terrain)*1.4);
                    else
                        newDistance += terrainMovementPoints(Grid[k].terrain);
                    if(newDistance < Grid[k].distanceFromSource)
                    {
                        Grid[k].distanceFromSource = newDistance;
                        notifyNeighbors = 1;
                    }
                }
            }
    
    if(notifyNeighbors)
        for(int x=-1;x<2;x++)
            for(int y=-1;y<2;y++)
                if(x || y)
                {
                    int index = k+y*WIDTH+x;
                    if(index>0 && index<WIDTH*HEIGHT)
                        Grid[index].shouldProcess = 1;
                }
    

}


-(BOOL)AltDijkstra
{
    int err;                            // error code returned from api calls
    size_t global;                      // global domain size for our calculation
    size_t local;                       // local domain size for our calculation
    cl_device_id device_id;             // compute device id 
    cl_context context;                 // compute context
    cl_command_queue commands;          // compute command queue
    cl_program program;                 // compute program
    cl_kernel kernel;                   // compute kernel
    cl_mem localMap;                    // device memory used for the input array
    cl_mem doneBuf;
    int done = 0;
    cl_mem widthBuff;
    int width = WIDTH;
    cl_mem heightBuff;
    int height = HEIGHT;

    // Connect to a compute device
    int gpu = 1;
    err = clGetDeviceIDs(NULL, gpu ? CL_DEVICE_TYPE_GPU : CL_DEVICE_TYPE_CPU, 1, &device_id, NULL);
    if (err != CL_SUCCESS) { printf("Error: Failed to create a device group! %d\n",err); return NO; }
    
    // Create a compute context 
    context = clCreateContext(0, 1, &device_id, NULL, NULL, &err);
    if (!context) { printf("Error: Failed to create a compute context!\n"); return NO; }
    
    // Create a command commands
    commands = clCreateCommandQueue(context, device_id, 0, &err);
    if (!commands) { printf("Error: Failed to create a command commands!\n"); return NO; }
    
    // Create the compute program from the source buffer
    program = clCreateProgramWithSource(context, 1, (const char **) & altKernelSource, NULL, &err);
    if (!program) { printf("Error: Failed to create compute program!\n"); return NO; }
    
    // Build the program executable
    err = clBuildProgram(program, 0, NULL, NULL, NULL, NULL);
    if (err != CL_SUCCESS)
    {
        size_t len;
        char buffer[2048];
        
        printf("Error: Failed to build program executable!\n");
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, sizeof(buffer), buffer, &len);
        printf("%s\n", buffer);
        return NO;
    }
    
    // Create the compute kernel in the program we wish to run
    kernel = clCreateKernel(program, "altDijkstraWork", &err);
    if (!kernel || err != CL_SUCCESS) { printf("Error: Failed to create compute kernel!\n"); return NO; }
    
    // Create the array in device memory for the sort
    localMap = clCreateBuffer(context,  CL_MEM_READ_WRITE,  sizeof(DPFNode) * WIDTH * HEIGHT, NULL, NULL);
    if (!localMap) { printf("Error: Failed to allocate device memory!\n"); return NO; }    
    
    // Create the array in device memory for the sort
    doneBuf = clCreateBuffer(context,  CL_MEM_READ_WRITE,  sizeof(int), NULL, NULL);
    if (!doneBuf) { printf("Error: Failed to allocate device memory!\n"); return NO; }    
    
    // Create the array in device memory for the sort
    widthBuff = clCreateBuffer(context,  CL_MEM_READ_WRITE,  sizeof(int), NULL, NULL);
    if (!widthBuff) { printf("Error: Failed to allocate device memory!\n"); return NO; }    
    
    // Create the array in device memory for the sort
    heightBuff = clCreateBuffer(context,  CL_MEM_READ_WRITE,  sizeof(int), NULL, NULL);
    if (!heightBuff) { printf("Error: Failed to allocate device memory!\n"); return NO; }    
    
    // Write our data set into the input array in device memory 
    err = clEnqueueWriteBuffer(commands, localMap, CL_TRUE, 0, sizeof(DPFNode) * WIDTH * HEIGHT, altMap, 0, NULL, NULL);
    if (err != CL_SUCCESS) { printf("Error: Failed to write to source array!\n"); return NO; }

    // Write our data set into the input array in device memory 
    err = clEnqueueWriteBuffer(commands, widthBuff, CL_TRUE, 0, sizeof(int), &width, 0, NULL, NULL);
    if (err != CL_SUCCESS) { printf("Error: Failed to write to source array!\n"); return NO; }

    // Write our data set into the input array in device memory 
    err = clEnqueueWriteBuffer(commands, heightBuff, CL_TRUE, 0, sizeof(int), &height, 0, NULL, NULL);
    if (err != CL_SUCCESS) { printf("Error: Failed to write to source array!\n"); return NO; }
    
    
    // Get the maximum work group size for executing the kernel on the device
    err = clGetKernelWorkGroupInfo(kernel, device_id, CL_KERNEL_WORK_GROUP_SIZE, sizeof(local), &local, NULL);
    if (err != CL_SUCCESS) { printf("Error: Failed to retrieve kernel work group info! %d\n", err); return NO; }
    
    global = WIDTH*HEIGHT;
    if(local>global)
        local = global;
    //global = 1;
    //local = 1;
    
    while(!done)
    {
        done = 1;
        
        // Write our data set into the input array in device memory 
        err = clEnqueueWriteBuffer(commands, doneBuf, CL_TRUE, 0, sizeof(int), &done, 0, NULL, NULL);
        if (err != CL_SUCCESS) { printf("Error: Failed to write to source array!\n"); return NO; }
                
        // Execute the kernel
        err  = 0;
        err  = clSetKernelArg(kernel, 0, sizeof(cl_mem), &localMap);
        err |= clSetKernelArg(kernel, 1, sizeof(cl_mem), &widthBuff);
        err |= clSetKernelArg(kernel, 2, sizeof(cl_mem), &heightBuff);
        err |= clSetKernelArg(kernel, 3, sizeof(cl_mem), &doneBuf);
        if (err != CL_SUCCESS) { printf("Error: Failed to set kernel arguments! %d\n", err); return NO; }
        
        err = clEnqueueNDRangeKernel(commands, kernel, 1, NULL, &global, &local, 0, NULL, NULL);
        if (err) { printf("Error: Failed to execute kernel (%d)!\n",err); return EXIT_FAILURE; } 
        
        // Wait for all the commands to get serviced before reading back results
        clFinish(commands);
        
        // Read back the results from the device to verify the output
        err = clEnqueueReadBuffer( commands, doneBuf, CL_TRUE, 0, sizeof(int), &done, 0, NULL, NULL );  
        if (err != CL_SUCCESS) { printf("Error: Failed to read output array! %d\n", err); return NO; }  
        
        //NSLog(@"Done = %d",done);
    }

    // Read back the results from the device to verify the output
    err = clEnqueueReadBuffer( commands, localMap, CL_TRUE, 0, sizeof(DPFNode) * WIDTH * HEIGHT, altMap, 0, NULL, NULL );  
    if (err != CL_SUCCESS) { printf("Error: Failed to read output array! %d\n", err); return NO; }
    
    //for(int i=0;i<20;i++)
    //    printf("Alt %d (%d %d %0.1f)\n",i,altMap[i].terrain,altMap[i].shouldProcess,altMap[i].distanceFromSource);
    
    
    // Shutdown and cleanup
    clReleaseMemObject(localMap);
    clReleaseProgram(program);
    clReleaseKernel(kernel);
    clReleaseCommandQueue(commands);
    clReleaseContext(context);
    
    return NO;
}



//"   __global int*  A,                       \n" \
"   const unsigned int len)                 \n" \

const char *kernelSource = "\n" \
"  \n" \
"typedef struct\n" \
"{\n" \
"    int x,y;\n" \
"    int terrain;\n" \
"    int  index;\n" \
"}DPFVert;\n" \
"  \n" \
"  int xOffsetForDirection(int d);  \n" \
"  int yOffsetForDirection(int d);  \n" \
"  float terrainMovementPoints(int terrain);  \n" \
"  \n" \
"  \n" \
"  float terrainMovementPoints(int terrain)\n" \
"  {\n" \
"      switch (terrain) \n" \
"      {\n" \
"          case 0:     return 9999;\n" \
"          case 2:   return 1.0;\n" \
"          case 3:    return 2.0;\n" \
"          case 1:    return 8.0;\n" \
"          case 4:   return 3.0;\n" \
"          case 5: return 5.0;\n" \
"          case 6:    return 4.0;\n" \
"          default: return 9999;\n" \
"      }\n" \
"      return 9999;\n" \
"  }\n" \
"  \n" \
"  int xOffsetForDirection(int d)  \n" \
"  {  \n" \
"      switch (d)   \n" \
"      {  \n" \
"          case 0: return  0; // N  \n" \
"          case 1: return  0; // S  \n" \
"          case 2: return  1; // E  \n" \
"          case 3: return -1; // W  \n" \
"          case 4: return -1; // NW  \n" \
"          case 5: return  1; // NE  \n" \
"          case 6: return -1; // SW  \n" \
"          case 7: return  1; // SE  \n" \
"      }  \n" \
"      return 0;  \n" \
"  }  \n" \
"    \n" \
"  int yOffsetForDirection(int d)  \n" \
"  {  \n" \
"      switch (d)   \n" \
"      {  \n" \
"          case 0: return -1; // N  \n" \
"          case 1: return  1; // S  \n" \
"          case 2: return  0; // E  \n" \
"          case 3: return  0; // W  \n" \
"          case 4: return -1; // NW  \n" \
"          case 5: return -1; // NE  \n" \
"          case 6: return  1; // SW  \n" \
"          case 7: return  1; // SE  \n" \
"      }  \n" \
"      return 0;      \n" \
"  }  \n" \
"  \n" \
"  \n" \
"  \n" \
"  \n" \
"__kernel void dijkstraWork(                \n" \
"__global DPFVert* map,                     \n" \
"const unsigned int source,                 \n" \
"__global int* heap,                        \n" \
"const int heapSize,                        \n" \
"__global float* dist,                      \n" \
"__global int*   prev                       \n" \
"                          )                \n" \
"{                                          \n" \
"   float SIZE_FACTOR = 64.0;               \n" \
"   int width = "xstr(WIDTH)";              \n" \
"   int d = get_global_id(0);               \n" \
"   int x = source % width;                 \n" \
"   int y = source / width;                 \n" \
"   int uIndex = source;                    \n" \
"                                           \n" \
"int xOff = x+xOffsetForDirection(d);       \n" \
"int yOff = y+yOffsetForDirection(d);       \n" \
"                                           \n" \
"   //printf((const char*)\"%d:(%d,%d %f %d) xOff = %d  yOff = %d\\n\",d,x,y,SIZE_FACTOR,width,xOff,yOff);\n" \
"                                           \n" \
"if(xOff<0 || yOff<0 || xOff>=" xstr(WIDTH) " || yOff>=" xstr(HEIGHT) ") \n" \
"return; // off the grid, ignore this edge  \n" \
"                                           \n" \
"__global DPFVert *v = &map[xOff+" xstr(WIDTH) "*yOff]; \n" \
"int vIndex = v->index;                     \n" \
"                                           \n" \
"float distToV = terrainMovementPoints(v->terrain); \n" \
"if(x!=v->x && y!=v->y)                     \n" \
"distToV *= 1.4;                            \n" \
"                                           \n" \
"float d1 = dist[vIndex];                   \n" \
"float d2 = dist[uIndex];                   \n" \
"//printf((const char*)\"(%d)%0.1f > (%d)%0.1f + %0.1f?\\n\",vIndex,d1,uIndex,d2,distToV); \n" \
"if(dist[vIndex] > dist[uIndex] + distToV)  \n" \
"{                                          \n" \
"    dist[vIndex] = dist[uIndex] + distToV; \n" \
"    prev[vIndex] = uIndex;                 \n" \
"    heap[heapSize+d] = vIndex;             \n" \
"}                                          \n" \
"    //heap[heapSize+d] = vIndex;           \n" \
"                                           \n" \
"   //printf((const char*)\"openCL! map[%d][%d]=%d  heapSize = %d  heap[%d]=%d\\n\",x,y,map[source].terrain,heapSize,heapSize-1,heap[heapSize-1]);\n" \
"                                           \n" \
"}                                          \n" \
"\n";


int len = DIRECTIONS;
int err;                            // error code returned from api calls
size_t global;                      // global domain size for our calculation
size_t local;                       // local domain size for our calculation
cl_device_id device_id;             // compute device id 
cl_context context;                 // compute context
cl_command_queue commands;          // compute command queue
cl_program program;                 // compute program
cl_kernel kernel;                   // compute kernel
cl_mem theMap;                        // device memory used for the map array
cl_mem theDist;                        // device memory used for the map array
cl_mem thePrev;                        // device memory used for the map array
cl_mem heap;                       // device memory used for the heap array

-(BOOL)openCLSetup
{
    // Connect to a compute device
    int gpu = 1;
    err = clGetDeviceIDs(NULL, gpu ? CL_DEVICE_TYPE_GPU : CL_DEVICE_TYPE_CPU, 1, &device_id, NULL);
    if (err != CL_SUCCESS) { printf("Error: Failed to create a device group! %d\n",err); return NO; }
    
    // Create a compute context 
    context = clCreateContext(0, 1, &device_id, NULL, NULL, &err);
    if (!context) { printf("Error: Failed to create a compute context!\n"); return NO; }
    
    // Create a command commands
    commands = clCreateCommandQueue(context, device_id, 0, &err);
    if (!commands) { printf("Error: Failed to create a command commands!\n"); return NO; }
    
    // Create the compute program from the source buffer
    program = clCreateProgramWithSource(context, 1, (const char **) & kernelSource, NULL, &err);
    if (!program) { printf("Error: Failed to create compute program!\n"); return NO; }
    
    // Build the program executable
    err = clBuildProgram(program, 0, NULL, NULL, NULL, NULL);
    if (err != CL_SUCCESS)
    {
        size_t len;
        char buffer[2048];
        
        printf("Error: Failed to build program executable!\n");
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, sizeof(buffer), buffer, &len);
        printf("%s\n", buffer);
        return NO;
    }
    
    // Create the compute kernel in the program we wish to run
    kernel = clCreateKernel(program, "dijkstraWork", &err);
    if (!kernel || err != CL_SUCCESS) { printf("Error: Failed to create compute kernel!\n"); return NO; }
    
    // Create the array in device memory for the sort
    theMap = clCreateBuffer(context,  CL_MEM_READ_WRITE,  sizeof(DPFVert) * WIDTH*HEIGHT, NULL, NULL);
    if (!theMap) { printf("Error: Failed to allocate device memory!\n"); return NO; }    
    
    heap = clCreateBuffer(context,  CL_MEM_READ_WRITE,  sizeof(int) * WIDTH*HEIGHT, NULL, NULL);
    if (!heap) { printf("Error: Failed to allocate device memory!\n"); return NO; }    
    
    thePrev = clCreateBuffer(context,  CL_MEM_READ_WRITE,  sizeof(int) * WIDTH*HEIGHT, NULL, NULL);
    if (!thePrev) { printf("Error: Failed to allocate device memory!\n"); return NO; }    
    
    theDist = clCreateBuffer(context,  CL_MEM_READ_WRITE,  sizeof(float) * WIDTH*HEIGHT, NULL, NULL);
    if (!theDist) { printf("Error: Failed to allocate device memory!\n"); return NO; }    
    
    
    // Get the maximum work group size for executing the kernel on the device
    err = clGetKernelWorkGroupInfo(kernel, device_id, CL_KERNEL_WORK_GROUP_SIZE, sizeof(local), &local, NULL);
    if (err != CL_SUCCESS) { printf("Error: Failed to retrieve kernel work group info! %d\n", err); return NO; }
    
    global = len;
    if(local>global)
        local = global;
    
    
    return YES;
}

-(void)openCLCleanup
{
    // Shutdown and cleanup
    clReleaseMemObject(theMap);
    clReleaseMemObject(heap);
    clReleaseProgram(program);
    clReleaseKernel(kernel);
    clReleaseCommandQueue(commands);
    clReleaseContext(context);
}

-(BOOL)openCLWorkOnIndex:(unsigned int)source
{
    
    // Write our data set into the input array in device memory 
    err = clEnqueueWriteBuffer(commands, heap, CL_TRUE, 0, sizeof(int) * WIDTH*HEIGHT, unsettledVertsHeap, 0, NULL, NULL);
    if (err != CL_SUCCESS) { printf("Error: Failed to write to source array 2!\n"); return NO; }
    
    // Write our data set into the input array in device memory 
    err = clEnqueueWriteBuffer(commands, thePrev, CL_TRUE, 0, sizeof(int) * WIDTH*HEIGHT, prev, 0, NULL, NULL);
    if (err != CL_SUCCESS) { printf("Error: Failed to write to source array 3!\n"); return NO; }
    
    // Write our data set into the input array in device memory 
    err = clEnqueueWriteBuffer(commands, theDist, CL_TRUE, 0, sizeof(float) * WIDTH*HEIGHT, dist, 0, NULL, NULL);
    if (err != CL_SUCCESS) { printf("Error: Failed to write to source array 4!\n"); return NO; }
    
    // Write our data set into the input array in device memory 
    err = clEnqueueWriteBuffer(commands, theMap, CL_TRUE, 0, sizeof(DPFVert) * WIDTH*HEIGHT, map, 0, NULL, NULL);
    if (err != CL_SUCCESS) { printf("Error: Failed to write to source array 1!\n"); return NO; }
        
    // Execute the kernel
    err  = 0;    
    err  = clSetKernelArg(kernel, 0, sizeof(cl_mem), &theMap);
    err |= clSetKernelArg(kernel, 1, sizeof(unsigned int), &source);
    err |= clSetKernelArg(kernel, 2, sizeof(cl_mem), &heap);
    err |= clSetKernelArg(kernel, 3, sizeof(int), &unsettledVertCount);
    err |= clSetKernelArg(kernel, 4, sizeof(cl_mem), &theDist);
    err |= clSetKernelArg(kernel, 5, sizeof(cl_mem), &thePrev);
    if (err != CL_SUCCESS) { printf("Error: Failed to set kernel arguments! %d\n", err); return NO; }
    
    err = clEnqueueNDRangeKernel(commands, kernel, 1, NULL, &global, &local, 0, NULL, NULL);
    if (err) { printf("Error: Failed to execute kernel (%d)!\n",err); return EXIT_FAILURE; } 
    
    // Wait for all the commands to get serviced before reading back results
    clFinish(commands);
    
    // Read back the results from the device to verify the output
    err = clEnqueueReadBuffer( commands, theMap, CL_TRUE, 0, sizeof(DPFVert) * WIDTH*HEIGHT, map, 0, NULL, NULL );  
    if (err != CL_SUCCESS) { printf("Error: Failed to read output array! %d -1\n", err); return NO; }
    
    // Read back the results from the device to verify the output
    err = clEnqueueReadBuffer( commands, heap, CL_TRUE, 0, sizeof(int) * WIDTH*HEIGHT, unsettledVertsHeap, 0, NULL, NULL );  
    if (err != CL_SUCCESS) { printf("Error: Failed to read output array! %d -2\n", err); return NO; }   
    
    // Read back the results from the device to verify the output
    err = clEnqueueReadBuffer( commands, thePrev, CL_TRUE, 0, sizeof(int) * WIDTH*HEIGHT, prev, 0, NULL, NULL );  
    if (err != CL_SUCCESS) { printf("Error: Failed to read output array! %d -3\n", err); return NO; }   
    
    // Read back the results from the device to verify the output
    err = clEnqueueReadBuffer( commands, theDist, CL_TRUE, 0, sizeof(float) * WIDTH*HEIGHT, dist, 0, NULL, NULL );  
    if (err != CL_SUCCESS) { printf("Error: Failed to read output array! %d -4\n", err); return NO; }    
    
    // update whatever heap work we need to
    int checkMax = unsettledVertCount+DIRECTIONS;
    for(int i = unsettledVertCount;i<checkMax;i++)
    {
        if(unsettledVertsHeap[i]!=-1)
            [self insertVert:allVerts[unsettledVertsHeap[i]]];
    }
    
    return YES;
}

-(BOOL)DijkstraP2
{
    if(unsettledVertCount==0)
        return NO; // nothing to do
    
    if(!queue)
        queue = dispatch_queue_create("Direction Concurrent Queue", DISPATCH_QUEUE_CONCURRENT);
    
    DPFVert *u = [self removeMinVert];
    
    int uIndex = u->index;
    if(dist[uIndex]==MAX_DISTANCE)
        return NO;
    
    // Add this node to the list of settled verts, it's as short as it gets
    settledVerts[settledVertCount++] = u;
    
    // This is the end node, we're done
    if(u->x==WIDTH-2 && u->y==HEIGHT-2)
        return NO;
    
    [self openCLWorkOnIndex:u->index];
    
    //return NO;
    
    /*
    dispatch_apply(8, queue, ^(size_t d) 
                   {
                       int xOff = u->x+xOffsetForDirection(d);
                       int yOff = u->y+yOffsetForDirection(d);
                       if(xOff<0 || yOff<0 || xOff>=WIDTH || yOff>=HEIGHT)
                           return; // off the grid, ignore this edge
                       
                       DPFVert *v = &map[xOff][yOff];
                       int vIndex = v->index;
                       
                       CGFloat distToV = terrainMovementPoints(v->terrain);
                       if(u->x!=v->x && u->y!=v->y)
                           distToV *= 1.4;
                       
                       if(dist[vIndex] > dist[uIndex] + distToV)
                       {
                           dist[vIndex] = dist[uIndex] + distToV;
                           prev[vIndex] = uIndex;
                           [self insertVertP1:v];
                       }
                   });
    */
    
    //NSLog(@"Iterrate");
    return YES;
}


- (void)findPath
{
    for(int x=0;x<WIDTH;x++)
        for(int y=0;y<HEIGHT;y++)
        {
            //if(x==(int)((float)y*((float)WIDTH/(float)HEIGHT)))
            //    thePath[x][y] = YES;
            thePath[WH(x,y)] = NO;
        }
    
    DPFVert *current = allVerts[(HEIGHT-2)*WIDTH+(WIDTH-2)];
    while(current)
    {
        thePath[WH(current->x,current->y)] = YES;
        current = allVerts[prev[current->index]];
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
            CGFloat r = terrainColor[map[WH(x,y)].terrain].r;
            CGFloat g = terrainColor[map[WH(x,y)].terrain].g;
            CGFloat b = terrainColor[map[WH(x,y)].terrain].b;
            //NSLog(@"r=%0.2f g=%0.2f b=%0.2f",r,g,b);
            
            CGContextSetRGBFillColor(ctx, r, g, b, 1);
            CGContextFillRect(ctx, CGRectMake((float)x*PIX_W, (float)y*PIX_H, PIX_W, PIX_H));
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
            if(thePath[WH(x,y)])
            {
                CGContextSetRGBFillColor(ctx, 1, 1, 0, 1);
                CGContextFillEllipseInRect(ctx, CGRectMake((float)x*PIX_W, (float)y*PIX_H, PIX_W, PIX_H));
            }
            

            if(SIZE_FACTOR>=16)
            {
                if(dist[y*WIDTH+x]>=MAX_DISTANCE)
                    snprintf(buff, 64, "-00-");
                else if((int)dist[y*WIDTH+x]>=9999)
                    snprintf(buff, 64, "----");
                else
                    snprintf(buff, 64, "%04d",(int)dist[y*WIDTH+x]);
                CGContextSetRGBFillColor(ctx, 0, 0, 0, 1);
                CGContextShowTextAtPoint(ctx, (float)x*PIX_W +SIZE_FACTOR/10.0f , (float)y*PIX_H + PIX_H/2.0f, buff, strlen(buff));                            
            }
        }
}


-(void)generateMapOfSize:(CGFloat)sizeFactor andSeed:(NSInteger)seed
{
    SIZE_FACTOR = sizeFactor;
    MAP_SEED = seed;
    
    //NSLog(@"Size %0.1f, seed %d",SIZE_FACTOR,MAP_SEED);
    //NSLog(@"Width = %d  Height = %d",WIDTH,HEIGHT);
    
    [self generateMap];
    [self setNeedsDisplay:YES];
}
-(void)findPathWithAlgorithm:(NSInteger)algorithm
{
    static BOOL working = NO;
    
    if(working)
        return;
    working = YES;
    
    [self resetDijkstra];
    [self setNeedsDisplay:YES];
    
    if(DRAW_STEPS)
        [NSTimer scheduledTimerWithTimeInterval:0.025f target:self selector:@selector(step:) userInfo:nil repeats:YES];
    else
    {
        clock_t startTime, endTime;
        float ratio = 1./CLOCKS_PER_SEC;
        startTime = clock();
        
        switch (algorithm) 
        {
            case 0:
                while([self Dijkstra]);
                break;
            case 1:
                while([self DijkstraP1]);
                break;
            case 2:
                if([self openCLSetup])
                {
                    while([self DijkstraP2]);
                    [self openCLCleanup];
                }
                break;
            case 3:
                [self setupAltDijkstra];
                [self AltDijkstra];
                break;
                
            default:
                break;
        }
        
        endTime = clock();
        self.textField.stringValue = [NSString stringWithFormat:@"With %d verts finished in %0.5f secs.\n",WIDTH*HEIGHT,ratio*(long)endTime - ratio*(long)startTime];
        printf("With %d verts and %d edges, finished in %0.4f seconds.\n",WIDTH*HEIGHT,WIDTH*HEIGHT*DIRECTIONS,ratio*(long)endTime - ratio*(long)startTime);
        
        if(algorithm==3)
            [self findAltPath];
        else
            [self findPath];
        [self setNeedsDisplay:YES];
    }    
    working = NO;
}

@end
