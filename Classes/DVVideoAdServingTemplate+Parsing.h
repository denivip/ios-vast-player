//
//  DVVideoAdServingTemplate+Parsing.h
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVVideoAdServingTemplate.h"
#import "DDXML.h"


@interface DVVideoAdServingTemplate (Parsing)

- (id)initWithData:(NSData *)data error:(NSError **)error;
- (id)initWithXMLDocument:(DDXMLDocument *)document error:(NSError **)error;

@end
