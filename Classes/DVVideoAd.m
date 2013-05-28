//
//  DVVideoAd.m
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVVideoAd.h"


@implementation DVVideoAd

@synthesize identifier = _identifier;

- (void)sendAsynchronousRequest:(NSURL*)url context:(id)context
{
    if (url && [url isKindOfClass:[NSURL class]]) {
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [NSURLConnection sendAsynchronousRequest:request queue:[[NSOperationQueue alloc] init] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            VLogV(context);
            VLogV(response.URL);
            if (error) {
                VLogV(error);
            } else {
                if ([context isKindOfClass:[NSMutableArray class]]) {
                    [(NSMutableArray*)context removeObject:url]; // This avoids tracking the URL twice.
                }
            }
        }];
    }
}

@end
