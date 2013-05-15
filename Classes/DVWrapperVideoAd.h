//
//  DVWrapperVideoAd.h
//  DVVASTSample
//
//  Created by Manuel "StuFF mc" Carrasco Molina in 2013 — https://github.com/stuffmc/ios-vast-player/tree/dev
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVInlineVideoAd.h"


@class DVVideoPlayBreak;

@interface DVWrapperVideoAd : DVInlineVideoAd

@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, strong, readonly) DVVideoPlayBreak *videoPlayBreak;

@end
