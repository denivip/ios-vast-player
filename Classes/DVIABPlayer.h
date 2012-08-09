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


@interface DVIABPlayer : AVPlayer

@property (nonatomic, strong) AVPlayerItem *contentPlayerItem; // main content player item as opposed to advertisement player items
@property (nonatomic, strong) DVVideoMultipleAdPlaylist *adPlaylist;

@end
