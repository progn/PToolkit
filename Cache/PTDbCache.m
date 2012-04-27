//
//  PTDbCache.m
//
//  Created by Алексей Соловьев on 18.04.12.
//  Copyright (c) 2012 Алексей Соловьев. All rights reserved.
//

#import "PTDbCache.h"

#import "FMDatabase.h"
#import "NSData+Zlib.h"

@interface PTDbCache ()
{
    FMDatabase *_db;
}

@end

@implementation PTDbCache

@synthesize maxCacheSize = _maxCacheSize;
@synthesize maxAgeForCacheItem = _maxAgeForCacheItem;
@synthesize minCountItems = _minCountItems;

static PTDbCache *singleton;

+ (PTDbCache *)sharedCache
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
    return [self initWithDbName:@"datacache.sqlite"];
}

- (id)initWithDbName:(NSString *)db_name
{
    if ((self = [super init]))
    {
        _maxAgeForCacheItem = 60 /*1 мин*/ * 60 /*1 час */ * 24 /*день*/ * 7;
        _minCountItems = 1;
        _maxCacheSize = 1024 * 1024 /*Мб*/ * 20;
        
        if (![self createDB:db_name])
            return nil;
    }
    
    return self;
}

- (void)dealloc
{
    [_db release];
    
    [super dealloc];
}

- (BOOL)createDB:(NSString *)db_name
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask, YES);
    
    if ([paths count] > 0)
    {
        NSString *cachePath = [paths objectAtIndex:0];
        
        if ( ![[NSFileManager defaultManager] fileExistsAtPath: cachePath]) 
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:NO attributes:nil error:nil];
        }
        
        _db = [[FMDatabase alloc] initWithPath:[cachePath stringByAppendingPathComponent:db_name]];
        
        if (![_db open])
        {
            NSLog(@"PTDbCache init %@", [_db lastErrorMessage]);
            
            return NO;
        }
        
        [self configureDBForFirstUse];
        
        return YES;
    }    
    
    return NO;
}

