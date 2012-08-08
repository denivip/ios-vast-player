//
//  DVViewController.h
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DVVideoMultipleAdPlaylist.h"
#import "DVIABPlayer.h"


@interface DVViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIView *playerView;
@property (strong, nonatomic) IBOutlet UILabel *currentTimeLabel;
@property (strong, nonatomic) IBOutlet UILabel *currentItemTitleLabel;

@property (nonatomic, copy) NSURL *contentURL;
@property (nonatomic, strong) DVVideoMultipleAdPlaylist *adPlaylist;
@property (nonatomic, strong) DVIABPlayer *player;


@end
