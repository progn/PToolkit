//
//  PTDbCache.h
//
//  Created by Алексей Соловьев on 18.04.12.
//  Copyright (c) 2012 Алексей Соловьев. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTCache.h"

@interface PTDbCache : NSObject <PTCache>

+ (PTDbCache *)sharedCache;

- (id)initWithDbName:(NSString *)db_name;

- (BOOL)addData:(NSData *)data
         forKey:(id)key
  withTimestamp:(NSTimeInterval)timestamp
 useCompression:(BOOL)use_compression;

- (NSData *)dataForKey:(id)key
      currentTimestamp:(NSTimeInterval)cur_timestamp;

- (void)removeItemForKey:(id)key;

- (void)cleanUp;

- (BOOL)consistencyCheck;

@property (nonatomic, assign)   NSUInteger      maxCacheSize;
@property (nonatomic, assign)   NSTimeInterval  maxAgeForCacheItem;
@property (nonatomic, assign)   NSUInteger      minCountItems;
@property (nonatomic, readonly) NSUInteger      currentCacheSize;

@end
