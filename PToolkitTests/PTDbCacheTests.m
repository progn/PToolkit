//
//  PTDbCacheTests.m
//
//  Created by Алексей Соловьев on 18.04.12.
//  Copyright (c) 2012 Алексей Соловьев. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

#import "PTCacheTests.h"
#import "PTDbCache.h"

@interface PTDbCacheTests : PTCacheTests

@end

@implementation PTDbCacheTests

- (void)setUp
{
    [super setUp];  
    // Set-up code here.
    
    cache = [[PTDbCache alloc] init];
    [cache cleanUp];
}

- (void)tearDown
{
    // Tear-down code here.
    [cache cleanUp];
    [cache release];
    
    [super tearDown];
}

- (void)testStress
{    
    cache.maxCacheSize = 1024 * 1024 * 1 /*1 Mb*/;
    
    for (int i = 0; i < 500; ++i)
    {
        @autoreleasepool
        {
            NSString *str = [self genRandomStringForMaxSize:100*1024];
            NSData *data_for_cache = [str dataUsingEncoding:NSUnicodeStringEncoding allowLossyConversion:YES];

            NSString *key = [self genRandomStringForMaxSize:500];
            
            NSTimeInterval timestamp = (double)rand() / rand();
            
            STAssertTrue([cache addData:data_for_cache forKey:key withTimestamp:timestamp useCompression:YES], nil);
            
            NSString *key_copy = [[key copy] autorelease];
            
            NSData *data_from_cache = [cache dataForKey:key_copy currentTimestamp:timestamp];
            
            STAssertEqualObjects(data_for_cache, data_from_cache, nil);
        }
    }
    
    STAssertTrue([cache consistencyCheck], nil);
}

@end
