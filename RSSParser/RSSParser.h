//
//  RSSParser.h
//  RSSParser
//
//  Created by Thibaut LE LEVIER on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSSItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface RSSParser : NSObject <NSXMLParserDelegate>

@property (strong, nonatomic) void (^successBlock)(NSArray<RSSItem *> *feedItems);
@property (strong, nonatomic) void (^failBlock)(NSError *error);

+ (NSSet *)acceptableContentTypes;


+ (void)parseRSSFeedFromXML:(NSXMLParser *)data
                    success:(void (^)(NSArray<RSSItem *> *feedItems))success
                    failure:(void (^)(NSError *error))failure;

@end

NS_ASSUME_NONNULL_END
