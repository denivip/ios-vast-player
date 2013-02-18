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
    
    DDXMLElement *impressionElement = [[element elementsForName:@"Impression"] objectAtIndex:0];
    NSArray *urls = [impressionElement elementsForName:@"URL"];
    NSString *impressionString = urls && urls.count ? [[urls objectAtIndex:0] stringValue] : [impressionElement stringValue];
    videoAd.impressionURL = [NSURL URLWithString:impressionString];
    
    NSArray *videos = [element elementsForName:@"Video"];
    DDXMLElement *videoElement = nil;
    if (videos && videos.count) {
        videoElement = [videos objectAtIndex:0];
    } else {
        NSArray *creatives = [element elementsForName:@"Creatives"];
        if (creatives && creatives.count) {
            NSArray *creative = [[creatives objectAtIndex:0] elementsForName:@"Creative"];
            if (creative && creative.count) {
                NSArray *linears = [[creative objectAtIndex:0] elementsForName:@"Linear"];
                if (linears && linears.count) {
                    videoElement = [linears objectAtIndex:0];
                }
            }
        }
    }
    
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

- (id)initWithData:(NSData *)data error:(NSError *__autoreleasing *)error_
{
    NSError *error = nil;
    DDXMLDocument *document = [[DDXMLDocument alloc] initWithData:data options:0 error:&error];
    if (! document) {
        if (error_ != nil) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      error, NSUnderlyingErrorKey, nil];
            *error_ = [NSError errorWithDomain:DVVideoAdServingTemplateErrorDomain
                                          code:DVVideoAdServingTemplateXMLParsingErrorCode
                                      userInfo:userInfo];
        }
        return nil;
    }
    
    self = [self initWithXMLDocument:document error:&error];
    if (! self) {
        if (error_ != nil) *error_ = error;
        return nil;
    }
    
    return self;
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
