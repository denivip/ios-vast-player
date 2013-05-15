//
//  DVInlineVideoAd.m
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12. Augmented by Manuel "StuFF mc" Carrasco Molina in 2013 — https://github.com/stuffmc/ios-vast-player/tree/dev
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVInlineVideoAd.h"


@implementation DVInlineVideoAd

@synthesize system = _system;
@synthesize title = _title;
@synthesize impressionURL = _impressionURL;
@synthesize impressionURLs = _impressionsURL;
@synthesize clickThroughURL = _clickThroughURL;
@synthesize clickTrackingURL = _clickTrackingURL;
@synthesize trackingEvents = _trackingEvents;
@synthesize duration = _duration;
@synthesize mediaFileURL = _mediaFileURL;

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ id:%@ url:%@ play:%d", [super description],
            self.identifier, self.mediaFileURL, self.playMediaFile];
}

- (void)trackImpressions
{
    // Trigger those babies, async of course!
    VLogV(self.impressionURLs);
    [self.impressionURLs enumerateObjectsUsingBlock:^(NSURL *url, NSUInteger idx, BOOL *stop) {
        VLogV(url);
        [self sendAsynchronousRequest:url context:@"trackImpressions"];
    }];
}

- (void)trackEvent:(NSString*)event
{
    if ([self.trackingEvents[event] isKindOfClass:[NSDictionary class]]) { // Should be.
        NSDictionary *dictionary = (NSDictionary*)self.trackingEvents[event];
        [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSURL *url, BOOL *stop) {
            VLogV(key);
            VLogV(url);
            NSString *context = [NSString stringWithFormat:@"trackEvent: %@ (%@)", event, key];
            [self sendAsynchronousRequest:url context:context];
        }];
    }
}

@end
