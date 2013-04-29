//
//  DVVideoMultipleAdPlaylist.h
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>


// http://www.iab.net/media/file/VMAPv1.0.pdf

@interface DVVideoMultipleAdPlaylist : NSObject

@property (nonatomic, copy) NSArray *playBreaks;

- (NSArray *)midRollTimes;
- (NSArray *)midRollPlayBreaksWithTime:(CMTime)time approximate:(BOOL)approximate; // approximation interval +-1sec
- (NSArray *)midRollPlayBreaksWithTime:(CMTime)time;
- (NSArray *)preRollPlayBreaks;
- (NSArray *)postRollPlayBreaks;

@end
