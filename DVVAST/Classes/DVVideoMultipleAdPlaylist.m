//
//  DVVideoMultipleAdPlaylist.m
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "DVVideoMultipleAdPlaylist.h"
#import "DVVideoPlayBreak.h"


@implementation DVVideoMultipleAdPlaylist

@synthesize playBreaks = _playBreaks;

- (NSArray *)midRollTimes
{
    NSMutableArray *times = [NSMutableArray arrayWithCapacity:[self.playBreaks count]];
    
    [self.playBreaks enumerateObjectsUsingBlock:^(DVVideoPlayBreak *brk, NSUInteger idx, BOOL *stop) {
        switch (brk.timeOffsetType) {
            case DVVideoPlayBreakTimeOffsetFromStart:
                [times addObject:[NSValue valueWithCMTime:brk.timeFromStart]];
                break;
                
            case DVVideoPlayBreakTimeOffsetStart:
            case DVVideoPlayBreakTimeOffsetEnd:
                // use other methods to test for pre-rolls and post-rolls
                break;
                
            case DVVideoPlayBreakTimeOffsetPercentage:
            case DVVideoPlayBreakTimeOffsetPositional:
                NSAssert(NO, @"Not implemented");
                break;
        }
    }];
    
    return [NSArray arrayWithArray:times];
}

- (NSArray *)midRollPlayBreaksWithTime:(CMTime)time approximate:(BOOL)approximate
{
    NSMutableArray *playBreaks = [NSMutableArray array];
    
    [self.playBreaks enumerateObjectsUsingBlock:^(DVVideoPlayBreak *brk, NSUInteger idx, BOOL *stop) {
        if (brk.timeOffsetType == DVVideoPlayBreakTimeOffsetFromStart &&
            ((!approximate && CMTimeCompare(brk.timeFromStart, time) == 0) ||
             (approximate && CMTimeCompare(CMTimeAbsoluteValue(CMTimeSubtract(brk.timeFromStart, time)),
                                           CMTimeMake(1, 1)) == -1))) {
            [playBreaks addObject:brk];
        }
    }];
    
    return [NSArray arrayWithArray:playBreaks];
}

- (NSArray *)midRollPlayBreaksWithTime:(CMTime)time
{
    return [self midRollPlayBreaksWithTime:time approximate:NO];
}

- (NSArray *)preRollPlayBreaks
{
    NSMutableArray *playBreaks = [NSMutableArray array];
    
    [self.playBreaks enumerateObjectsUsingBlock:^(DVVideoPlayBreak *brk, NSUInteger idx, BOOL *stop) {
        if (brk.timeOffsetType == DVVideoPlayBreakTimeOffsetStart) {
            [playBreaks addObject:brk];
        }
    }];
    
    return [NSArray arrayWithArray:playBreaks];
}

- (NSArray *)postRollPlayBreaks
{
    NSMutableArray *playBreaks = [NSMutableArray array];
    
    [self.playBreaks enumerateObjectsUsingBlock:^(DVVideoPlayBreak *brk, NSUInteger idx, BOOL *stop) {
        if (brk.timeOffsetType == DVVideoPlayBreakTimeOffsetEnd) {
            [playBreaks addObject:brk];
        }
    }];
    
    return [NSArray arrayWithArray:playBreaks];
}

@end
