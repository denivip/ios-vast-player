//
//  DVVideoAdServingTemplate+Parsing.h
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12. Augmented by Manuel "StuFF mc" Carrasco Molina in 2013 — https://github.com/stuffmc/ios-vast-player/tree/dev
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVVideoAdServingTemplate.h"
#import <KissXML/DDXML.h>
#import "DVInlineVideoAd.h"

@interface DDXMLElement (VAST)

@property (nonatomic, readonly) BOOL isEmpty;

@end

@interface DVVideoAdServingTemplate (Parsing)

- (id)initWithData:(NSData *)data error:(NSError **)error;
- (id)initWithXMLDocument:(DDXMLDocument *)document error:(NSError **)error;
- (BOOL)populateInlineVideoAd:(DVInlineVideoAd *)videoAd withXMLElement:(DDXMLElement *)element error:(NSError **)error;

@end
