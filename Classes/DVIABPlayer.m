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


#define AD_REQUEST_TIMEOUT_INTERVAL ((NSTimeInterval)5.f)
#define AD_PLAY_BREAK_MIN_INTERVAL_BETWEEN ((NSTimeInterval)5.f)

static void *DVIABPlayerContentPlayerItemStatusObservationContext = &DVIABPlayerContentPlayerItemStatusObservationContext;
static void *DVIABPlayerInlineAdPlayerItemStatusObservationContext = &DVIABPlayerInlineAdPlayerItemStatusObservationContext;
static void *DVIABPlayerCurrentItemObservationContext = &DVIABPlayerCurrentItemObservationContext;
static void *DVIABPlayerRateObservationContext = &DVIABPlayerRateObservationContext;


NSString *const DVIABPlayerErrorDomain = @"DVIABPlayerErrorDomain";


@interface DVIABPlayer ()

@property (nonatomic, strong) id playBreaksTimeObserver;
@property (nonatomic, strong) id periodicTimeObserver;
@property (nonatomic, strong) NSMutableArray *playBreaksQueue;
@property (nonatomic, strong) DVVideoPlayBreak *currentPlayBreak;
@property (nonatomic, strong) NSMutableData *adRequestData;
@property (nonatomic, strong) NSMutableArray *adsQueue;
@property (nonatomic) BOOL contentPlayerItemDidReachEnd;
@property (nonatomic) BOOL didFinishPlayBreakRecently;

- (void)startPlayBreaksFromQueue;
- (void)finishPlayBreaksQueue;
- (void)finishCurrentPlayBreak;
- (void)fetchPlayBreakAdTemplate:(DVVideoPlayBreak *)playBreak;
- (void)startAdsFromQueue;
- (void)playInlineAd:(DVInlineVideoAd *)videoAd;
- (void)finishCurrentInlineAd:(AVPlayerItem *)playerItem;

@end


@implementation DVIABPlayer

- (id)init
{
    if (self = [super init]) {
        [self addObserver:self
               forKeyPath:@"currentItem"
                  options:NSKeyValueObservingOptionNew
                  context:DVIABPlayerCurrentItemObservationContext];
        [self addObserver:self
               forKeyPath:@"rate"
                  options:NSKeyValueObservingOptionNew
                  context:DVIABPlayerRateObservationContext];
    }
    return self;
}

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
        [_contentPlayerItem removeObserver:self forKeyPath:@"status"
                                   context:DVIABPlayerContentPlayerItemStatusObservationContext];
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
                                context:DVIABPlayerContentPlayerItemStatusObservationContext];
    }
}

