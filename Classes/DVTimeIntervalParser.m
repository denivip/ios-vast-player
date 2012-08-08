//
//  DVTimeIntervalParser.m
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/8/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVTimeIntervalParser.h"


@implementation DVTimeIntervalParser

- (NSTimeInterval)timeIntervalWithString:(NSString *)string
{
    NSScanner *scanner = [NSScanner scannerWithString:string];
    
    NSInteger hours = 0;
    NSInteger minutes = 0;
    NSInteger seconds = 0;
    NSInteger milliseconds = 0;
    
    if (! [scanner scanInteger:&hours]) {
        return NAN;
    }
    
    if (! [scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@":"] intoString:nil]) {
        return NAN;
    }
    
    if (! [scanner scanInteger:&minutes]) {
        return NAN;
    }
    
    if (! [scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@":"] intoString:nil]) {
        return NAN;
    }
    
    if (! [scanner scanInteger:&seconds]) {
        return NAN;
    }
    
    if ([scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"."] intoString:nil]) {
        [scanner scanInteger:&milliseconds];
    }
    
    return hours * 60 * 60 + minutes * 60 + seconds + (CGFloat)milliseconds / 1000.f;
}

@end
