//
//  DVPlayerView.h
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/8/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>


@interface DVPlayerView : UIView

@property (nonatomic, readonly, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, weak) NSString *videoGravity;

@end
