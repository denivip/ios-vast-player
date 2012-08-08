//
//  DVTimeIntervalParser.h
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/8/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DVTimeIntervalFormatter : NSObject

- (NSTimeInterval)timeIntervalWithString:(NSString *)string;
- (NSString *)stringWithTimeInterval:(NSTimeInterval)timeInterval;

@end
