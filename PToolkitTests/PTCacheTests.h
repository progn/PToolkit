//
//  PTCacheTests.h
//
//  Created by Алексей Соловьев on 27.02.12.
//  Copyright (c) 2012 Алексей Соловьев. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

#import "PTCache.h"

@interface PTCacheTests : SenTestCase
{
    id<PTCache> cache;
}

- (NSString *)genRandomStringForMaxSize:(NSUInteger)max_size;

@end
