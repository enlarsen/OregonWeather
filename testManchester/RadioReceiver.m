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

@property (strong, nonatomic) ManchesterDecoder *manchesterDecoder;

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
    NSRange preambleRange = [input rangeOfString:@"0101010101010101"];
    NSRange syncByteRange = [input rangeOfString:@"010110011001"]; // 1 nibble of sync with sync byte
    if(preambleRange.location != NSNotFound && syncByteRange.location != NSNotFound)
    {
//        NSLog(@"Preamble: %@", NSStringFromRange(preambleRange));
//        NSLog(@"Sync byte + a little preamble: %@", NSStringFromRange(syncByteRange));
//        NSLog(@"Decoded manchester data! Length: %lu", (unsigned long)input.length);
//        NSLog(@"%@", input);

        if(syncByteRange.location < preambleRange.location + 35)
        {
            NSInteger startLocation = syncByteRange.location + syncByteRange.length;

            NSRange startRange = NSMakeRange(startLocation, input.length - startLocation);

            NSMutableString *messageString1 = [[NSMutableString alloc] init];
            NSMutableString *messageString2 = [[NSMutableString alloc] init];

            for(NSInteger i = startLocation; i < input.length - 1 ; i += 2)
            {
                NSRange m1Range = NSMakeRange(i, 1);
                NSRange m2Range = NSMakeRange(i + 1, 1);
                [messageString1 appendString:[input substringWithRange:m1Range]];
                [messageString2 appendString:[input substringWithRange:m2Range]];

            }
//            NSLog(@"Message 1: %@", message1);
//            NSLog(@"Message 2: %@", message2);
            __block int bitErrors = 0;
            [messageString1 enumerateSubstringsInRange:NSMakeRange(0, messageString1.length)
            options:NSStringEnumerationByComposedCharacterSequences | NSStringEnumerationReverse usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop)
            {
                if([substring isEqualToString:[messageString2 substringWithRange:substringRange]])
                {
                    bitErrors++;
                }
            }];

            NSLog(@"Bit errors: %d", bitErrors);

            NSMutableString *nibbleFlippedMessage1 = [[NSMutableString alloc] init];
            NSMutableString *nibbleFlippedMessage2 = [[NSMutableString alloc] init];

            if(messageString2.length == messageString1.length)
            {
                for(NSInteger i = 0; i < messageString2.length - 4; i += 4)
                {
                    [messageString1 enumerateSubstringsInRange:NSMakeRange(i, 4) options:NSStringEnumerationReverse | NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop)
                     {
                         [nibbleFlippedMessage1 appendString:substring];
                     }];

                    [messageString2 enumerateSubstringsInRange:NSMakeRange(i, 4) options:NSStringEnumerationReverse | NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop)
                     {
                         [nibbleFlippedMessage2 appendString:substring];
                     }];

                }
                //            NSLog(@"Nibble flipped: %@", nibbleFlippedMessage2);
                // Convert back to nibbles
                uint8 byte1 = 0x01;
                uint8 byte2 = 0x01;
                NSMutableArray *message1 = [[NSMutableArray alloc] init];
                NSMutableArray *message2 = [[NSMutableArray alloc] init];

                for(NSInteger i = 0; i < nibbleFlippedMessage2.length; i++)
                {
                    BOOL lastBit1 = (byte1 & 0x08) == 0x08;
                    BOOL lastBit2 = (byte2 & 0x08) == 0x08;
                    byte1 <<= 1;
                    byte2 <<= 1;
                    // Message1 is the inverse, so make the inverse here;
                    if([[nibbleFlippedMessage1 substringWithRange:NSMakeRange(i, 1)]
                        isEqualToString: @"0"])
                    {
                        byte1 |= 1;
                    }
                    if([[nibbleFlippedMessage2 substringWithRange:NSMakeRange(i, 1)]
                        isEqualToString: @"1"])
                    {
                        byte2 |= 1;
                    }
                    if(lastBit1)
                    {
                        [message1 addObject:[NSNumber numberWithChar:(byte1 & 0x0f)]];
                        byte1 = 0x01;
                    }
                    if(lastBit2)
                    {
                        [message2 addObject:[NSNumber numberWithChar:(byte2 & 0x0f)]];
                        byte2 = 0x01;
                    }
                }
                // Check whether various nibbles are equal so we're somewhat sure the data
                // is correct.

                int nibbleErrors = 0;
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
                if([message2[0] isEqualToNumber:@0x1] && [message2[1] isEqualToNumber:@0xd] &&
                   [message2[2] isEqualToNumber:@0x2] && [message2[3] isEqualToNumber:@0x0])
                {
                    if(nibbleErrors == 0)
                    {
                        NSLog(@"Got a thermometer reading!");
                        NSLog(@"Channel: %@", message2[4]);
                        float temperatureC = [message2[10] floatValue] * 10.0 + [message2[9] floatValue] + [message2[8] floatValue] / 10.0;
                        float temperatureF = temperatureC * 1.8 + 32.0;
                        NSLog(@"Temperature F: %f", temperatureF);
                        long humidity = [message2[13] integerValue] * 10 + [message2[12] integerValue];
                        NSLog(@"Humidity: %ld", humidity);
                    }
                    else
                    {
                        NSLog(@"Found too many errors in the nibbles: %d", nibbleErrors);
                    }
                }
            }
            
        }
    }

}

@end
