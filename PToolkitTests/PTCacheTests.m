//
//  PTCacheTests.m
//
//  Created by Алексей Соловьев on 09.04.12.
//  Copyright (c) 2012 Алексей Соловьев. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

#import "PTCacheTests.h"

@implementation PTCacheTests

- (void)testAdd
{
    if (cache == nil)
        return;
    
    char buf[] = "123456789123456789123456789";
    NSData *data_for_cache = [NSData dataWithBytes:buf length:sizeof(buf) / sizeof(buf[0])];

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    BOOL is_added = [cache addData:data_for_cache forKey:@"key 1" withTimestamp:now useCompression:YES];
    STAssertTrue(is_added, nil);
    
    NSData *data_from_cache = [cache dataForKey:@"key 1" currentTimestamp:now];
    STAssertEqualObjects(data_for_cache, data_from_cache, nil);
}

- (void)testRemove
{
    if (cache == nil)
        return;
    
    char buf[] = "123456789123456789123456789";
    NSData *data_for_cache = [NSData dataWithBytes:buf length:sizeof(buf) / sizeof(buf[0])];
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    BOOL is_added = [cache addData:data_for_cache forKey:@"key 1" withTimestamp:now useCompression:YES];
    STAssertTrue(is_added, nil);
    
    [cache removeItemForKey:@"key 1"];
    
    NSData *data_from_cache = [cache dataForKey:@"key 1" currentTimestamp:now];
    STAssertNil(data_from_cache, nil);
}

- (void)testCacheMiss
{
    if (cache == nil)
        return;
    
    char buf[] = "1234567";
    NSData *data_for_cache = [NSData dataWithBytes:buf length:sizeof(buf) / sizeof(buf[0])];
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    BOOL is_added = [cache addData:data_for_cache forKey:@"key 1" withTimestamp:now useCompression:YES];
    STAssertTrue(is_added, nil);
    
    NSData *data_from_cache = [cache dataForKey:@"key not in cache" currentTimestamp:now];
    STAssertNil(data_from_cache, nil);
}

- (void)testItemIsTooOld
{
    if (cache == nil)
        return;
    
    char buf[] = "1234567";
    NSData *data_for_cache = [NSData dataWithBytes:buf length:sizeof(buf) / sizeof(buf[0])];
    
    BOOL is_added = [cache addData:data_for_cache forKey:@"key 1" withTimestamp:120 useCompression:NO];
    STAssertTrue(is_added, nil);
    
    cache.maxAgeForCacheItem = 3;
    
    NSData *data_from_cache = [cache dataForKey:@"key 1" currentTimestamp:123];
    STAssertNotNil(data_from_cache, nil);
    
    cache.maxAgeForCacheItem = 2;
    data_from_cache = [cache dataForKey:@"key 1" currentTimestamp:123];
    STAssertNil(data_from_cache, nil);
}

- (void)testAddToBigItem
{
    if (cache == nil)
        return;
    
    cache.maxCacheSize = 10;
    
    char buf[] = "123456789";
    NSData *data_for_cache = [NSData dataWithBytes:buf length:sizeof(buf) / sizeof(buf[0])];
    
    BOOL is_added;
    is_added = [cache addData:data_for_cache forKey:@"key 1" withTimestamp:1 useCompression:NO];
    STAssertTrue(is_added, nil);
    
    cache.maxCacheSize = 9;
    
    is_added = [cache addData:data_for_cache forKey:@"key 1" withTimestamp:2 useCompression:NO];
    STAssertFalse(is_added, nil);
}

- (void)testCacheOverflow
{
    if (cache == nil)
        return;
    
    cache.maxCacheSize = 20;
    
    char buf[] = "123456789";
    NSData *data_for_cache = [NSData dataWithBytes:buf length:sizeof(buf) / sizeof(buf[0])];
    
    BOOL is_added;

    is_added = [cache addData:data_for_cache forKey:@"key 1" withTimestamp:1 useCompression:NO];
    STAssertTrue(is_added, nil);
    
    is_added = [cache addData:data_for_cache forKey:@"key 2" withTimestamp:2 useCompression:NO];
    STAssertTrue(is_added, nil);

    STAssertNotNil([cache dataForKey:@"key 1" currentTimestamp:0], nil);
    STAssertNotNil([cache dataForKey:@"key 2" currentTimestamp:0], nil);
    
    is_added = [cache addData:data_for_cache forKey:@"key 3" withTimestamp:3 useCompression:NO];
    STAssertTrue(is_added, nil);
    
    STAssertNotNil([cache dataForKey:@"key 3" currentTimestamp:0], nil);
    STAssertNotNil([cache dataForKey:@"key 2" currentTimestamp:0], nil);
    
    STAssertNil([cache dataForKey:@"key 1" currentTimestamp:0], nil);
    
    is_added = [cache addData:data_for_cache forKey:@"key 4" withTimestamp:4 useCompression:NO];
    STAssertTrue(is_added, nil);
    
    STAssertNotNil([cache dataForKey:@"key 4" currentTimestamp:0], nil);
    STAssertNotNil([cache dataForKey:@"key 3" currentTimestamp:0], nil);
    
    STAssertNil([cache dataForKey:@"key 2" currentTimestamp:0], nil);
    
    
    // непоследовательный timestamp
    cache.maxCacheSize = 30;
    
    [cache addData:data_for_cache forKey:@"key 3.5" withTimestamp:3.5 useCompression:NO];

    STAssertNotNil([cache dataForKey:@"key 3.5" currentTimestamp:0], nil);
    STAssertNotNil([cache dataForKey:@"key 4" currentTimestamp:0], nil);
    STAssertNotNil([cache dataForKey:@"key 3" currentTimestamp:0], nil);
    
    [cache addData:data_for_cache forKey:@"key 5" withTimestamp:5 useCompression:NO];
    STAssertNotNil([cache dataForKey:@"key 5" currentTimestamp:0], nil);
    STAssertNotNil([cache dataForKey:@"key 4" currentTimestamp:0], nil);
    STAssertNotNil([cache dataForKey:@"key 3.5" currentTimestamp:0], nil);

    STAssertNil([cache dataForKey:@"key 3" currentTimestamp:0], nil);
    
    [cache addData:data_for_cache forKey:@"key 6" withTimestamp:4 useCompression:NO];
    STAssertNotNil([cache dataForKey:@"key 6" currentTimestamp:0], nil);
    STAssertNotNil([cache dataForKey:@"key 5" currentTimestamp:0], nil);
    STAssertNotNil([cache dataForKey:@"key 4" currentTimestamp:0], nil);
    
    STAssertNil([cache dataForKey:@"key 3.5" currentTimestamp:0], nil);
}

- (NSString *)genRandomStringForMaxSize:(NSUInteger)max_size
{
    NSUInteger str_size = (rand() * rand()) % max_size + 1;
    
    unichar str_buf[str_size];
    
    for (size_t i = 0; i < str_size; i++)
    {
        str_buf[i] = rand();
    }
    str_buf[str_size-1] = 0;
    
    
    return [NSString stringWithCharacters:str_buf length:str_size];    
}

@end
