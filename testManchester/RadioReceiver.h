//
//  RadioReceiver.h
//  OregonWeather
//
//  Created by Erik Larsen on 12/15/14.
//  Copyright (c) 2014 Erik Larsen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RadioTools/RadioTools.h"

@interface RadioReceiver : NSObject <RTSDataReceived>

@property (nonatomic, strong) dispatch_queue_t dataDispatchQueue;

- (void)start;

@end
