//
//  RSSParser.m
//  RSSParser
//
//  Created by Thibaut LE LEVIER on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSSParser.h"

#import "AFHTTPRequestOperation.h"
#import "AFURLResponseSerialization.h"

@interface RSSParser()

@property (nonatomic) NSDateFormatter *formatter;
@property (nonatomic) NSDateFormatter *ISO8601formatter;
@property (nonatomic) NSDateFormatter *formatterWithTimeZoneAbbreviation;

@end

@implementation RSSParser

#pragma mark lifecycle
- (id)init {
    self = [super init];
    if (self) {
        items = [NSMutableArray new];

        NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_EN"];

        _formatter = [NSDateFormatter new];
        [_formatter setLocale:locale];
        [_formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];

        _formatterWithTimeZoneAbbreviation = [NSDateFormatter new];
        [_formatterWithTimeZoneAbbreviation setLocale:locale];
        [_formatterWithTimeZoneAbbreviation setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss V"];

        _ISO8601formatter = [NSDateFormatter new];
        [_ISO8601formatter setLocale:locale];
        [_ISO8601formatter setDateFormat: @"yyyy-MM-dd'T'HH:mm:ssZ"];
    }
    return self;
}

#pragma mark -

#pragma mark parser

+ (void)parseRSSFeedForRequest:(NSURLRequest *)urlRequest
                       success:(void (^)(NSArray *feedItems))success
                       failure:(void (^)(NSError *error))failure
{
    RSSParser *parser = [[RSSParser alloc] init];
    [parser parseRSSFeedForRequest:urlRequest success:success failure:failure];
}


- (void)parseRSSFeedForRequest:(NSURLRequest *)urlRequest
                       success:(void (^)(NSArray *feedItems))success
                       failure:(void (^)(NSError *error))failure
{
    
    block = [success copy];
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:urlRequest];
    
    operation.responseSerializer = [[AFXMLParserResponseSerializer alloc] init];
    operation.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/xml", @"text/xml",@"application/rss+xml", @"application/atom+xml", nil];
    
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        failblock = [failure copy];
        [(NSXMLParser *)responseObject setDelegate:self];
        [(NSXMLParser *)responseObject parse];
    }
                                     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                         failure(error);
                                     }];
    
    [operation start];
    
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
        } else if ([elementName isEqualToString:@"description"]) {
            [currentItem setItemDescription:tmpString];
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
        block(items);
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
    if (string) {
        date = [_formatter dateFromString:string];
        if (!date) {
            date = [_ISO8601formatter dateFromString:string];
        }
        if (!date) {
            NSRange range = [string rangeOfString:@" " options:NSBackwardsSearch];
            NSString *threeLetterZone = [string substringFromIndex:range.location+1];
            NSTimeZone *timeZone = [NSTimeZone timeZoneWithAbbreviation:threeLetterZone];
            if (timeZone)
            {
                NSString *gmtTime = [string stringByReplacingOccurrencesOfString:threeLetterZone withString:@"GMT"];
                date = [[_formatterWithTimeZoneAbbreviation dateFromString:gmtTime] dateByAddingTimeInterval:-timeZone.secondsFromGMT];
            }
        }
    }
    return date;
}

#pragma mark -

@end
