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
#import "DVTimeIntervalFormatter.h"
#import "DVVideoMultipleAdPlaylist.h"


static void *DVViewControllerCurrentPlayerItemObservationContext = &DVViewControllerCurrentPlayerItemObservationContext;
static void *DVViewControllerPlayerItemStatusObservationContext = &DVViewControllerPlayerItemStatusObservationContext;

#define OPENX_AD_TAG_WITH_ZONE(ZONE_ID) ([NSURL URLWithString:[NSString stringWithFormat:@"http://openx.denivip.ru/delivery/fc.php?block=0&script=bannerTypeHtml:vastInlineBannerTypeHtml:vastInlineHtml&format=vast&nz=1&charset=UTF-8&r=0.1978856846690178&zones=z%%3D%u", (ZONE_ID)]])

@interface DVViewController ()

@property (nonatomic, strong) id periodicTimeObserver;
@property (nonatomic) BOOL didStartPlayback;

@end


@implementation DVViewController

@synthesize playerView = _playerView;
@synthesize currentTimeLabel = _currentTimeLabel;
@synthesize currentItemTitleLabel = _currentItemTitleLabel;
@synthesize player = _player;
@synthesize periodicTimeObserver = _periodicTimeObserver;

#pragma mark - Player

- (void)startPlaybackWithContentURL:(NSURL *)contentURL
{
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:contentURL];

    [playerItem addObserver:self
                 forKeyPath:@"status"
                    options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
                    context:DVViewControllerPlayerItemStatusObservationContext];
    self.player.contentPlayerItem = playerItem;
    self.didStartPlayback = NO;
    [self.player replaceCurrentItemWithPlayerItem:playerItem];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == DVViewControllerCurrentPlayerItemObservationContext) {
        self.currentItemTitleLabel.text = [((AVURLAsset *)self.player.currentItem.asset).URL absoluteString];
    }
    else if (context == DVViewControllerPlayerItemStatusObservationContext) {
        AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        VLog(@"DVViewControllerPlayerItemStatusObservationContext %i", status);
        if (status == AVPlayerItemStatusReadyToPlay &&
            ! self.didStartPlayback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.didStartPlayback = YES;
                [self.player play];
            });
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Controls

- (IBAction)rewindButton:(id)sender
{
    [self.player seekToTime:CMTimeSubtract(self.player.currentTime, CMTimeMake(60, 1))];
}

- (IBAction)fastForwardButton:(id)sender
{
    [self.player seekToTime:CMTimeAdd(self.player.currentTime, CMTimeMake(60, 1))];
}

- (IBAction)endButton:(id)sender
{
    NSArray *seekableTimeRanges = self.player.currentItem.seekableTimeRanges;
    CMTimeRange seekableRange = [[seekableTimeRanges objectAtIndex:0] CMTimeRangeValue];
    [self.player seekToTime:CMTimeSubtract(CMTimeAdd(seekableRange.start, seekableRange.duration),
                                           CMTimeMake(10, 1))];
}

- (IBAction)playPauseButton:(id)sender
{
    if (self.player.rate > 0) {
        [self.player pause];
    }
    else {
        [self.player play];
    }
}

#pragma mark - View Controller

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.player = [[DVIABPlayer alloc] init];
    // Example of a specific HTTP Header you would want to pass to your server for capping reasons — uncomment to test ;)
    // self.player.httpHeaders = @{@"User-Agent": @"Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1)"};
    self.player.playerLayer = (AVPlayerLayer *)self.playerView.layer;
    ((AVPlayerLayer *)self.playerView.layer).player = self.player;
    
    [self.player addObserver:self
                  forKeyPath:@"currentItem"
                     options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
                     context:DVViewControllerCurrentPlayerItemObservationContext];

    __block DVViewController *SELF = self;
    self.periodicTimeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 10) queue:NULL usingBlock:^(CMTime time) {
        DVTimeIntervalFormatter *formatter = [[DVTimeIntervalFormatter alloc] init];
        SELF.currentTimeLabel.text = [NSString stringWithFormat:@"%@ / %@",
                                      [formatter stringWithTimeInterval:CMTimeGetSeconds(time)],
                                      [formatter stringWithTimeInterval:CMTimeGetSeconds(SELF.player.currentItem.duration)]];
    }];
    
    DVVideoMultipleAdPlaylist *adPlaylist = [[DVVideoMultipleAdPlaylist alloc] init];
    adPlaylist.playBreaks = [NSArray arrayWithObjects:
                             [DVVideoPlayBreak playBreakBeforeStartWithAdTemplateURL:OPENX_AD_TAG_WITH_ZONE(18)],
                             [DVVideoPlayBreak playBreakAtTimeFromStart:CMTimeMake(10, 1) withAdTemplateURL:OPENX_AD_TAG_WITH_ZONE(19)],
                             [DVVideoPlayBreak playBreakAfterEndWithAdTemplateURL:OPENX_AD_TAG_WITH_ZONE(20)],
                             nil];
    
    self.player.adPlaylist = adPlaylist;
    self.player.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    NSURL *contentURL = [NSURL URLWithString:@"https://devimages.apple.com.edgekey.net/resources/http-streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"];
    // NSURL *contentURL = [NSURL URLWithString:@"http://denivip.ru/sites/default/files/ios-iab/content.mp4"];
    [self startPlaybackWithContentURL:contentURL];
}

- (void)viewDidUnload
{
    [self setPlayerView:nil];
    [self setCurrentTimeLabel:nil];
    [self setCurrentItemTitleLabel:nil];
    
    [self.player removeTimeObserver:self.periodicTimeObserver];
    self.periodicTimeObserver = nil;
    
    [self.player removeObserver:self forKeyPath:@"currentItem"
                        context:DVViewControllerCurrentPlayerItemObservationContext];
    self.player = nil;
    
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - Player Delegate

- (BOOL)player:(DVIABPlayer *)player shouldPauseForAdBreak:(DVVideoPlayBreak *)playBreak
{
    return YES;
}

- (void)player:(DVIABPlayer *)player didFailPlayBreak:(DVVideoPlayBreak *)playBreak withError:(NSError *)error
{
    VLogV(error);
}

@end
