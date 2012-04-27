//
//  NSData+Zlib.m
//
//  Created by Алексей Соловьев on 18.01.12.
//  Copyright (c) 2012 Алексей Соловьев. All rights reserved.
//

#import "NSData+Zlib.h"
#import <zlib.h>

@implementation NSData (Zlib)

- (NSData *)zlibDecompress
{
	if ([self length] == 0)
        return self;
    
	unsigned full_length = [self length];
	unsigned half_length = [self length] / 2;
    
	NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
	
	z_stream strm;
	strm.next_in = (Bytef *)[self bytes];
	strm.avail_in = [self length];
	strm.total_out = 0;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
    
	if (inflateInit (&strm) != Z_OK)
        return nil;
    
    BOOL done = NO;
    
	while (!done)
	{
		// Make sure we have enough room and reset the lengths.
		if (strm.total_out >= [decompressed length])
			[decompressed increaseLengthBy: half_length];
        
		strm.next_out = [decompressed mutableBytes] + strm.total_out;
		strm.avail_out = [decompressed length] - strm.total_out;
        
		// Inflate another chunk.
        int status = inflate (&strm, Z_SYNC_FLUSH);
        
		if (status == Z_STREAM_END)
            done = YES;
        else
            if (status != Z_OK)
                break;
	}
	if (inflateEnd (&strm) != Z_OK) return nil;
    
	// Set real length.
	if (done)
	{
		[decompressed setLength: strm.total_out];
        
		return [NSData dataWithData: decompressed];
	}
	
    return nil;
}

- (NSData *)zlibCompress
{
	if ([self length] == 0)
        return self;
	
	z_stream strm;
    
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	strm.total_out = 0;
	strm.next_in = (Bytef *)[self bytes];
	strm.avail_in = [self length];
    
	// Compresssion Levels:
	//   Z_NO_COMPRESSION
	//   Z_BEST_SPEED
	//   Z_BEST_COMPRESSION
	//   Z_DEFAULT_COMPRESSION
    
	if (deflateInit(&strm, Z_BEST_COMPRESSION) != Z_OK)
        return nil;
    
	NSMutableData *compressed = [NSMutableData dataWithLength:16384];  // 16K chuncks for expansion
    
	do
    {
		if (strm.total_out >= [compressed length])
			[compressed increaseLengthBy: 16384];
		
		strm.next_out = [compressed mutableBytes] + strm.total_out;
		strm.avail_out = [compressed length] - strm.total_out;
		
        deflate(&strm, Z_FINISH);  
		
	} while (strm.avail_out == 0);
	
	deflateEnd(&strm);
	
    [compressed setLength: strm.total_out];
	
	return [NSData dataWithData: compressed];
}

@end
