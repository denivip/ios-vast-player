//
//  DVInlineVideoAd.m
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVInlineVideoAd.h"


@implementation DVInlineVideoAd

@synthesize system = _system;
@synthesize title = _title;
@synthesize impressionURL = _impressionURL;
@synthesize clickThroughURL = _clickThroughURL;
@synthesize clickTrackingURL = _clickTrackingURL;
@synthesize duration = _duration;
@synthesize mediaFileURL = _mediaFileURL;

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@ %@", [super description],
            self.identifier, self.mediaFileURL];
}

@end
