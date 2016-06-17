//
//  RSSParser.m
//  RSSParser
//
//  Created by Thibaut LE LEVIER on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSSParser.h"
#import "AFHTTPRequestOperationManager.h"
#import "AFURLResponseSerialization.h"
#import "NSDate+InternetDateTime.h"

@interface RSSParser()

@end

@implementation RSSParser

#pragma mark lifecycle
- (id)init {
    self = [super init];
    if (self) {
        items = [NSMutableArray new];
    }
    return self;
}

#pragma mark -

#pragma mark parser

+ (void)parseRSSFeedForURL:(NSString *)url
            withParameters:(id)parameters
                   success:(void (^)(NSArray *feedItems))success
                   failure:(void (^)(NSError *error))failure
{
    RSSParser *parser = [[RSSParser alloc] init];
    [parser parseRSSFeedForURL:url withParameters:parameters success:success failure:failure];
}


- (void)parseRSSFeedForURL:(NSString *)url
            withParameters:(id)parameters
                   success:(void (^)(NSArray *feedItems))success
                   failure:(void (^)(NSError *error))failure
{
    successblock = [success copy];
    failblock = [failure copy];

    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/xml", @"text/xml",@"application/rss+xml", @"application/atom+xml", nil];

    [manager GET:url parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [(NSXMLParser *)responseObject setDelegate:self];
        [(NSXMLParser *)responseObject parse];
    } failure:^(AFHTTPRequestOperation * _Nonnull operation, NSError * _Nonnull error) {
        failblock(error);
    }];
}

#pragma mark -
#pragma mark NSXMLParser delegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
    
    if ([elementName isEqualToString:@"item"] || [elementName isEqualToString:@"entry"]) {
        currentItem = [[RSSItem alloc] init];
    }
    
    tmpString = [[NSMutableString alloc] init];

    if (currentItem != nil) {
        if (attributeDict != nil && attributeDict.count > 0) {
            if ([elementName isEqualToString:@"media:thumbnail"]) {
                [currentItem setMediaThumbnail:[self getNSURLFromString:[attributeDict objectForKey:@"url"]]];
            } else if ([elementName isEqualToString:@"media:content"]) {
                [self initMedia:attributeDict];
            } else if ([elementName isEqualToString:@"enclosure"] ) {
                [self initMedia:attributeDict];
            } else if (([elementName isEqualToString:@"media:player"])) {
                if (currentItem.mediaType != Audio || currentItem.mediaType != Video) {
                    [currentItem setMediaURL:[self getNSURLFromString:[attributeDict objectForKey:@"url"]]];
                }
            } else if (([elementName isEqualToString:@"link"])) {
                [currentItem setLink:[self getNSURLFromString:[attributeDict objectForKey:@"href"]]];
            }
        }
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName isEqualToString:@"item"] || [elementName isEqualToString:@"entry"]) {
        [items addObject:currentItem];
    }
    if (currentItem != nil && tmpString != nil) {
        
        if ([elementName isEqualToString:@"title"]) {
            [currentItem setTitle:tmpString];
        } else if ([elementName isEqualToString:@"description"] || [elementName isEqualToString:@"media:description"]) {
            if (![currentItem itemDescription] || ![[currentItem itemDescription] length]) {
                [currentItem setItemDescription:tmpString];
            }
        } else if ([elementName isEqualToString:@"content:encoded"] || [elementName isEqualToString:@"content"]) {
            [currentItem setContent:tmpString];
        } else if ([elementName isEqualToString:@"link"]) {
            if (![currentItem link] || ![[[currentItem link] absoluteString] length]) {
                [currentItem setLink:[NSURL URLWithString:tmpString]];
            }
        } else if ([elementName isEqualToString:@"comments"]) {
            [currentItem setCommentsLink:[NSURL URLWithString:tmpString]];
        } else if ([elementName isEqualToString:@"wfw:commentRss"]) {
            [currentItem setCommentsFeed:[NSURL URLWithString:tmpString]];
        } else if ([elementName isEqualToString:@"slash:comments"]) {
            [currentItem setCommentsCount:[NSNumber numberWithInt:[tmpString intValue]]];
        } else if ([elementName isEqualToString:@"pubDate"] || [elementName isEqualToString:@"published"]) {
            if (![currentItem pubDate]) {
                [currentItem setPubDate:[self getDateFromString:tmpString]];
            }
        } else if ([elementName isEqualToString:@"dc:creator"]) {
            [currentItem setAuthor:tmpString];
        } else if ([elementName isEqualToString:@"guid"]) {
            [currentItem setGuid:tmpString];
        } else if ([elementName isEqualToString:@"media:title"]) {
            [currentItem setMediaTitle:tmpString];
        }
    }
    
    if ([elementName isEqualToString:@"rss"] || [elementName isEqualToString:@"feed"]) {
        successblock(items);
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [tmpString appendString:string];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    failblock(parseError);
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

-(void)initMedia:(NSDictionary *)dict {
    ContentType type = [self determineMediaTypeFromAttributes:dict];
    if (type >= currentItem.mediaType) {
        [currentItem setMediaType:type];
        [currentItem setMediaURL:[self getNSURLFromString:[dict objectForKey:@"url"]]];
    }

    if (type == Image && ![currentItem mediaThumbnail]) {
        [currentItem setMediaThumbnail:[self getNSURLFromString:[dict objectForKey:@"url"]]];
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
