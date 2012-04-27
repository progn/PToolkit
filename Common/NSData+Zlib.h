//
//  NSData+Zlib.h
//
//  Created by Алексей Соловьев on 18.01.12.
//  Copyright (c) 2012 Алексей Соловьев. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Zlib)

- (NSData *) zlibDecompress; 
- (NSData *) zlibCompress;

@end
