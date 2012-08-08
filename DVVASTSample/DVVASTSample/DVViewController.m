//
//  DVViewController.m
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "DVVideoPlayBreak.h"


static void *DVViewControllerCurrentPlayerItemObservationContext = &DVViewControllerCurrentPlayerItemObservationContext;
static void *DVViewControllerPlayerItemStatusObservationContext = &DVViewControllerPlayerItemStatusObservationContext;

#define OPENX_AD_TAG_WITH_ZONE(ZONE_ID) ([NSURL URLWithString:@"http://openx.denivip.ru/delivery/fc.php?block=0&script=bannerTypeHtml:vastInlineBannerTypeHtml:vastInlineHtml&format=vast&nz=1&charset=UTF-8&r=0.1978856846690178&zones=z=ZONE_ID"])

@interface DVViewController ()

@end


@implementation DVViewController

@synthesize playerView = _playerView;
@synthesize currentTimeLabel = _currentTimeLabel;
@synthesize currentItemTitleLabel = _currentItemTitleLabel;
@synthesize contentURL = _contentURL;
@synthesize adPlaylist = _adPlaylist;
@synthesize player = _player;

#pragma mark - Player

- (void)startPlaybackWithContentURL:(NSURL *)contentURL adPlaylist:(DVVideoMultipleAdPlaylist *)adPlaylist
{
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:contentURL];

    [playerItem addObserver:self
                 forKeyPath:@"status"
                    options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
                    context:DVViewControllerPlayerItemStatusObservationContext];
    [self.player replaceCurrentItemWithPlayerItem:playerItem];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == DVViewControllerCurrentPlayerItemObservationContext) {
        self.currentItemTitleLabel.text = [((AVURLAsset *)self.player.currentItem.asset).URL absoluteString];
    }
    else if (context == DVViewControllerPlayerItemStatusObservationContext) {
        AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        if (status == AVPlayerItemStatusReadyToPlay) {
            [self.player play];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - View Controller

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.player = [[DVIABPlayer alloc] init];
    ((AVPlayerLayer *)self.playerView.layer).player = self.player;
    
    [self.player addObserver:self
                  forKeyPath:@"currentItem"
                     options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
                     context:DVViewControllerCurrentPlayerItemObservationContext];

    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 10) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        NSTimeInterval seconds = CMTimeGetSeconds(time);
        self.currentTimeLabel.text = [NSString stringWithFormat:@"%.3f", seconds];
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.contentURL = [NSURL URLWithString:@"http://denivip.ru/sites/default/files/ios-iab/content.mp4"];
    self.adPlaylist = [[DVVideoMultipleAdPlaylist alloc] init];
    self.adPlaylist.playBreaks = [NSArray arrayWithObjects:
                                  [DVVideoPlayBreak playBreakBeforeStartWithAdTemplateURL:OPENX_AD_TAG_WITH_ZONE(18)],
                                  [DVVideoPlayBreak playBreakAtTimeFromStart:CMTimeMakeWithSeconds(10.f, 1000000) withAdTemplateURL:OPENX_AD_TAG_WITH_ZONE(19)],
                                  [DVVideoPlayBreak playBreakAfterEndWithAdTemplateURL:OPENX_AD_TAG_WITH_ZONE(20)],
                                  nil];
    
    [self startPlaybackWithContentURL:self.contentURL adPlaylist:self.adPlaylist];
}

- (void)viewDidUnload
{
    [self setPlayerView:nil];
    [self setCurrentTimeLabel:nil];
    [self setCurrentItemTitleLabel:nil];
    
    [self.player removeObserver:self forKeyPath:nil];
    self.player = nil;
    
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

@end
