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

#define SIZE_FACTOR 8  // can be 1,2,4,8
#define MAP_SEED    5

#define WIDTH  ((int)(1024/SIZE_FACTOR))
#define HEIGHT  ((int)(768/SIZE_FACTOR))
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

#define PIX_W  (1024.0f/(float)WIDTH)
#define PIX_H  (768.0f/(float)HEIGHT)

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

// min heap source drawn from: http://en.wikibooks.org/wiki/Data_Structures/Min_and_Max_Heaps
#define LEFT(i)  (2*i)
#define RIGHT(i) (2*i+1)
- (void)insertVert:(DPFVert*)vert
{
    unsettledVerts[unsettledVertCount++] = vert;
    int i = unsettledVertCount-1;
    while(i>0)
    {
        if(dist[unsettledVerts[i/2]->index] < dist[unsettledVerts[i]->index])
            break;
        DPFVert *temp = unsettledVerts[i/2];
        unsettledVerts[i/2] = unsettledVerts[i];
        unsettledVerts[i] = temp;        
        i/=2;
    }
    
    if(1)
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
    unsettledVerts[unsettledVertCount++] = vert;
    int i = unsettledVertCount-1;
    while(i>0)
    {
        if(dist[unsettledVerts[i/2]->index] < dist[unsettledVerts[i]->index])
            break;
        DPFVert *temp = unsettledVerts[i/2];
        unsettledVerts[i/2] = unsettledVerts[i];
        unsettledVerts[i] = temp;        
        i/=2;
    }
    
    if(1)
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
    DPFVert *savedMinVert = unsettledVerts[0];
    unsettledVerts[0] = unsettledVerts[--unsettledVertCount];
    int i=0;
    while(i<unsettledVertCount)
    {
        int minIndex = i;
        if(LEFT(i)<unsettledVertCount && dist[unsettledVerts[LEFT(i)]->index] < dist[unsettledVerts[minIndex]->index])
            minIndex = LEFT(i);
        if(RIGHT(i)<unsettledVertCount && dist[unsettledVerts[RIGHT(i)]->index] < dist[unsettledVerts[minIndex]->index])
            minIndex = RIGHT(i);
        if(minIndex!=i)
        {
            DPFVert *temp = unsettledVerts[i];
            unsettledVerts[i] = unsettledVerts[minIndex];
            unsettledVerts[minIndex] = temp;
            i = minIndex;
        }
        else
            break;
    }
    
    return savedMinVert;
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
        
        v = &map[xOff][yOff];
        int vIndex = v->index;
        
        CGFloat distToV = terrainMovementPoints(v->terrain);
        if(u->x!=v->x && u->y!=v->y)
            distToV *= 1.4;
        
        if(dist[vIndex] > dist[uIndex] + distToV)
        {
            dist[vIndex] = dist[uIndex] + distToV;
            prev[vIndex] = u;
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
        //NSLog(@"Hi %d",(int)d);
        
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
            prev[vIndex] = u;
            [self insertVertP1:v];
        }
        
        //sleep(rand()%4);
        
        //NSLog(@"Bye %d",(int)d);
    });
    
    return YES;
}


//"   __global int*  A,                       \n" \
"   const unsigned int len)                 \n" \

const char *kernelSource = "\n" \
"__kernel void dijkstraWork(                \n" \
"void)                                      \n" \
"{                                          \n" \
"   int k = get_global_id(0);               \n" \
"   printf((const char*)\"openCL! %d\\n\",k);\n" \
"}                                          \n" \
"\n";

-(BOOL)DijkstraP2
{
    int len = 8;
    int err;                            // error code returned from api calls
    size_t global;                      // global domain size for our calculation
    size_t local;                       // local domain size for our calculation
    cl_device_id device_id;             // compute device id 
    cl_context context;                 // compute context
    cl_command_queue commands;          // compute command queue
    cl_program program;                 // compute program
    cl_kernel kernel;                   // compute kernel
    cl_mem input;                       // device memory used for the input array
    
    // Connect to a compute device
    int gpu = 0;
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
    input = clCreateBuffer(context,  CL_MEM_READ_WRITE,  sizeof(int) * len, NULL, NULL);
    if (!input) { printf("Error: Failed to allocate device memory!\n"); return NO; }    
    
    // Write our data set into the input array in device memory 
    //err = clEnqueueWriteBuffer(commands, input, CL_TRUE, 0, sizeof(int) * len, A, 0, NULL, NULL);
    //if (err != CL_SUCCESS) { printf("Error: Failed to write to source array!\n"); return NO; }
    
    // Get the maximum work group size for executing the kernel on the device
    err = clGetKernelWorkGroupInfo(kernel, device_id, CL_KERNEL_WORK_GROUP_SIZE, sizeof(local), &local, NULL);
    if (err != CL_SUCCESS) { printf("Error: Failed to retrieve kernel work group info! %d\n", err); return NO; }
    
    global = 8;
    if(local>global)
        local = global;
    
    // Execute the kernel
    err  = 0;
    //err  = clSetKernelArg(kernel, 0, sizeof(cl_mem), &input);
    //err |= clSetKernelArg(kernel, 1, sizeof(unsigned int), &len);
    if (err != CL_SUCCESS) { printf("Error: Failed to set kernel arguments! %d\n", err); return NO; }
    
    err = clEnqueueNDRangeKernel(commands, kernel, 1, NULL, &global, &local, 0, NULL, NULL);
    if (err) { printf("Error: Failed to execute kernel (%d)!\n",err); return EXIT_FAILURE; } 
    
    // Wait for all the commands to get serviced before reading back results
    clFinish(commands);
    
    // Read back the results from the device to verify the output
    //err = clEnqueueReadBuffer( commands, input, CL_TRUE, 0, sizeof(int) * len, A, 0, NULL, NULL );  
    //if (err != CL_SUCCESS) { printf("Error: Failed to read output array! %d\n", err); return NO; }
    
    // Shutdown and cleanup
    clReleaseMemObject(input);
    clReleaseProgram(program);
    clReleaseKernel(kernel);
    clReleaseCommandQueue(commands);
    clReleaseContext(context);
    
    return NO;
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
            clock_t startTime, endTime;
            float ratio = 1./CLOCKS_PER_SEC;
            startTime = clock();
            while([self DijkstraP2]);
            endTime = clock();
            printf("With %d verts and %d edges, finished in %0.4f seconds.\n",MAX_VERTS,MAX_VERTS*DIRECTIONS,ratio*(long)endTime - ratio*(long)startTime);
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
            if(thePath[x][y])
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

@end
