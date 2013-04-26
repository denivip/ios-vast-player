//
//  DVVideoAd.h
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DVVideoAd : NSObject

@property (nonatomic, copy) NSString *identifier;
@property BOOL playMediaFile;

- (void)sendAsynchronousRequest:(NSURL*)url context:(NSString*)context;

@end
