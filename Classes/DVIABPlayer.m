//
//  DVVASTPlayer.m
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVIABPlayer.h"
#import "DVVideoAdServingTemplate+Parsing.h"
#import "DVVideoAd.h"
#import "DVInlineVideoAd.h"
#import "DVWrapperVideoAd.h"


#define AD_REQUEST_TIMEOUT_INTERVAL ((NSTimeInterval)5.f)
#define AD_PLAY_BREAK_MIN_INTERVAL_BETWEEN ((NSTimeInterval)5.f)

static void *DVIABPlayerInlineAdPlayerItemStatusObservationContext = &DVIABPlayerInlineAdPlayerItemStatusObservationContext;
static void *DVIABContentPlayerRateObservationContext = &DVIABContentPlayerRateObservationContext;
static void *DVIABAdPlayerRateObservationContext = &DVIABAdPlayerRateObservationContext;


NSString *const DVIABPlayerErrorDomain = @"DVIABPlayerErrorDomain";


@interface DVIABPlayer ()

@property (nonatomic, strong) AVPlayer *adPlayer;

@property (nonatomic, strong) id playBreaksTimeObserver;
@property (nonatomic, strong) id periodicAdTimeObserver;
@property (nonatomic, strong) id periodicTimeObserver;
@property (nonatomic, strong) NSMutableArray *playBreaksQueue;
@property (nonatomic, strong) DVVideoPlayBreak *currentPlayBreak;
@property (nonatomic, strong) NSMutableData *adRequestData;
@property (nonatomic, strong) NSMutableArray *adsQueue;
@property (nonatomic, strong) AVPlayerItem *currentInlineAdPlayerItem;
@property (nonatomic) BOOL contentPlayerItemDidReachEnd, didFinishPlayBreakRecently, firstQuartile, midpoint, thirdQuartile;
@property (nonatomic, strong, readonly) DVInlineVideoAd *currentInlineAd;
@property (nonatomic, strong) DVWrapperVideoAd *wrapper;

- (void)startPlayBreaksFromQueue;
- (void)finishCurrentPlayBreak;
- (void)fetchPlayBreakAdTemplate:(DVVideoPlayBreak *)playBreak;
- (void)startAdsFromQueue;
- (void)playInlineAd:(DVInlineVideoAd *)videoAd;
- (void)finishCurrentInlineAd:(AVPlayerItem *)playerItem;

@end


@implementation DVIABPlayer {
    BOOL paused;
}

@synthesize currentAd = _currentAd;

- (id)init
{
    if (self = [super init]) {
        [self addObserver:self
               forKeyPath:@"rate"
                  options:NSKeyValueObservingOptionNew
                  context:DVIABContentPlayerRateObservationContext];
    }
    return self;
}

- (DVInlineVideoAd*)currentInlineAd
{
    if ([self.currentAd isKindOfClass:[DVInlineVideoAd class]]) {
        return (DVInlineVideoAd*)self.currentAd;
    } else {
        return nil;
    }
}

@synthesize adPlayer = _adPlayer;

- (void)setAdPlayer:(AVPlayer *)adPlayer
{
    if (adPlayer != _adPlayer && _adPlayer != nil) {
        [_adPlayer removeObserver:self
                       forKeyPath:@"rate"
                          context:DVIABAdPlayerRateObservationContext];
    }
    
    _adPlayer = adPlayer;
    
    if (_adPlayer != nil) {
        [_adPlayer addObserver:self
                    forKeyPath:@"rate"
                       options:NSKeyValueObservingOptionNew
                       context:DVIABAdPlayerRateObservationContext];
    }
}

@synthesize playerLayer = _playerLayer;
@synthesize delegate = _delegate;
@synthesize playBreaksQueue = _playBreaksQueue;
@synthesize adRequestData = _adRequestData;
@synthesize contentPlayerItem = _contentPlayerItem;

- (void)setContentPlayerItem:(AVPlayerItem *)contentPlayerItem
{
    if (contentPlayerItem == nil && _contentPlayerItem != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:_contentPlayerItem];
    }
    
    _contentPlayerItem = contentPlayerItem;
    
    if (_contentPlayerItem != nil) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(contentPlayerItemDidReachEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:_contentPlayerItem];
    }
}

