//
//  RSSParser.h
//  RSSParser
//
//  Created by Thibaut LE LEVIER on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSSItem.h"

@interface RSSParser : NSObject <NSXMLParserDelegate>

@property (strong, nonatomic) void (^successBlock)(NSArray *feedItems);
@property (strong, nonatomic) void (^failBlock)(NSError *error);

+ (NSSet *)acceptableContentTypes;


+ (void)parseRSSFeedFromXML:(NSXMLParser *)data
                    success:(void (^)(NSArray *feedItems))success
                    failure:(void (^)(NSError *error))failure;

@end
