//
//  DVVideoAdServingTemplate+Parsing.m
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12.
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVVideoAdServingTemplate+Parsing.h"
#import "DVVideoAd.h"
#import "DVInlineVideoAd.h"
#import "DVWrapperVideoAd.h"
#import "DVTimeIntervalFormatter.h"


@implementation DVVideoAdServingTemplate (Parsing)

- (BOOL)populateInlineVideoAd:(DVInlineVideoAd *)videoAd withXMLElement:(DDXMLElement *)element error:(NSError **)error
{
    videoAd.system = [[[element elementsForName:@"AdSystem"] objectAtIndex:0] stringValue];
    videoAd.title = [[[element elementsForName:@"AdSystem"] objectAtIndex:0] stringValue];
    
    NSString *impressionString = [[[[[element elementsForName:@"Impression"] objectAtIndex:0]
                                    elementsForName:@"URL"] objectAtIndex:0] stringValue];
    videoAd.impressionURL = [NSURL URLWithString:impressionString];
    
    DDXMLElement *videoElement = [[element elementsForName:@"Video"] objectAtIndex:0];
    
    NSString *durationString = [[[videoElement elementsForName:@"Duration"] objectAtIndex:0] stringValue];
    DVTimeIntervalFormatter *timeIntervalParser = [[DVTimeIntervalFormatter alloc] init];
    videoAd.duration = [timeIntervalParser timeIntervalWithString:durationString];
    
    NSString *mediaFileString = [[[[[[[videoElement elementsForName:@"MediaFiles"] objectAtIndex:0]
                                     elementsForName:@"MediaFile"] objectAtIndex:0]
                                   elementsForName:@"URL"] objectAtIndex:0] stringValue];
    videoAd.mediaFileURL = [NSURL URLWithString:mediaFileString];
    
    return YES;
}

- (DVVideoAd *)videoAdWithXMLElement:(DDXMLElement *)element error:(NSError **)error
{
    DVVideoAd *videoAd = nil;
    
    DDXMLElement *adContents = (DDXMLElement *)[element childAtIndex:0];
    NSString *adContentsName = [adContents name];
    if ([adContentsName isEqualToString:@"InLine"]) {
        videoAd = [[DVInlineVideoAd alloc] init];
        NSError *inlineVideoAdError = nil;
        if (! [self populateInlineVideoAd:(DVInlineVideoAd *)videoAd
                           withXMLElement:adContents
                                    error:&inlineVideoAdError]) {
            if (error != nil) {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                          inlineVideoAdError, NSUnderlyingErrorKey, nil];
                *error = [NSError errorWithDomain:DVVideoAdServingTemplateErrorDomain
                                             code:DVVideoAdServingTemplateSchemaValidationErrorCode
                                         userInfo:userInfo];
            }
            return nil;
        }
    }
    else if ([adContentsName isEqualToString:@"Wrapper"]) {
        videoAd = [[DVWrapperVideoAd alloc] init];
        NSAssert(NO, @"Wrapper ads not implemented");
        return nil;
    }
    else {
        if (error != nil) *error = [NSError errorWithDomain:DVVideoAdServingTemplateErrorDomain
                                                       code:DVVideoAdServingTemplateUnexpectedAdType
                                                   userInfo:nil];
        return nil;
    }
    
    DDXMLNode *idAttribute = [element attributeForName:@"id"];
    videoAd.identifier = [idAttribute stringValue];
    
    return videoAd;
}

- (id)initWithXMLDocument:(DDXMLDocument *)document error:(NSError *__autoreleasing *)error
{
    if (self = [self init]) {
        
        NSMutableArray *ads = [NSMutableArray array];
        
        DDXMLElement *rootElement = [document rootElement];
        NSArray *adElements = [rootElement elementsForName:@"Ad"];
        for (DDXMLElement *adElement in adElements) {
            NSError *videoAdError = nil;
            DVVideoAd *videoAd = [self videoAdWithXMLElement:adElement error:&videoAdError];
            if (! videoAd) {
                if (error != nil) {
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                              videoAdError, NSUnderlyingErrorKey, nil];
                    *error = [NSError errorWithDomain:DVVideoAdServingTemplateErrorDomain
                                                 code:DVVideoAdServingTemplateSchemaValidationErrorCode
                                             userInfo:userInfo];
                }
                return nil;
            }
            
            [ads addObject:videoAd];
        }
        
        self.ads = [NSArray arrayWithArray:ads];
    }
    return self;
}

@end