- (void)contentPlayerItemDidReachEnd:(NSNotification *)notification
{
    VLogC();
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (! self.contentPlayerItemDidReachEnd) {
            self.playBreaksQueue = [[self.adPlaylist postRollPlayBreaks] mutableCopy];
            [self startPlayBreaksFromQueue];
        }
        
        self.contentPlayerItemDidReachEnd = YES;
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == DVIABPlayerInlineAdPlayerItemStatusObservationContext) {
        AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        VLog(@"DVIABPlayerInlineAdPlayerItemStatusObservationContext %i", status);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (status) {
                case AVPlayerItemStatusReadyToPlay:
                    self.playerLayer.player = self.adPlayer;
                    [self.currentInlineAd trackEvent:@"start"];
                    [self.currentInlineAd trackImpressions];
                    [self.adPlayer play];
                    break;
                    
                case AVPlayerItemStatusFailed:
                    VLog(@"AVPlayerItemStatusFailed %@", self.currentInlineAdPlayerItem.error);
                    [self finishCurrentInlineAd:self.currentInlineAdPlayerItem];
                    break;
                    
                case AVPlayerItemStatusUnknown:
                    break;
            }
        });
    }
    else if (context == DVIABContentPlayerRateObservationContext) {
        float rate = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
        VLog(@"DVIABPlayerRateObservationContext %@ %f", self.currentItem, rate);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (rate > 0) {
                self.contentPlayerItemDidReachEnd = NO;
                
                if (CMTimeCompare(CMTimeAbsoluteValue(self.currentItem.currentTime),
                                  CMTimeMake(1, 1)) == -1) {
                    self.playBreaksQueue = [[self.adPlaylist preRollPlayBreaks] mutableCopy];
                    [self startPlayBreaksFromQueue];
                }
            }
        });
    }
    else if (context == DVIABAdPlayerRateObservationContext) {
        // Sometimes AVPlayer just stops playback before reaching end.
        // In this case we need to call play.
        
        float rate = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
        VLog(@"DVIABPlayerRateObservationContext %@ %f", self.currentItem, rate);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (rate == 0 && !paused) {
                VLogV(self.playerLayer);
                self.playerLayer.player = self.adPlayer;
                [self.adPlayer play];
            }
            paused = NO;
        });
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
        [self removeTimeObserver:self.periodicTimeObserver];
        [self removeTimeObserver:self.periodicAdTimeObserver];
        self.playBreaksTimeObserver = nil;
    }
    
    _adPlaylist = adPlaylist;
    
    if (_adPlaylist != nil) {
        NSMutableArray *boundaryTimes = [NSMutableArray array];
        [boundaryTimes addObjectsFromArray:[[_adPlaylist midRollTimes] mutableCopy]];
        
        VLogV(boundaryTimes);
        
        DVIABPlayer* __block player = self;
        if (boundaryTimes && boundaryTimes.count) {
            self.playBreaksTimeObserver = [self addBoundaryTimeObserverForTimes:boundaryTimes queue:NULL usingBlock:^{
                if (player.currentItem != player.contentPlayerItem) {
                    return;
                }
                
                CMTime currentTime = player.currentTime;
                VLog(@"playBreaksTimeObserver %@", CFBridgingRelease(CMTimeCopyDescription(nil, currentTime)));
                
                NSArray *playBreaks = [player.adPlaylist midRollPlayBreaksWithTime:currentTime approximate:YES];
                NSCAssert([playBreaks count], @"No play breaks found for boundary time");
                player.playBreaksQueue = [playBreaks mutableCopy];
                [player startPlayBreaksFromQueue];
            }];
        }
        
        __block CMTime previousTime = kCMTimeNegativeInfinity;
        self.periodicTimeObserver = [self addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(AD_PLAY_BREAK_MIN_INTERVAL_BETWEEN, 1) queue:NULL usingBlock:^(CMTime time) {
//            VLogI((int)time.value);
            if (player.currentItem == player.contentPlayerItem &&
                CMTimeCompare(CMTimeMakeWithSeconds(AD_PLAY_BREAK_MIN_INTERVAL_BETWEEN, 1),
                              CMTimeAbsoluteValue(CMTimeSubtract(previousTime, time))) == -1) {
                    previousTime = time;
                    player.didFinishPlayBreakRecently = NO;
                }
        }];
    }
}

- (BOOL)delegateAllowsToPauseForAdBreak:(DVVideoPlayBreak *)playBreak
{
    return (! [self.delegate respondsToSelector:@selector(player:shouldPauseForAdBreak:)] ||
            [self.delegate player:self shouldPauseForAdBreak:playBreak]);
}

