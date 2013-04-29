//
//  DVVASTPlayer.h
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "DVVideoMultipleAdPlaylist.h"
#import "DVVideoPlayBreak.h"
#import "DVVideoAd.h"

extern NSString *const DVIABPlayerErrorDomain;

enum {
    
    DVIABPlayerInvalidAdTemplateURLErrorCode = 1,
    
} DVIABPlayerErrorCode;


@class DVIABPlayer;

@protocol DVIABPlayerDelegate <NSObject>

@optional

- (BOOL)player:(DVIABPlayer *)player shouldPauseForAdBreak:(DVVideoPlayBreak *)playBreak;
- (void)player:(DVIABPlayer *)player didFailPlayBreak:(DVVideoPlayBreak *)playBreak withError:(NSError *)error;

@end


@interface DVIABPlayer : AVPlayer <NSURLConnectionDataDelegate>

@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, weak) id<DVIABPlayerDelegate> delegate;
@property (nonatomic, strong) AVPlayerItem *contentPlayerItem; // main content player item as opposed to advertisement player items
@property (nonatomic, strong) DVVideoMultipleAdPlaylist *adPlaylist;
@property (nonatomic, strong) NSDictionary *httpHeaders;
@property (nonatomic, strong, readonly) DVVideoAd *currentAd;

- (void)finishPlayBreaksQueue;

@end
