//
//  ManchesterDecoder.m
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

static const float shortPulseTime = 0.0005f; // seconds
static const float noSignalTime = 0.0024f;  // seconds

#import "ManchesterDecoder.h"

@interface ManchesterDecoder()

@property (nonatomic) NSUInteger samplesSinceLastDataBit;
@property (nonatomic) float samplesInShortPulse;
@property (nonatomic) NSUInteger numberDataBitsReceived;
@property (nonatomic) float amplitudeFloor;
@property (nonatomic) NSUInteger lastLogicalLevel;
@property (nonatomic) float samplesWithNoSignal;

@property (nonatomic, strong) NSMutableString *outputData;
@property (nonatomic) NSUInteger sizeElements;
@property (nonatomic) NSUInteger sizeBytes;

//@property (nonatomic) UInt8 currentByte;

@end

@implementation ManchesterDecoder

- (instancetype)initWithSampleRate:(float)sampleRate amplitudeFloor:(float)amplitudeFloor
{
    self = [super init];
    if(self)
    {
        _amplitudeFloor = amplitudeFloor;
        _samplesInShortPulse = shortPulseTime * sampleRate;
        _samplesWithNoSignal = noSignalTime * sampleRate;
//        _currentByte = 0x01; // once the high bit is 1, we know we have one more shift before the
//                             // byte is "full"
        _lastLogicalLevel = 0;
    }
    return self;
}

#pragma mark - properties

- (NSMutableString *)outputData
{
    if(!_outputData)
    {
        _outputData = [[NSMutableString alloc] init];
    }
    return _outputData;
}


// Almost verbatim from
// https://github.com/magellannh/rtl-wx/blob/master/src/rtl-433fm-demod.c manchester_decode()

- (void)decode:(RTSFloatVector *)input
{
    if (self.samplesSinceLastDataBit == 0)
    {
        self.samplesSinceLastDataBit = self.samplesInShortPulse * 2.0;
    }

    for (NSUInteger i = 0; i < input.sizeElements; i++)
    {
        if (self.numberDataBitsReceived != 0)
        {
            self.samplesSinceLastDataBit++;
        }
         /* Pulse start (rising edge) */
        if (self.lastLogicalLevel == 0 && ([input vector][i] > self.amplitudeFloor))
        {
            self.lastLogicalLevel = 1;

            if (self.samplesSinceLastDataBit  > (self.samplesInShortPulse + (self.samplesInShortPulse / 2.0)))
            {
                /* Last bit was recorded more than samplesInShortPulse*1.5 samples ago */
                /* so this pulse start must be a data edge (rising data edge means bit = 0) */
                [self addBit:@"0"];
                self.samplesSinceLastDataBit = 1;
                self.numberDataBitsReceived++;
            }
        }
        /* Pulse end (falling edge) */
        if (self.lastLogicalLevel == 1 && ([input vector][i] <= self.amplitudeFloor))
        {
            if (self.samplesSinceLastDataBit > (self.samplesInShortPulse + (self.samplesInShortPulse / 2.0)))
            {
                /* Last bit was recorded more than "samplesInShortPulse*1.5" samples ago */
                /* so this pulse end is a data edge (falling data edge means bit = 1) */
                [self addBit:@"1"];
                self.samplesSinceLastDataBit = 1;
                self.numberDataBitsReceived++;
            }
            self.lastLogicalLevel = 0;
        }

        if (self.samplesSinceLastDataBit > self.samplesWithNoSignal)
        {
            if (self.dataReceivedDelegate)
            {
                [self.dataReceivedDelegate decodedManchesterDataReceived:self.outputData];
            }
            [self resetDataBuffer];
            self.samplesSinceLastDataBit = self.samplesInShortPulse * 2.0;
            self.numberDataBitsReceived = 0;
        }
    }

}

// Old way before using strings to make bit/nibble/byte alignment less
// fragile/painful/maddening.

//- (void)addBit:(NSUInteger)bit
//{
//    if(bit != 0x00 && bit != 0x01)
//    {
//        NSLog(@"Bad bit value: %lu", (unsigned long)bit);
//        return;
//    }
//
//    BOOL lastBit = (self.currentByte & 0x80) == 0x80;
//    self.currentByte <<= 1;
//    self.currentByte |= (uint8)bit;
//
//    if(lastBit)
//    {
//        [self.outputData appendBytes:&_currentByte length:1];
//        self.currentByte = 0x01;
//    }
//}

- (void)addBit:(NSString *)bit
{
    [self.outputData appendString:bit];
}

- (void)resetDataBuffer
{
    _outputData = nil;
}


@end
