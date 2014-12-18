//
//  RadioReceiver.m
//  OregonWeather
//
//  Created by Erik Larsen on 12/15/14.
//  Copyright (c) 2014 Erik Larsen. All rights reserved.
//

#import "RadioReceiver.h"

// Make this divisible by the decimators' factors because they can't
// handle non-rational decimation. I'm decimating by 4 and 10.
static const NSUInteger inputBufferSize = 3200;
static const NSUInteger sampleRate = 1024000;
static const UInt32 frequency = 433920000;

@interface RadioReceiver()

@property (strong, nonatomic) RTSRTLRadio* radio;
@property (strong, nonatomic) RTSInputConditioner *conditioner;
@property (strong, nonatomic) RTSAMDemodulator *demodulator;
@property (strong, nonatomic) RTSDecimator *firstDecimator;
@property (strong, nonatomic) RTSDecimator *finalDecimator;
@property (strong, nonatomic) RTSAudioOutput *audioOutput;
@property (strong, nonatomic) RTSMultiplyAdder *multiplyAdder;

@end

@implementation RadioReceiver

- (dispatch_queue_t)dataDispatchQueue
{
    if(!_dataDispatchQueue)
    {
        _dataDispatchQueue = dispatch_queue_create("com.enlarsen.dataDispatchQueue", NULL);
    }
    return _dataDispatchQueue;
}

- (RTSRTLRadio *)radio
{
    if(!_radio)
    {
        _radio = [[RTSRTLRadio alloc] initWithDelegate:self frequency:frequency sampleRate:sampleRate  outputBufferSize:inputBufferSize];
    }
    return _radio;

}

- (RTSInputConditioner *)conditioner
{
    if(!_conditioner)
    {
        _conditioner = [[RTSInputConditioner alloc] init];
    }
    return _conditioner;
}

- (RTSAMDemodulator *)demodulator
{
    if(!_demodulator)
    {
        _demodulator = [[RTSAMDemodulator alloc] init];
    }
    return _demodulator;
}

- (RTSDecimator *)firstDecimator
{
    if(!_firstDecimator)
    {
        _firstDecimator = [[RTSDecimator alloc] initWithFactor:4];
    }
    return _firstDecimator;
}

- (RTSDecimator *)finalDecimator
{
    if(!_finalDecimator)
    {
        _finalDecimator = [[RTSDecimator alloc] initWithFactor:8];
    }
    return _finalDecimator;
}

- (RTSAudioOutput *)audioOutput
{
    if(!_audioOutput)
    {
        _audioOutput = [[RTSAudioOutput alloc] initWithSampleRate:32000];
    }
    return _audioOutput;
}

- (RTSMultiplyAdder *)multiplyAdder
{
    if(!_multiplyAdder)
    {
        _multiplyAdder = [[RTSMultiplyAdder alloc] initWithMultiplyFactor:-1.0 adder:500.0];
    }
    return _multiplyAdder;
}

- (void)start
{
    [self.radio start];
}

- (void)dataReceived:(NSMutableData *)dataQueue
{
    RTSComplexVector *conditioned = [self.conditioner conditionInput:dataQueue];
    RTSComplexVector *firstDecimated = [self.firstDecimator decimateComplex:conditioned];
    RTSFloatVector *demodulated = [self.demodulator demodulate:firstDecimated];
    RTSFloatVector *finalDecimated = [self.finalDecimator decimateFloat:demodulated];
    RTSFloatVector *scaled = [self.multiplyAdder multiplyAdd:finalDecimated];

    [self.audioOutput playSoundBuffer:scaled];


//    [scaled writeData:@"/Users/erikla/desktop/test12172014.txt"];
}

@end
