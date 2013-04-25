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
@synthesize impressionURLs = _impressionsURL;
@synthesize clickThroughURL = _clickThroughURL;
@synthesize clickTrackingURL = _clickTrackingURL;
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
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[[NSOperationQueue alloc] init]
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            VLogV(response.URL);
            if (error) {
                VLogV(error);
            }
        }];
    }];
}

@end