-(void)configureDBForFirstUse
{
    [_db executeQuery:@"PRAGMA journal_mode = OFF"];
    //[_db executeQuery:@"PRAGMA locking_mode = EXCLUSIVE"];
    [_db executeQuery:@"PRAGMA synchronous = OFF"];
	
    [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS DataCache (keyHash INTEGER PRIMARY KEY, timestamp DOUBLE, data BLOB, compressed BOOLEAN)"];
    [_db executeUpdate:@"CREATE INDEX IF NOT EXISTS timestampIndex ON DataCache(timestamp)"];
    
    [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS CacheInfo (totalDataSize INTEGER)"];
    
    if (![[_db executeQuery:@"SELECT totalDataSize FROM CacheInfo"] next])
        [_db executeUpdate:@"INSERT OR REPLACE INTO CacheInfo (totalDataSize) VALUES (0)"];
}

- (NSTimeInterval)ageBetweenTimestamp:(NSTimeInterval)cur_timestamp andTimestamp:(NSTimeInterval)timestamp
{
    return cur_timestamp - timestamp;
}

- (BOOL)addData:(NSData *)data
         forKey:(id)key
  withTimestamp:(NSTimeInterval)timestamp
 useCompression:(BOOL)use_compression
{
    @synchronized(_db)
    {
        NSData *data_for_cache = use_compression ? [data zlibCompress] : data;
        
        if ([data_for_cache length] / _minCountItems > _maxCacheSize)
            return NO;
        
        self.currentCacheSize += [data_for_cache length] - [self sizeItemDataForKey:key];
        
        if (self.currentCacheSize > _maxCacheSize)
        {
            [self freeUpForSize:[data_for_cache length]];
        }
        
        if (![_db executeUpdate:@"INSERT OR REPLACE INTO DataCache (keyHash, timestamp, data, compressed) VALUES (?, ?, ?, ?)", 
              [NSNumber numberWithUnsignedLongLong:[key hash]],
              [NSNumber numberWithDouble:timestamp],
              data_for_cache,
              [NSNumber numberWithBool:use_compression]])
        {
            NSLog(@"PTDbCache addData error %@", [_db lastErrorMessage]);
            
            return NO;
        }
        
        return YES;
    }
}

- (NSUInteger)sizeItemDataForKey:(id)key
{
	FMResultSet *results = [_db executeQuery:@"SELECT length(data) FROM DataCache WHERE keyHash = ?", [NSNumber numberWithUnsignedLongLong:[key hash]]];
	
	if ([_db hadError])
	{
		NSLog(@"PTDbCache dataForKey error %@", [_db lastErrorMessage]);
        
		return 0;
	}    
     
    NSUInteger size = 0;
    
    if ([results next])
	{ 
        size = [results unsignedLongLongIntForColumnIndex:0];
    }
    
    return size;
}

- (NSData *)dataForKey:(id)key
      currentTimestamp:(NSTimeInterval)cur_timestamp
{
    @synchronized(_db)
    {
        FMResultSet *results = [_db executeQuery:@"SELECT data, timestamp, compressed FROM DataCache WHERE keyHash = ?", [NSNumber numberWithUnsignedLongLong:[key hash]]];
        
        if ([_db hadError])
        {
            NSLog(@"PTDbCache dataForKey error %@", [_db lastErrorMessage]);
            
            return nil;
        }
        
        NSData *data = nil;
        
        if ([results next])
        {
            NSTimeInterval timestamp = [results doubleForColumnIndex:1];
            
            if ([self ageBetweenTimestamp:cur_timestamp andTimestamp:timestamp] <= _maxAgeForCacheItem)
            {
                data = [results dataForColumnIndex:0];
                
                if ([results boolForColumnIndex:2])
                    data = [data zlibDecompress];
            }
            else
            {
                [self removeItemForKey:key];            
            }
        }
        
        [results close];
        
        return data;
    }
}

- (NSUInteger)currentCacheSize
{
	FMResultSet *results = [_db executeQuery:@"SELECT totalDataSize FROM CacheInfo"];
	
	if ([_db hadError])
	{
		NSLog(@"PTDbCache currentCacheSize error %@", [_db lastErrorMessage]);
        
		return 0;
	}
    
    NSUInteger curCacheSize = 0;
    
    if ([results next])
    {
        curCacheSize = [results unsignedLongLongIntForColumnIndex:0];
    }
    
    [results close];
    
    return curCacheSize;
}

- (void)setCurrentCacheSize:(NSUInteger)currentCacheSize
{
	if (![_db executeUpdate:@"UPDATE CacheInfo SET totalDataSize = ? WHERE rowid == 1", 
          [NSNumber numberWithUnsignedLongLong:currentCacheSize]])
    {
		NSLog(@"PTDbCache setCurrentCacheSize error %@", [_db lastErrorMessage]);
    }    
}

- (void)removeItemForKey:(id)key
{
    @synchronized(_db)
    {    
        self.currentCacheSize -= [self sizeItemDataForKey:key];
    
        if (![_db executeUpdate:@"DELETE FROM DataCache WHERE keyHash == ?", 
              [NSNumber numberWithUnsignedLongLong:[key hash]]])
        {
            NSLog(@"PTDbCache removeItemForKey error %@", [_db lastErrorMessage]);
        }
    }
}

- (BOOL)freeUpItemsLessEqualTimestamp:(NSTimeInterval)timestamp
{
    BOOL res = [_db executeUpdate:@"DELETE FROM DataCache WHERE timestamp <= ?", [NSNumber numberWithDouble:timestamp]];

    if ([_db hadError])
    {
        NSLog(@"PTDbCache freeUpItemsLessEqualTimestamp error %@", [_db lastErrorMessage]);
    }
    
    return res;
}

- (void)freeUpForSize:(NSUInteger)need_free_size
{
    FMResultSet *results = [_db executeQuery:@"SELECT length(data), timestamp FROM DataCache ORDER BY timestamp LIMIT 10"];
	
	if ([_db hadError])
	{
		NSLog(@"PTDbCache freeUpForSize error %@", [_db lastErrorMessage]);
        
		return;
	}
    
    NSUInteger free_up_size = 0;
    NSTimeInterval last_timestamp = -1;
    
    while ([results next])
    {
        NSUInteger cur_item_size = [results unsignedLongLongIntForColumnIndex:0];
        last_timestamp = [results doubleForColumnIndex:1];
        
        free_up_size += cur_item_size;
        
        if (free_up_size >= need_free_size)
            break;
    }
    
    NSAssert(last_timestamp != -1, @"freeUpForSize last_timestamp == -1");
    
    [self freeUpItemsLessEqualTimestamp:last_timestamp];
    
    self.currentCacheSize -= free_up_size;
    
    //NSLog(@"cache free up for %d", free_up_size);
    
    if (free_up_size < need_free_size)
        [self freeUpForSize:need_free_size - free_up_size];
}

- (void)cleanUp
{
    @synchronized(_db)
    {    
        if (![_db executeUpdate: @"DELETE FROM DataCache"])
        {
            NSLog(@"PTDbCache cleanUp error %@", [_db lastErrorMessage]);
        }	
        
        self.currentCacheSize = 0;
    }
}

- (BOOL)consistencyCheck
{
    @synchronized(_db)
    {    
        FMResultSet *results = [_db executeQuery:@"SELECT sum(length(data)) FROM DataCache"];
    
        NSUInteger total_size = 0;
        
        if (([results next]))
        {
            total_size = [results unsignedLongLongIntForColumnIndex:0];
        }
        
        if (self.currentCacheSize != total_size)
            return NO;
        
        return YES;
    }
}

@end