- (void)contentPlayerItemDidReachEnd:(NSNotification *)notification
{
    NSLog(@"contentPlayerItemDidReachEnd:");
    
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
    if (context == DVIABPlayerContentPlayerItemStatusObservationContext) {
        AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        NSLog(@"DVIABPlayerContentPlayerItemStatusObservationContext %i", status);
    }
    else if (context == DVIABPlayerInlineAdPlayerItemStatusObservationContext) {
        AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        NSLog(@"DVIABPlayerInlineAdPlayerItemStatusObservationContext %i", status);
        
        switch (status) {
            case AVPlayerItemStatusReadyToPlay:
                [self play];
                break;
                
            case AVPlayerItemStatusFailed:
                [self finishCurrentInlineAd:self.currentItem];
                break;

            case AVPlayerItemStatusUnknown:
                break;
        }
    }
    else if (context == DVIABPlayerCurrentItemObservationContext) {
        AVPlayerItem *currentItem = [change objectForKey:NSKeyValueChangeNewKey];
        NSLog(@"DVIABPlayerCurrentItemObservationContext %@ %i", currentItem, currentItem.status);

        if (currentItem == self.contentPlayerItem &&
            currentItem.status == AVPlayerItemStatusReadyToPlay &&
            ! self.contentPlayerItemDidReachEnd) {
            [self play]; // on finish ad playback
        }
    }
    else if (context == DVIABPlayerRateObservationContext) {
        // Sometimes AVPlayer just stops playback before reaching end.
        // In this case we need to call play.
        
        float rate = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
        NSLog(@"DVIABPlayerRateObservationContext %@ %f", self.currentItem, rate);

        if (rate == 0 &&
            self.currentItem != self.contentPlayerItem) {
            [self play];
        }
        
        if (rate > 0 &&
            self.currentItem == self.contentPlayerItem) {
            self.contentPlayerItemDidReachEnd = NO;
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
        [self removeTimeObserver:self.periodicTimeObserver];
        self.playBreaksTimeObserver = nil;
    }
    
    _adPlaylist = adPlaylist;
    
    if (_adPlaylist != nil) {
        NSMutableArray *boundaryTimes = [NSMutableArray array];
        if ([[_adPlaylist preRollPlayBreaks] count] > 0) {
            [boundaryTimes addObject:[NSValue valueWithCMTime:CMTimeMake(1, 1000)]];
        }
        [boundaryTimes addObjectsFromArray:[[_adPlaylist midRollTimes] mutableCopy]];
        
        NSLog(@"%@", boundaryTimes);
        
        id __block player = self;
        self.playBreaksTimeObserver = [self addBoundaryTimeObserverForTimes:boundaryTimes queue:NULL usingBlock:^{
            if (self.currentItem != self.contentPlayerItem) {
                return;
            }
            
            CMTime currentTime = self.currentTime;
            NSLog(@"playBreaksTimeObserver %@", CMTimeCopyDescription(nil, currentTime));
            
            if (CMTimeCompare(CMTimeAbsoluteValue(currentTime),
                              CMTimeMake(1, 1)) == -1) {
                self.playBreaksQueue = [[self.adPlaylist preRollPlayBreaks] mutableCopy];
            }
            else {
                NSArray *playBreaks = [self.adPlaylist midRollPlayBreaksWithTime:currentTime approximate:YES];
                NSCAssert([playBreaks count], @"No play breaks found for boundary time");
                self.playBreaksQueue = [playBreaks mutableCopy];
            }

            [player startPlayBreaksFromQueue];
        }];
        
        __block CMTime previousTime = kCMTimeNegativeInfinity;
        self.periodicTimeObserver = [self addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(AD_PLAY_BREAK_MIN_INTERVAL_BETWEEN, 1) queue:NULL usingBlock:^(CMTime time) {
            if (self.currentItem == self.contentPlayerItem &&
                CMTimeCompare(CMTimeMakeWithSeconds(AD_PLAY_BREAK_MIN_INTERVAL_BETWEEN, 1),
                              CMTimeAbsoluteValue(CMTimeSubtract(previousTime, time))) == -1) {
                    previousTime = time;
                    self.didFinishPlayBreakRecently = NO;
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
    NSLog(@"startPlayBreaksFromQueue %@", self.playBreaksQueue);
    
    if (self.didFinishPlayBreakRecently) {
        // previous ad break happened not long ago, skip this one
        [self finishPlayBreaksQueue];
        return;
    }
    
    if ([self.playBreaksQueue count] > 0) {
        DVVideoPlayBreak *brk = [self.playBreaksQueue objectAtIndex:0];
        [self.playBreaksQueue removeObjectAtIndex:0];
        
        if (! [self delegateAllowsToPauseForAdBreak:brk]) {
            [self startPlayBreaksFromQueue];
        }
        
        self.currentPlayBreak = brk;
        
        [self pause];
        [self fetchPlayBreakAdTemplate:self.currentPlayBreak];
    }
    else {
        [self finishPlayBreaksQueue];
    }
}

- (void)finishPlayBreaksQueue
{
    self.didFinishPlayBreakRecently = YES;
    if (self.currentItem != self.contentPlayerItem) {
        [self replaceCurrentItemWithPlayerItem:self.contentPlayerItem];
    }
    else if (self.currentItem.status == AVPlayerItemStatusReadyToPlay &&
             ! self.contentPlayerItemDidReachEnd) {
        [self play];
    }
}

- (void)finishCurrentPlayBreak
{
    NSLog(@"finishCurrentPlayBreak %@", self.currentPlayBreak);
    
    self.currentPlayBreak = nil;
    [self startPlayBreaksFromQueue];
}

- (void)startAdsFromQueue
{
    NSLog(@"startAdsFromQueue %@", self.adsQueue);
    
    if ([self.adsQueue count] > 0) {
        DVVideoAd *currentAd = [self.adsQueue objectAtIndex:0];
        [self.adsQueue removeObjectAtIndex:0];

        if ([currentAd isKindOfClass:[DVInlineVideoAd class]]) {
            [self playInlineAd:(DVInlineVideoAd *)currentAd];
        }
        else {
            NSAssert(NO, @"Not supported");
            [self finishCurrentInlineAd:nil];
        }
    }
    else {
        [self finishCurrentPlayBreak];
    }
}

- (void)playInlineAd:(DVInlineVideoAd *)videoAd
{
    NSLog(@"playInlineAd:%@", videoAd);
    
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
    
    [self replaceCurrentItemWithPlayerItem:playerItem];
}

- (void)inlineAdPlayerItemDidReachEnd:(NSNotification *)notification
{
    AVPlayerItem *playerItem = [notification object];
    NSLog(@"inlineAdPlayerItemDidReachEnd:%@", playerItem);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self finishCurrentInlineAd:playerItem];
    });
}

- (void)inlineAdPlayerItemDidFailToReachEnd:(NSNotification *)notification
{
    AVPlayerItem *playerItem = [notification object];
    NSLog(@"inlineAdPlayerItemDidFailToReachEnd:%@ userInfo:%@", playerItem, [notification userInfo]);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self finishCurrentInlineAd:playerItem];
    });
}

- (void)finishCurrentInlineAd:(AVPlayerItem *)playerItem
{
    NSLog(@"finishCurrentInlineAd:%@", playerItem);
    
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

- (void)dealloc
{
    self.adPlaylist = nil; // to remove time observer
    self.contentPlayerItem = nil; // to remove notification observer
    [self removeObserver:self forKeyPath:@"currentItem"
                 context:DVIABPlayerCurrentItemObservationContext];
    [self removeObserver:self forKeyPath:@"rate"
                 context:DVIABPlayerRateObservationContext];
}

#pragma mark - Networking

- (void)fetchPlayBreakAdTemplate:(DVVideoPlayBreak *)playBreak
{
    NSLog(@"fetchPlayBreakAdTemplate:%@", playBreak);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:playBreak.adServingTemplateURL
                                             cachePolicy:NSURLRequestReloadIgnoringCacheData
                                         timeoutInterval:AD_REQUEST_TIMEOUT_INTERVAL];
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
    NSLog(@"connectionDidFinishLoading:%@", [[NSString alloc] initWithData:self.adRequestData encoding:NSUTF8StringEncoding]);
    
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
    
    self.adsQueue = [adTemplate.ads mutableCopy];
    [self startAdsFromQueue];
}

@end
