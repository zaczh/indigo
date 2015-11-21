//
//  IndigoTestObject.h
//  indigo
//
//  Created by zhang on 9/5/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface IndigoTestObject : NSObject
- (void)funcThatTakesNoArg;
- (SEL)funcThatTakesSelector:(SEL)arg;
- (char)funcThatTakesCChar:(char)arg;
- (unsigned char)funcThatTakesCUnsignedChar:(unsigned char)arg;
- (short)funcThatTakesShort:(short)arg;
- (unsigned short)funcThatTakesUnsignedShort:(unsigned short)arg;
- (int)funcThatTakesInt:(int)arg;
- (long)funcThatTakesLong:(long)arg;
- (unsigned int)funcThatTakesUnsignedInt:(unsigned int)arg;
- (double)funcThatTakesDouble:(double)arg;
- (unsigned long)funcThatTakesUnsignedLong:(unsigned long)arg;
- (long long)funcThatTakesLongLong:(long long)arg;
- (unsigned long long)funcThatTakesUnsignedLongLong:(unsigned long long)arg;
- (CGRect)funcThatTakesStruct:(CGRect)arg;
@end
