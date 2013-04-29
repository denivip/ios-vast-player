//
//  DVWrapperVideoAd.m
//  DVVASTSample
//
//  Created by Manuel "StuFF mc" Carrasco Molina in 2013 — https://github.com/stuffmc/ios-vast-player/tree/dev
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVWrapperVideoAd.h"
#import "DVVideoPlayBreak.h"


@implementation DVWrapperVideoAd

@synthesize URL = _URL;

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ id:%@ url:%@", [super description],
            self.identifier, self.URL];
}

- (DVVideoPlayBreak *)videoPlayBreak
{
    return [DVVideoPlayBreak playBreakAfterEndWithAdTemplateURL:self.URL];
}


@end
