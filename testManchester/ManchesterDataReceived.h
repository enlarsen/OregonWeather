//
//  ManchesterDataReceived.h
//  OregonWeather
//
//  Created by Erik Larsen on 12/19/14.
//  Copyright (c) 2014 Erik Larsen.
//

#import <Foundation/Foundation.h>

@protocol ManchesterDataReceived <NSObject>

- (void)decodedManchesterDataReceived:(NSMutableString *)input;

@end
