//
//  main.m
//  testManchester
//
//  Created by Erik Larsen on 12/15/14.
//  Copyright (c) 2014 Erik Larsen. All rights reserved.
//

void manchester(void);

#import <Foundation/Foundation.h>
#import "RadioTools/RadioTools.h"
#import "RadioReceiver.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        // insert code here...
        NSLog(@"Hello, World!");
        manchester();
        BOOL shouldKeepRunning = YES;
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        while(shouldKeepRunning && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    }
    return 0;
}

void manchester()
{
    RadioReceiver *receiver = [[RadioReceiver alloc] init];
    [receiver start];
}

