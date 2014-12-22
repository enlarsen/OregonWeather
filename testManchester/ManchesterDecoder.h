//
//  ManchesterDecoder.h
//
//  Created by Erik Larsen on 12/18/14.
//  Copyright (c) 2014 Erik Larsen.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import <Foundation/Foundation.h>
#import "RadioTools/RadioTools.h"
#import "ManchesterDataReceived.h"

@interface ManchesterDecoder : NSObject

- (instancetype)initWithSampleRate:(float)sampleRate amplitudeFloor:(float)amplitudeFloor;
- (void)decode:(RTSFloatVector *)input;

@property (nonatomic, weak) id<ManchesterDataReceived> dataReceivedDelegate;

@end
