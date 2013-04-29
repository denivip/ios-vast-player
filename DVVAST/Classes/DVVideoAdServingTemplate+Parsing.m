//
//  DVVideoAdServingTemplate+Parsing.m
//  DVVASTSample
//
//  Created by Nikolay Morev on 8/7/12. Augmented by Manuel "StuFF mc" Carrasco Molina in 2013 — https://github.com/stuffmc/ios-vast-player/tree/dev
//  Copyright (c) 2012 DENIVIP Media. All rights reserved.
//

#import "DVVideoAdServingTemplate+Parsing.h"
#import "DVVideoAd.h"
#import "DVInlineVideoAd.h"
#import "DVWrapperVideoAd.h"
#import "DVTimeIntervalFormatter.h"
#import "NSString+DDXML.h"

@implementation DDXMLElement (VAST)

- (BOOL)isEmpty
{
    return !self.stringValue || [[self.stringValue stringByTrimming] isEqualToString:@""];
}

@end


@implementation DVVideoAdServingTemplate (Parsing)

- (BOOL)populateInlineVideoAd:(DVInlineVideoAd *)videoAd withXMLElement:(DDXMLElement *)element error:(NSError **)error
{
    videoAd.playMediaFile = YES;
    videoAd.system = [[[element elementsForName:@"AdSystem"] objectAtIndex:0] stringValue];
    videoAd.title = [[[element elementsForName:@"AdSystem"] objectAtIndex:0] stringValue];
    
    // VAST 2 — Multiple <Impression> elements
    NSArray *impressionElements = [element elementsForName:@"Impression"];
    if (impressionElements.count == 1) {
        // VAST 1 — Multiple <URL> elements in a single <Impression>
        DDXMLElement *impressionElement = [impressionElements objectAtIndex:0];
        impressionElements = [impressionElement elementsForName:@"URL"];
    }
    NSMutableArray *impressionURLs = [NSMutableArray array];
    [impressionElements enumerateObjectsUsingBlock:^(DDXMLElement *impressionElement, NSUInteger idx, BOOL *stop) {
        [self addURLElement:impressionElement toArray:impressionURLs];
    }];
    VLogV(impressionURLs);
    videoAd.impressionURLs = impressionURLs;
    if (impressionURLs.count) {
        // For compatibility sake (code using ios-vast-player's "single" impressionURL)
        videoAd.impressionURL =  impressionURLs[0];
    }
    VLogV(videoAd.impressionURLs);
    
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
    
    NSArray *durations = [videoElement elementsForName:@"Duration"];
    if (durations && durations.count) {
        NSString *durationString = [[durations objectAtIndex:0] stringValue];
        DVTimeIntervalFormatter *timeIntervalParser = [[DVTimeIntervalFormatter alloc] init];
        videoAd.duration = [timeIntervalParser timeIntervalWithString:durationString];
    }
    
    NSArray *videoClicksElements = [videoElement elementsForName:@"VideoClicks"];
    if ([videoClicksElements count] > 0) {
        DDXMLElement *videoClicks = [videoClicksElements objectAtIndex:0];
        NSArray *clickThroughs = [videoClicks elementsForName:@"ClickThrough"];
        if (clickThroughs && clickThroughs.count) {
            DDXMLElement *clickThrough = [clickThroughs objectAtIndex:0];
            videoAd.clickThroughURL = [NSURL URLWithString:clickThrough.stringValue];
        }
        
        // VAST 2 — Multiple <ClickTracking> elements
        NSArray *clickTrackingElements = [videoClicks elementsForName:@"ClickTracking"];
        if (clickTrackingElements.count == 1) {
            // VAST 1 — Multiple <URL> elements in a single <ClickTracking>
            DDXMLElement *clickTrackingElement = [clickTrackingElements objectAtIndex:0];
            clickTrackingElements = [clickTrackingElement elementsForName:@"URL"];
        }

        NSMutableArray *clickTrackingURLs = [NSMutableArray array];
        [clickTrackingElements enumerateObjectsUsingBlock:^(DDXMLElement *clickTrackingElement, NSUInteger idx, BOOL *stop) {
            [self addURLElement:clickTrackingElement toArray:clickTrackingURLs];
        }];
        VLogV(clickTrackingURLs);
        videoAd.clickTrackingURLs = clickTrackingURLs;
        if (clickTrackingURLs.count) {
            // For compatibility sake (code using ios-vast-player's "single" clickTrackingURL)
            videoAd.clickTrackingURL =  clickTrackingURLs[0];
        }
        VLogV(videoAd.clickTrackingURLs);
    }
    
#define TRACKING_EVENTS @"TrackingEvents"
    NSArray *trackingEvents = [videoElement elementsForName:TRACKING_EVENTS]; // VAST 2 has that tag in the Video tag
    if (!trackingEvents || !trackingEvents.count) { // VAST 1 has it at the same level than the video tag.
        trackingEvents = [element elementsForName:TRACKING_EVENTS];
    }
    if (trackingEvents.count) {
        DDXMLElement *trackingEvent = [trackingEvents objectAtIndex:0];
        NSArray *trackingElements = [trackingEvent elementsForName:@"Tracking"];
//        NSMutableDictionary *dictionary = videoAd.trackingEvents ? [videoAd.trackingEvents mutableCopy] : [NSMutableDictionary dictionary];
        NSMutableDictionary *dictionary = videoAd.trackingEvents ? [videoAd.trackingEvents mutableCopy] : [NSMutableDictionary dictionary];
        [trackingElements enumerateObjectsUsingBlock:^(DDXMLElement *trackingElement, NSUInteger idx, BOOL *stop) {
            NSString *event = [trackingElement attributeForName:@"event"].stringValue;
            NSArray *urls = [trackingElement elementsForName:@"URL"];
            NSMutableDictionary *innerDictionary = dictionary[event] ? [dictionary[event] mutableCopy] : [NSMutableDictionary dictionary];
            if (!urls.count) {
                if (!trackingElement.isEmpty) {
                    VLogV(trackingElement.stringValue);
                    NSString *key = [NSString stringWithFormat:@"url-%lu", (unsigned long)innerDictionary.allKeys.count];
                    VLogV(key);
                    innerDictionary[key] = [NSURL URLWithString:trackingElement.stringValue];
                }
            } else {
                [urls enumerateObjectsUsingBlock:^(DDXMLElement *url, NSUInteger idx, BOOL *stop) {
                    if (!url.isEmpty) {
                        NSString *attribute = [url attributeForName:@"id"].stringValue;
                        innerDictionary[attribute] = [NSURL URLWithString:url.stringValue];
                    }
                }];
            }
            dictionary[event] = innerDictionary;
        }];
        videoAd.trackingEvents = dictionary;
    }
    VLogV(videoAd.trackingEvents);
    
    NSArray *mediaFilesArray = [videoElement elementsForName:@"MediaFiles"];
    if (mediaFilesArray && mediaFilesArray.count) {
        DDXMLElement *mediaFiles = [mediaFilesArray objectAtIndex:0];
        DDXMLElement *mediaFile = nil;
        for (DDXMLElement *currentMF in [mediaFiles elementsForName:@"MediaFile"]) {
            NSString *type = [[currentMF attributeForName:@"type"] stringValue];
            if ([type isEqualToString:@"mobile/m3u8"] || [type isEqualToString:@"video/mp4"] || [type isEqualToString:@"video/x-mp4"]) {
                mediaFile = currentMF;
                break;
            }
        }
        NSArray *urls = [mediaFile elementsForName:@"URL"];
        DDXMLDocument *url = urls && urls.count ? [urls objectAtIndex:0] : mediaFile;
        videoAd.mediaFileURL = [NSURL URLWithString:[url stringValue]];
    }

    // Looking for the <Fallback> tag that will tell me not to play this media.
    NSArray *extensions = [element elementsForName:@"Extensions"];
    if (extensions && extensions.count) {
        NSArray *extension = [[extensions objectAtIndex:0] elementsForName:@"Extension"];
        if (extension && extension.count) {
            NSArray *fallback = [[extension objectAtIndex:0] elementsForName:@"Fallback"];
            videoAd.playMediaFile = !fallback || !fallback.count;
        }
    }

    return YES;
}

