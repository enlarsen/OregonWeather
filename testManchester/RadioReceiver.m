//
//  RadioReceiver.m
//  OregonWeather
//
//  Created by Erik Larsen on 12/15/14.
//  Copyright (c) 2014 Erik Larsen.
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


@property (strong, nonatomic) NSMutableArray *sensors;

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

- (ManchesterDecoder *)manchesterDecoder
{
    if(!_manchesterDecoder)
    {
        _manchesterDecoder = [[ManchesterDecoder alloc] initWithSampleRate:32000.0 amplitudeFloor:2000000];
        _manchesterDecoder.dataReceivedDelegate = self;
    }
    return _manchesterDecoder;
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

    [self.manchesterDecoder decode:finalDecimated];

//    [self.audioOutput playSoundBuffer:scaled];


//    [finalDecimated writeData:@"/Users/erikla/desktop/test12192014.txt"];
}

- (void)decodedManchesterDataReceived:(NSMutableString *)input
{
    // For v2.1 sensors
    NSRange preambleRange = [input rangeOfString:@"0101010101010101"]; // 4 nibbles of preamble out of 8 total
    NSRange syncByteRange = [input rangeOfString:@"010110011001"]; // 1 nibble of preamble with sync byte

    // Conditions for not decoding:
    // * Preamble not found
    // * Sync byte (next to 1 nibble of preamble) not found
    // * Sync byte too far from beginning of preamble

    if(preambleRange.location == NSNotFound ||
       syncByteRange.location == NSNotFound ||
       syncByteRange.location > preambleRange.location + 35)
    {
        return;
    }

    NSInteger startLocation = syncByteRange.location + syncByteRange.length;

    NSArray *messages = [self deinterleaveMessage:[input substringWithRange:NSMakeRange(startLocation, input.length - startLocation)]];

    int bitErrors = [self countBitErrors:messages[0] message2:messages[1]];

    NSLog(@"Bit errors: %d", bitErrors);

    NSArray *nibbleFlippedMessages = [self flipNibbles:messages[0] message2:messages[1]];

    // Fails if there aren't 4 bits in the messages and if their lengths are different
    if(nibbleFlippedMessages == nil)
    {
        return;
    }

    // Convert to real nibbles stored as NSNumbers.
    // note that message1 has its bits flipped so if there are
    // no bit errors, message1 == message2

    NSArray *nibbles = [self convertToNibbles:nibbleFlippedMessages[0]
                                     message2:nibbleFlippedMessages[1]];

    NSArray *message1 = nibbles[0];
    NSArray *message2 = nibbles[1];

    if([message2[0] isEqualToNumber:@0x1] && [message2[1] isEqualToNumber:@0xd] &&
       [message2[2] isEqualToNumber:@0x2] && [message2[3] isEqualToNumber:@0x0])
    {
        // Check whether various nibbles we care about are equal
        // between messages so we're somewhat sure the data is correct.

        int nibbleErrors = 0;
        if(message1.count < 14 || message2.count < 14)
        {
            NSLog(@"Messages too short: %ld", message1.count);
            return;
        }
        for(int i = 0; i < 5; i++) // This is the sensor ID and the channel
        {
            if(message1[i] != message2[i])
            {
                nibbleErrors++;
            }
        }

        for(int i = 8; i < 14; i++) // This is the temperature and humidity data
        {
            if(message1[i] != message2[i])
            {
                nibbleErrors++;
            }
        }

        if(nibbleErrors == 0)
        {
//            NSLog(@"Got a thermometer reading!");
            long channel = [message2[4] integerValue];
            NSLog(@"Channel: %@", message2[4]);
            float temperatureC = [message2[10] floatValue] * 10.0 + [message2[9] floatValue] + [message2[8] floatValue] / 10.0;
            float temperatureF = temperatureC * 1.8 + 32.0;
            NSLog(@"Temperature F: %f", temperatureF);
            long humidity = [message2[13] integerValue] * 10 + [message2[12] integerValue];
            NSLog(@"Humidity: %ld", humidity);

            NSString *temperatureString = [NSString stringWithFormat:@"%.1f ℉", temperatureF];
            NSString *humidityString = [NSString stringWithFormat:@"%ld%%", humidity];
            if(channel == 1)
            {
                self.temperatureChannel1 = temperatureString;
                self.humidityChannel1 = humidityString;
            }
            if(channel == 2)
            {
                self.temperatureChannel2 = temperatureString;
                self.humidityChannel2 = humidityString;
            }
            if(channel == 4) // Channel 3
            {
                self.temperatureChannel3 = temperatureString;
                self.humidityChannel3 = humidityString;
            }


        }
        else
        {
            NSLog(@"Found too many nibble errors: %d", nibbleErrors);
        }
    }
}

