//
//  RadioReceiver.h
//  OregonWeather
//
//  Created by Erik Larsen on 12/15/14.
//  Copyright (c) 2014 Erik Larsen.
//

#import <Foundation/Foundation.h>
#import "RadioTools/RadioTools.h"
#import "ManchesterDecoder.h"
#import "ManchesterDataReceived.h"

@interface RadioReceiver : NSObject <RTSDataReceived, ManchesterDataReceived>

@property (nonatomic, strong) dispatch_queue_t dataDispatchQueue;

- (void)start;

@end