- (void)startPlayBreaksFromQueue
{
    VLogV(self.playBreaksQueue);
    
    if (self.didFinishPlayBreakRecently) {
        // previous ad break happened not long ago, skip this one
        [self finishPlayBreaksQueue];
        return;
    }
    
    if ([self.playBreaksQueue count] > 0) {
        [self pause];
        
        DVVideoPlayBreak *brk = [self.playBreaksQueue objectAtIndex:0];
        [self.playBreaksQueue removeObjectAtIndex:0];
        
        if (! [self delegateAllowsToPauseForAdBreak:brk]) {
            [self startPlayBreaksFromQueue];
        }
        
        self.currentPlayBreak = brk;
        
        [self fetchPlayBreakAdTemplate:self.currentPlayBreak];
    }
    else {
        [self finishPlayBreaksQueue];
    }
}

- (void)finishPlayBreaksQueue
{
    self.didFinishPlayBreakRecently = YES;
    self.playerLayer.player = self;
    self.adPlayer = nil;
    
    if (! self.contentPlayerItemDidReachEnd) {
        [self play];
    }
}

- (void)finishCurrentPlayBreak
{
    VLogV(self.currentPlayBreak);
    
    self.currentPlayBreak = nil;
    [self startPlayBreaksFromQueue];
}

- (void)startAdsFromQueue
{
    VLogV(self.adsQueue);
    
    if ([self.adsQueue count] > 0) {
        _currentAd = [self.adsQueue objectAtIndex:0];
        [self.adsQueue removeObjectAtIndex:0];
        
        if (_currentAd.playMediaFile) {
            if (self.currentInlineAd) {
                [self playInlineAd:self.currentInlineAd];
            } else {
                NSAssert(NO, @"Not supported");
                [self finishCurrentInlineAd:nil];
            }
        } else {
            [self finishCurrentInlineAd:nil];
        }
    }
    else {
        [self finishCurrentPlayBreak];
    }
}

- (void)playInlineAd:(DVInlineVideoAd *)videoAd
{
    VLogV(videoAd);
    
    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithURL:videoAd.mediaFileURL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inlineAdPlayerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inlineAdPlayerItemDidFailToReachEnd:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:playerItem];
    [playerItem addObserver:self
                 forKeyPath:@"status"
                    options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
                    context:DVIABPlayerInlineAdPlayerItemStatusObservationContext];
    
    self.currentInlineAdPlayerItem = playerItem;
    
    self.adPlayer = [[AVPlayer alloc] initWithPlayerItem:playerItem];
    Float64 duration = CMTimeGetSeconds(playerItem.duration);
//    VLogF(duration);
    typeof(self) SELF = self;
    self.firstQuartile = self.midpoint = self.thirdQuartile = NO;
    self.periodicAdTimeObserver = [self.adPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 1) queue:NULL usingBlock:^(CMTime time) {
        Float64 current = CMTimeGetSeconds(time)/duration;
        if (current >= .25 && !SELF.firstQuartile) {
            SELF.firstQuartile = YES;
            [SELF.currentInlineAd trackEvent:@"firstQuartile"];
        }
        if (current >= .5 && !SELF.midpoint) {
            SELF.midpoint = YES;
            [SELF.currentInlineAd trackEvent:@"midpoint"];
        }
        if (current >= .75 && !SELF.thirdQuartile) {
            SELF.thirdQuartile = YES;
            [SELF.currentInlineAd trackEvent:@"thirdQuartile"];
        }
//        VLogF(current);
    }];
    
    // Other TrackingEvents (Not Implemented)
    // ——————————————————————————————————————
    // fullscreen
    // mute
    // unmute
    // expand
    // collapse
    // acceptInvitation
    // close
}

- (void)inlineAdPlayerItemDidReachEnd:(NSNotification *)notification
{
    AVPlayerItem *playerItem = [notification object];
    VLogV(playerItem);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self finishCurrentInlineAd:playerItem];
    });
}

- (void)inlineAdPlayerItemDidFailToReachEnd:(NSNotification *)notification
{
    AVPlayerItem *playerItem = [notification object];
    VLog(@"%@ userInfo:%@", playerItem, [notification userInfo]);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self finishCurrentInlineAd:playerItem];
    });
}

- (void)finishCurrentInlineAd:(AVPlayerItem *)playerItem
{
    VLogV(playerItem);

    [self.currentInlineAd trackEvent:@"complete"];

    if (playerItem != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:playerItem];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                      object:playerItem];
        [playerItem removeObserver:self forKeyPath:@"status"
                           context:DVIABPlayerInlineAdPlayerItemStatusObservationContext];
    }
    
    [self startAdsFromQueue];
}