- (NSArray *)deinterleaveMessage:(NSString *)interleavedMessage
{
    NSMutableString *messageString1 = [[NSMutableString alloc] init];
    NSMutableString *messageString2 = [[NSMutableString alloc] init];

    for(NSInteger i = 0; i < interleavedMessage.length - 1 ; i += 2)
    {
        NSRange m1Range = NSMakeRange(i, 1);
        NSRange m2Range = NSMakeRange(i + 1, 1);
        [messageString1 appendString:[interleavedMessage substringWithRange:m1Range]];
        [messageString2 appendString:[interleavedMessage substringWithRange:m2Range]];
    }

    return @[messageString1, messageString2];
}

- (int)countBitErrors:(NSString *)message1 message2:(NSString *)message2
{
    __block int bitErrors = 0;

    [message1 enumerateSubstringsInRange:NSMakeRange(0, message1.length)
                                       options:NSStringEnumerationByComposedCharacterSequences | NSStringEnumerationReverse usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop)
     {
         if([substring isEqualToString:[message2 substringWithRange:substringRange]])
         {
             bitErrors++;
         }
     }];

    return bitErrors;

}

// The nibbles in V2.1 messages are in the reverse order than customary. This
// method flips them in message1 and its inverse, message2.

- (NSArray *)flipNibbles:(NSString *)message1 message2:(NSString *)message2
{
    NSMutableString *nibbleFlippedMessage1 = [[NSMutableString alloc] init];
    NSMutableString *nibbleFlippedMessage2 = [[NSMutableString alloc] init];

    if(message1.length == message2.length && message1.length > 4)
    {
        for(NSInteger i = 0; i < message2.length - 4; i += 4)
        {
            [message1 enumerateSubstringsInRange:NSMakeRange(i, 4) options:NSStringEnumerationReverse | NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop)
             {
                 [nibbleFlippedMessage1 appendString:substring];
             }];

            [message2 enumerateSubstringsInRange:NSMakeRange(i, 4) options:NSStringEnumerationReverse | NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop)
             {
                 [nibbleFlippedMessage2 appendString:substring];
             }];
            
        }

        return @[nibbleFlippedMessage1, nibbleFlippedMessage2];

    }
    else
    {
        return nil;
    }
}

// Convert the strings of 1s and 0s to an array of arrays of nibbles

- (NSArray *)convertToNibbles:(NSString *)message1 message2:(NSString *)message2
{
    // Convert back to nibbles
    uint8 byte1 = 0x01;
    uint8 byte2 = 0x01;
    NSMutableArray *nibbles1 = [[NSMutableArray alloc] init];
    NSMutableArray *nibbles2 = [[NSMutableArray alloc] init];

    for(NSInteger i = 0; i < message2.length; i++)
    {
        BOOL lastBit1 = (byte1 & 0x08) == 0x08;
        BOOL lastBit2 = (byte2 & 0x08) == 0x08;
        byte1 <<= 1;
        byte2 <<= 1;
        // Message1 is the inverse, so make the inverse here;
        if([[message1 substringWithRange:NSMakeRange(i, 1)]
            isEqualToString: @"0"])
        {
            byte1 |= 1;
        }
        if([[message2 substringWithRange:NSMakeRange(i, 1)]
            isEqualToString: @"1"])
        {
            byte2 |= 1;
        }
        if(lastBit1)
        {
            [nibbles1 addObject:[NSNumber numberWithChar:(byte1 & 0x0f)]];
            byte1 = 0x01;
        }
        if(lastBit2)
        {
            [nibbles2 addObject:[NSNumber numberWithChar:(byte2 & 0x0f)]];
            byte2 = 0x01;
        }
    }
    return @[nibbles1, nibbles2];
}

@end
