//
//  RSSParser.m
//  RSSParser
//
//  Created by Thibaut LE LEVIER on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSSParser.h"
#import "NSDate+InternetDateTime.h"

@interface RSSParser()

// These properties are temporary place holders for content being parsed
@property (strong, nonatomic) RSSItem *currentParsedItem;
@property (strong, nonatomic) NSMutableString *currentParsedText;

// Contains the result of the feed being parsed
@property (strong, nonatomic) NSMutableArray<RSSItem *> *feedItems;

- (void)parseRSSFeedFromXML:(NSXMLParser *)data
                    success:(void (^)(NSArray *feedItems))success
                    failure:(void (^)(NSError *error))failure;

@end

@implementation RSSParser

+ (NSSet *)acceptableContentTypes {
    return [NSSet setWithObjects:@"application/xml", @"text/xml",@"application/rss+xml", @"application/atom+xml", nil];
}

#pragma mark lifecycle
- (id)init {
    self = [super init];
    if (self) {
        self.feedItems = [NSMutableArray new];
    }
    return self;
}

#pragma mark -

#pragma mark parser

+ (void)parseRSSFeedFromXML:(NSXMLParser *)data
                    success:(void (^)(NSArray *feedItems))success
                    failure:(void (^)(NSError *error))failure
{
    RSSParser *parser = [RSSParser new];
    [parser parseRSSFeedFromXML:data success:success failure:failure];
}


- (void)parseRSSFeedFromXML:(NSXMLParser *)data
                   success:(void (^)(NSArray *feedItems))success
                   failure:(void (^)(NSError *error))failure
{
    self.successBlock = [success copy];
    self.failBlock = [failure copy];

    data.delegate = self;
    [data parse];
}

