//
//  ManchesterDataReceived.h
//  OregonWeather
//
//  Created by Erik Larsen on 12/19/14.
//  Copyright (c) 2014 Erik Larsen. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ManchesterDataReceived <NSObject>

- (void)decodedManchesterDataReceived:(NSMutableData *)input;

@end
