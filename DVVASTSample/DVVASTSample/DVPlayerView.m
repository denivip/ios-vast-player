//
//  DVPlayerView.m
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/8/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVPlayerView.h"


@implementation DVPlayerView

+ (Class)layerClass
{
    return [AVPlayerLayer class];
}

- (AVPlayerLayer *)playerLayer
{
    return (AVPlayerLayer *)self.layer;
}

- (void)setup
{
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideButtonDoubleTapped:)];
    doubleTap.numberOfTapsRequired = 2;
    [self addGestureRecognizer:doubleTap];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self setup];
    }
    return self;
}

@synthesize videoGravity = _videoGravity;

- (NSString *)videoGravity
{
    return self.playerLayer.videoGravity;
}

- (void)setVideoGravity:(NSString *)gravity
{
    self.playerLayer.videoGravity = gravity;
    self.playerLayer.frame = self.playerLayer.frame; // workaround iOS5 bug
}

- (void)hideButtonDoubleTapped:(UITapGestureRecognizer *)tap
{
    if ([self.videoGravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        self.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    else {
        self.videoGravity = AVLayerVideoGravityResizeAspect;
    }
}

@end
