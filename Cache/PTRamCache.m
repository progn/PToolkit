//
//  PTRamCache.m
//
//  Created by Алексей Соловьев on 09.04.12.
//  Copyright (c) Алексей Соловьев. All rights reserved.
//

#import "PTRamCache.h"
#import "NSData+Zlib.h"
#import "NSMutableArray+BinarySearch.h"

///

@interface CacheItem : NSObject

@property (nonatomic, retain) NSData *data;
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) BOOL compressed;

@end

@implementation CacheItem
@synthesize data, timestamp, compressed;

- (NSString *)description
{
    return [NSString stringWithFormat:@"data: %@, timestamp: %f, compressed %d", data, timestamp, compressed];
}

@end

///

@interface KeyTimestamp : NSObject

@property (nonatomic, retain) id key;
@property (nonatomic, assign) NSTimeInterval timestamp;

@end

@implementation KeyTimestamp
@synthesize key, timestamp;

- (NSString *)description
{
    return [NSString stringWithFormat:@"key: %@, timestamp: %f", key, timestamp];
}

@end

///////////////////

@interface PTRamCache ()
{
    NSMutableDictionary *_cacheDict;
    NSMutableArray *_oldestItems;
}
@end

@implementation PTRamCache 

@synthesize maxCacheSize = _maxCacheSize;
@synthesize maxAgeForCacheItem = _maxAgeForCacheItem;
@synthesize minCountItems = _minCountItems;
@synthesize currentCacheSize = _currentCacheSize;

static PTRamCache *singleton;

+ (PTRamCache *)sharedCache
{
    @synchronized(self)
    {
        if(singleton == nil)
            singleton = [[self alloc] init];
    }
    
    return singleton;    
}

- (id)init
{
    if ((self = [super init]))
    {
        _maxAgeForCacheItem = 60 /*1 мин*/ * 60 /*1 час */ * 24 /*день*/ * 1;
        _currentCacheSize = 0;
        _minCountItems = 1;
        _maxCacheSize = 1024 * 1024 /*Мб*/ * 1;
                
        _cacheDict = [[NSMutableDictionary alloc] initWithCapacity:100];
        _oldestItems = [[NSMutableArray alloc] initWithCapacity:100];
    }
    
    return self;
}

- (void)dealloc
{
    [_cacheDict release];
    [_oldestItems release];

    [super dealloc];
}

- (BOOL)addData:(NSData *)data
         forKey:(id)key
  withTimestamp:(NSTimeInterval)timestamp
 useCompression:(BOOL)use_compression
{
    @synchronized(self)
    {
        NSData *data_for_cache = use_compression ? [data zlibCompress] : data;
    
        if ([data_for_cache length] / _minCountItems > _maxCacheSize)
            return NO;
        
        CacheItem *item = [[CacheItem alloc] init];
        item.data = data_for_cache;
        item.timestamp = timestamp;
        item.compressed = use_compression;
        
        CacheItem *itemForThisKey = [_cacheDict objectForKey:key];
        if (itemForThisKey != 0)
        {
            _currentCacheSize -= [itemForThisKey.data length];
        }
        
        _currentCacheSize += [data length];
        
        if (_currentCacheSize > _maxCacheSize)
        {
            [self freeUpForSize:[data length]];
        }
        
        [_cacheDict setObject:item forKey:key];
        
        [item release];
        
        [self addToOldestItemsKey:key timestamp:timestamp];
        
        return YES;
    }
}

- (NSData *)dataForKey:(id)key
      currentTimestamp:(NSTimeInterval)cur_timestamp
{
    @synchronized(self)
    {
        CacheItem *item = [_cacheDict objectForKey:key];
    
        if (item == nil)
            return nil;
        
        if ([self ageBetweenTimestamp:cur_timestamp andTimestamp:item.timestamp] > _maxAgeForCacheItem)
        {
            [self removeItemForKey:key];
            
            return nil;
        }
        
        return item.compressed ? [item.data zlibDecompress] : item.data;
    }
}

- (NSTimeInterval)ageBetweenTimestamp:(NSTimeInterval)cur_timestamp andTimestamp:(NSTimeInterval)timestamp
{
    return cur_timestamp - timestamp;
}

- (void)removeItemForKey:(id)key
{
    @synchronized(self)
    {
        CacheItem *item = [_cacheDict objectForKey:key];
        
        if (item)
        {
            _currentCacheSize -= [item.data length];
            
            [_cacheDict removeObjectForKey:key];
        }
    }
}

- (void)freeUpForSize:(NSUInteger)need_free_size
{
    NSUInteger free_up_size = 0;
    
    while ([_oldestItems count] && free_up_size < need_free_size)
    {
        KeyTimestamp *kt = [_oldestItems objectAtIndex:0];
        
        CacheItem *item = [_cacheDict objectForKey:kt.key];
        NSAssert(item != nil, @"");
        
        free_up_size += [item.data length];
        
        [self removeItemForKey:kt.key];
        
        [_oldestItems removeObjectAtIndex:0];
    }
}

- (void)addToOldestItemsKey:(id)key timestamp:(NSTimeInterval)timestamp
{
    KeyTimestamp *kt = [[KeyTimestamp alloc] init];
    kt.key = key;
    kt.timestamp = timestamp;
    
    if ([_oldestItems count] == 0 ||
        timestamp > [_oldestItems.lastObject timestamp])
    {
        [_oldestItems addObject:kt];
    }
    else
    {
        [_oldestItems insertObject:kt intoArraySortedBy:^NSComparisonResult(KeyTimestamp *obj1, KeyTimestamp *obj2) {
            
            if (obj1.timestamp < obj2.timestamp)
                return NSOrderedAscending;
            else
            if (obj1.timestamp > obj2.timestamp)
                return NSOrderedDescending;
            else
                return NSOrderedSame;
        }];
    }
    
    [kt release];
}

- (void)cleanUp
{
    @synchronized(self)
    {
        [_cacheDict removeAllObjects];
        [_oldestItems removeAllObjects];
    
        _currentCacheSize = 0;
    }
}

- (BOOL)consistencyCheck
{
    @synchronized(self)
    {
        if ([_cacheDict count] != [_oldestItems count])
            return NO;
        
        NSTimeInterval prev_timestamp = 0;
        NSUInteger total_cache_size = 0;
        
        for (KeyTimestamp *kt in _oldestItems)
        {
            if (prev_timestamp > kt.timestamp)
                return NO;
            
            CacheItem *item = [_cacheDict objectForKey:kt.key];
            if (item == nil)
                return NO;
            
            total_cache_size += [item.data length];
        }
              
        if (total_cache_size > _maxCacheSize)
            return NO;
        
        return YES;
    }
}

@end
