//
//  DVVideoPlayBreak.h
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CMTime.h>
#import "DVVideoAdServingTemplate.h"


// http://www.iab.net/media/file/VMAPv1.0.pdf

typedef enum {
    
    DVVideoPlayBreakTimeOffsetFromStart = 1,
    DVVideoPlayBreakTimeOffsetPercentage,
    DVVideoPlayBreakTimeOffsetStart,
    DVVideoPlayBreakTimeOffsetEnd,
    DVVideoPlayBreakTimeOffsetPositional,
    
} DVVideoPlayBreakTimeOffsetType;

typedef enum {
    
    DVVideoPlayBreakLinear = 1 << 0,
    DVVideoPlayBreakNonLinear = 1 << 1,
    DVVideoPlayBreakDisplay = 1 << 2,
    
} DVVideoPlayBreakType;


@interface DVVideoPlayBreak : NSObject

@property (nonatomic) DVVideoPlayBreakTimeOffsetType timeOffsetType;
@property (nonatomic) CMTime timeFromStart;
@property (nonatomic) NSUInteger percentage;
@property (nonatomic) NSUInteger position;
@property (nonatomic) CMTime repeatAfterTime;

@property (nonatomic) DVVideoPlayBreakType types;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSURL *adServingTemplateURL;

+ (id)playBreakBeforeStartWithAdTemplateURL:(NSURL *)adTemplateURL;
+ (id)playBreakAfterEndWithAdTemplateURL:(NSURL *)adTemplateURL;
+ (id)playBreakAtTimeFromStart:(CMTime)timeFromStart withAdTemplateURL:(NSURL *)adTemplateURL;

@end