- (void)pause
{
    if (self.adPlayer) {
        paused = YES;
        [self.currentInlineAd trackEvent:@"pause"];
        [self.adPlayer pause];
    } else {
        [super pause];
    }
}

- (void)play
{
    if (self.adPlayer) {
        [self.adPlayer play];
    } else {
        [super play];
    }
}

- (void)dealloc
{
    self.adPlayer = nil; // remove observers
    self.adPlaylist = nil; // to remove time observer
    self.contentPlayerItem = nil; // to remove notification observer
    [self removeObserver:self forKeyPath:@"rate"
                 context:DVIABContentPlayerRateObservationContext];
}

#pragma mark - Networking

- (void)fetchPlayBreakAdTemplate:(DVVideoPlayBreak *)playBreak
{
    VLogV(playBreak);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:playBreak.adServingTemplateURL
                                             cachePolicy:NSURLRequestReloadIgnoringCacheData
                                         timeoutInterval:AD_REQUEST_TIMEOUT_INTERVAL];
    
    // Set HTTP Headers if any where passed.
    for (NSString *field in _httpHeaders) {
        [request setValue:_httpHeaders[field] forHTTPHeaderField:field];
    }
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];    
    if (! connection) {
        if ([self.delegate respondsToSelector:@selector(player:didFailPlayBreak:withError:)]) {
            NSError *error = [NSError errorWithDomain:DVIABPlayerErrorDomain
                                                 code:DVIABPlayerInvalidAdTemplateURLErrorCode
                                             userInfo:nil];
            [self.delegate player:self didFailPlayBreak:playBreak withError:error];
        }
        
        self.currentPlayBreak = nil;
        
        [self startPlayBreaksFromQueue];
        return;
    }
    
    self.adRequestData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.adRequestData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.adRequestData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.adRequestData = nil;
    
    if ([self.delegate respondsToSelector:@selector(player:didFailPlayBreak:withError:)]) {
        [self.delegate player:self didFailPlayBreak:self.currentPlayBreak withError:error];
    }

    [self finishCurrentPlayBreak];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    VLog(@"%@", [[NSString alloc] initWithData:self.adRequestData encoding:NSUTF8StringEncoding]);
    
    NSError *error = nil;
    DVVideoAdServingTemplate *adTemplate = [[DVVideoAdServingTemplate alloc] initWithData:self.adRequestData error:&error];
    self.adRequestData = nil;
    if (! adTemplate) {
        if ([self.delegate respondsToSelector:@selector(player:didFailPlayBreak:withError:)]) {
            [self.delegate player:self didFailPlayBreak:self.currentPlayBreak withError:error];
        }
        
        [self finishCurrentPlayBreak];
        return;
    }
    
    VLogV(adTemplate.ads);
    
    if ((adTemplate.ads.count && [adTemplate.ads[0] isKindOfClass:[DVWrapperVideoAd class]]) || self.wrapper) {
        if (!self.wrapper) {
            self.wrapper = (DVWrapperVideoAd*)adTemplate.ads[0];
        }
        if (!self.adsQueue) { // adTemplate.ads.count && adTemplate.ads[0] == wrapper
            // Supercharge with the inline ad.
            self.adsQueue = [adTemplate.ads mutableCopy];
            [self fetchPlayBreakAdTemplate:_wrapper.videoPlayBreak];
        } else {
            // Probably means we've supercharged and we're ready to go!
            // TODO: We should move this in DVVideoAdServingTemplate
            NSArray *adElements = [adTemplate.document.rootElement elementsForName:@"Ad"];
            VLogV(adElements);
            for (DDXMLElement *adElement in adElements) {
                DDXMLElement *adContents = (DDXMLElement *)[adElement childAtIndex:0];
                NSString *adContentsName = [adContents name];
                if ([adContentsName isEqualToString:@"InLine"]) {
                    NSError *error = nil;
                    [adTemplate populateInlineVideoAd:_wrapper withXMLElement:adContents error:&error];
                    if (error) {
                        VLogV(error);
                    }
                }
            }
            self.adsQueue = [@[_wrapper] mutableCopy];
            [self startAdsFromQueue];
        }
    } else {
        // Simply play the inline ad.
        self.adsQueue = [adTemplate.ads mutableCopy];
        [self startAdsFromQueue];
    }
}

@end
