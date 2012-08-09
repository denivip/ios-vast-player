//
//  DVVASTPlayer.m
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVIABPlayer.h"


static void *DVIABPlayerPlayerItemStatusObservationContext = &DVIABPlayerPlayerItemStatusObservationContext;


@interface DVIABPlayer ()

@property (nonatomic, strong) id playBreaksTimeObserver;

@end


@implementation DVIABPlayer

@synthesize contentPlayerItem = _contentPlayerItem;

- (void)setContentPlayerItem:(AVPlayerItem *)contentPlayerItem
{
    if (contentPlayerItem == nil && _contentPlayerItem != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:_contentPlayerItem];
        [_contentPlayerItem removeObserver:self forKeyPath:nil];
    }
    
    _contentPlayerItem = contentPlayerItem;
    
    if (_contentPlayerItem != nil) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(contentPlayerItemDidReachEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:_contentPlayerItem];
        [_contentPlayerItem addObserver:self
                             forKeyPath:@"status"
                                options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
                                context:DVIABPlayerPlayerItemStatusObservationContext];
    }
}

- (void)contentPlayerItemDidReachEnd:(NSNotification *)notification
{
    // AVPlayerItem *playerItem = [notification object];
    
    // post-roll
    
    NSArray *playBreaks = [self.adPlaylist postRollPlayBreaks];
    NSLog(@"%@", playBreaks);
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == DVIABPlayerPlayerItemStatusObservationContext) {
        AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        if (status == AVPlayerItemStatusReadyToPlay) {
            
            // pre-roll
            
            NSArray *playBreaks = [self.adPlaylist preRollPlayBreaks];
            NSLog(@"%@", playBreaks);
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@synthesize playBreaksTimeObserver = _playBreaksTimeObserver;
@synthesize adPlaylist = _adPlaylist;

- (void)setAdPlaylist:(DVVideoMultipleAdPlaylist *)adPlaylist
{
    if (adPlaylist == nil && self.playBreaksTimeObserver != nil) {
        [self removeTimeObserver:self.playBreaksTimeObserver];
        self.playBreaksTimeObserver = nil;
    }
    
    _adPlaylist = adPlaylist;
    
    if (_adPlaylist != nil) {
        self.playBreaksTimeObserver = [self addBoundaryTimeObserverForTimes:[_adPlaylist midRollTimes] queue:NULL usingBlock:^{
            
            CMTime currentTime = self.currentTime;
            NSArray *playBreaks = [self.adPlaylist midRollPlayBreaksWithTime:currentTime approximate:YES];
            NSCAssert([playBreaks count], @"No play breaks found for boundary time");
            NSLog(@"%@", playBreaks);
            
        }];
    }
}

- (void)dealloc
{
    self.adPlaylist = nil; // to remove time observer
    self.contentPlayerItem = nil; // to remove notification observer
}

@end