- (void)addURLElement:(DDXMLElement*)element toArray:(NSMutableArray*)array
{
    if (!element.isEmpty) {
        NSURL *url = [NSURL URLWithString:element.stringValue];
        VLogV(url);
        if (url) {
            [array addObject:url];
        }
    }
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
        
        NSArray *vastTagArray = [adContents elementsForName:@"VASTAdTagURL"];
        DDXMLElement *vastTagURI = nil;
        if (vastTagArray && vastTagArray.count) {
            // VAST 1.x
            vastTagURI = [[[vastTagArray objectAtIndex:0] elementsForName:@"URL"] objectAtIndex:0];
        } else {
            // VAST 2.0
            vastTagArray = [adContents elementsForName:@"VASTAdTagURI"];
            vastTagURI = [vastTagArray objectAtIndex:0];
        }
        // TODO: Parse this (inline) + self (wrapper!)
        ((DVWrapperVideoAd*)videoAd).URL = [NSURL URLWithString:[vastTagURI stringValue]];
        VLogV(((DVWrapperVideoAd*)videoAd).URL);
        
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
        videoAd.playMediaFile = NO;
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
    self.document = [[DDXMLDocument alloc] initWithData:data options:0 error:&error];
    if (! self.document) {
        if (error_ != nil) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      error, NSUnderlyingErrorKey, nil];
            *error_ = [NSError errorWithDomain:DVVideoAdServingTemplateErrorDomain
                                          code:DVVideoAdServingTemplateXMLParsingErrorCode
                                      userInfo:userInfo];
        }
        return nil;
    }
    
    self = [self initWithXMLDocument:self.document error:&error];
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
        VLogV(adElements);
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
