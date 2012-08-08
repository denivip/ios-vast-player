//
//  DVVideoAdServingTemplate.h
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import <Foundation/Foundation.h>


// http://www.iab.net/media/file/VASTv3.0.pdf

extern NSString *const DVVideoAdServingTemplateErrorDomain;

enum {
    
    DVVideoAdServingTemplateXMLParsingErrorCode = 100,
    DVVideoAdServingTemplateSchemaValidationErrorCode = 101,
    DVVideoAdServingTemplateUnexpectedAdType = 200,
    DVVideoAdServingTemplateUndefinedErrorCode = 900,
    
} DVVideoAdServingTemplateErrorCode;

@interface DVVideoAdServingTemplate : NSObject

@property (nonatomic, copy) NSArray *ads;

@end