#pragma mark NSXMLParser delegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {

    // If we have found an <item> or <entry> tag, create a new RSSItem so that we can start saving data into it
    if ([elementName isEqualToString:@"item"] || [elementName isEqualToString:@"entry"]) {
        self.currentParsedItem = [RSSItem new];
    }

    // This is a new element, so we need to start saving parsed text for this element
    self.currentParsedText = [NSMutableString new];

    // Parse the attributes within a tag (e.g. <tag attribute="value"></tag>)
    if (self.currentParsedItem != nil) {
        if (attributeDict != nil && attributeDict.count > 0) {
            if ([elementName isEqualToString:@"media:thumbnail"]) {
                [self.currentParsedItem setMediaThumbnail:[self getNSURLFromString:[attributeDict objectForKey:@"url"]]];
            } else if ([elementName isEqualToString:@"media:content"]) {
                [self initMedia:attributeDict forItem:self.currentParsedItem];
            } else if ([elementName isEqualToString:@"enclosure"] ) {
                [self initMedia:attributeDict forItem:self.currentParsedItem];
            } else if (([elementName isEqualToString:@"media:player"])) {
                if (self.currentParsedItem.mediaType != Audio || self.currentParsedItem.mediaType != Video) {
                    [self.currentParsedItem setMediaURL:[self getNSURLFromString:[attributeDict objectForKey:@"url"]]];
                }
            } else if (([elementName isEqualToString:@"link"])) {
                [self.currentParsedItem setLink:[self getNSURLFromString:[attributeDict objectForKey:@"href"]]];
            } else if (([elementName isEqualToString:@"itunes:image"])) {
                [self.currentParsedItem setItunesImageURL:[self getNSURLFromString:[attributeDict objectForKey:@"href"]]];
            }
        }
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {

    // Parse the value between an element tag (e.g. <tag>some value here</tag>)
    if (self.currentParsedItem && self.currentParsedText) {
        if ([elementName isEqualToString:@"title"]) {
            [self.currentParsedItem setTitle:self.currentParsedText];
        } else if ([elementName isEqualToString:@"description"] || [elementName isEqualToString:@"media:description"]) {
            if (![self.currentParsedItem itemDescription] || ![[self.currentParsedItem itemDescription] length]) {
                [self.currentParsedItem setItemDescription:self.currentParsedText];
            }
        } else if ([elementName isEqualToString:@"content:encoded"] || [elementName isEqualToString:@"content"]) {
            [self.currentParsedItem setContent:self.currentParsedText];
        } else if ([elementName isEqualToString:@"link"]) {
            if (![self.currentParsedItem link] || ![[[self.currentParsedItem link] absoluteString] length]) {
                [self.currentParsedItem setLink:[NSURL URLWithString:self.currentParsedText]];
            }
        } else if ([elementName isEqualToString:@"comments"]) {
            [self.currentParsedItem setCommentsLink:[NSURL URLWithString:self.currentParsedText]];
        } else if ([elementName isEqualToString:@"wfw:commentRss"]) {
            [self.currentParsedItem setCommentsFeed:[NSURL URLWithString:self.currentParsedText]];
        } else if ([elementName isEqualToString:@"slash:comments"]) {
            [self.currentParsedItem setCommentsCount:[NSNumber numberWithInt:[self.currentParsedText intValue]]];
        } else if ([elementName isEqualToString:@"pubDate"] || [elementName isEqualToString:@"published"]) {
            if (![self.currentParsedItem pubDate]) {
                [self.currentParsedItem setPubDate:[self getDateFromString:self.currentParsedText]];
            }
        } else if ([elementName isEqualToString:@"dc:creator"]) {
            [self.currentParsedItem setAuthor:self.currentParsedText];
        } else if ([elementName isEqualToString:@"guid"]) {
            [self.currentParsedItem setGuid:self.currentParsedText];
        } else if ([elementName isEqualToString:@"media:title"]) {
            [self.currentParsedItem setMediaTitle:self.currentParsedText];
        }
    }

    if ([elementName isEqualToString:@"item"] || [elementName isEqualToString:@"entry"]) {
        [self.feedItems addObject:self.currentParsedItem];
        self.currentParsedItem = nil;
    }

    // If we have reached the ending tag for the feed, return the result
    if ([elementName isEqualToString:@"rss"] || [elementName isEqualToString:@"feed"]) {
        self.successBlock(self.feedItems);
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [self.currentParsedText appendString:string];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    self.failBlock(parseError);
    [parser abortParsing];
}

-(ContentType)determineMediaTypeFromAttributes:(NSDictionary *)dict
{
    if ([self dictionary:dict containsMedia:@"video"]) {
        return Video;
    }
    else if ([self dictionary:dict containsMedia:@"audio"]) {
        return Audio;
    }
    else if ([self dictionary:dict containsMedia:@"image"]) {
        return Image;
    }
    else if ([self dictionary:dict containsMedia:@"flash"]) {
        return Flash;
    }

    return Unknown;
}

-(BOOL)dictionary:(NSDictionary *)dict containsMedia:(NSString *)string
{
    for (id key in @[@"mime_type", @"type", @"medium"]) {
        if ([dict objectForKey:key]) {
            if ([[dict objectForKey:key] rangeOfString:string options:NSCaseInsensitiveSearch].location != NSNotFound) {
                return YES;
            }
        }
    }

    return NO;
}

-(void)initMedia:(NSDictionary *)dict forItem:(RSSItem *)item {
    ContentType type = [self determineMediaTypeFromAttributes:dict];
    if (type >= item.mediaType) {
        [item setMediaType:type];
        [item setMediaURL:[self getNSURLFromString:[dict objectForKey:@"url"]]];
    }

    if (type == Image && ![item mediaThumbnail]) {
        [item setMediaThumbnail:[self getNSURLFromString:[dict objectForKey:@"url"]]];
    }
}

-(NSURL *)getNSURLFromString:(NSString *)string {
    if (string) {
        return [NSURL URLWithString:string];
    }
    else {
        return nil;
    }
}

-(NSDate *)getDateFromString:(NSString *)string {
    NSDate *date = nil;
    date = [NSDate dateFromInternetDateTimeString:string formatHint:DateFormatHintNone];
    return date;
}

#pragma mark -

@end
