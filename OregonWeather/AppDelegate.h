//
//  AppDelegate.h
//  OregonWeather
//
//  Created by Erik Larsen on 12/15/14.
//  Copyright (c) 2014 Erik Larsen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RadioReceiver.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet RadioReceiver *radio;

@end

