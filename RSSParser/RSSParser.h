//
//  RSSParser.h
//  RSSParser
//
//  Created by Thibaut LE LEVIER on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSSItem.h"

@interface RSSParser : NSObject <NSXMLParserDelegate> {
    RSSItem *currentItem;
    NSMutableArray *items;
    NSMutableString *tmpString;
    void (^successblock)(NSArray *feedItems);
    void (^failblock)(NSError *error);
}

+ (void)parseRSSFeedForURL:(NSString *)url
            withParameters:(id)parameters
                   success:(void (^)(NSArray *feedItems))success
                   failure:(void (^)(NSError *error))failure;

- (void)parseRSSFeedForURL:(NSString *)url
            withParameters:(id)parameters
                   success:(void (^)(NSArray *feedItems))success
                   failure:(void (^)(NSError *error))failure;

@end
