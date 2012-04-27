//
//  NSMutableArray+BinarySearch.h
//
//  Created by Алексей Соловьев on 26.04.12.
//  Copyright (c) 2012 Алексей Соловьев. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableArray (BinarySearch)

- (void)insertObject:(id)object intoArraySortedBy:(NSComparator)comparator;

@end
