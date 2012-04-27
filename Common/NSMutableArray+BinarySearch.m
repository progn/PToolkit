//
//  NSMutableArray+BinarySearch.m
//
//  Created by Алексей Соловьев on 26.04.12.
//  Copyright (c) 2012 Алексей Соловьев. All rights reserved.
//

#import "NSMutableArray+BinarySearch.h"

@implementation NSMutableArray (BinarySearch)

- (void)insertObject:(id)object intoArraySortedBy:(NSComparator)comparator 
{
	int numElements = [self count];
	
	if (numElements == 0)
	{
		[self addObject:object];
        
		return;
	}
	
	NSRange searchRange = NSMakeRange(0, numElements);
	
	while(searchRange.length > 0)
	{
		unsigned int checkIndex = searchRange.location + (searchRange.length / 2);
        
		id checkObject = [self objectAtIndex:checkIndex];
        
		NSComparisonResult order = comparator(checkObject, object);		
		switch (order)
		{
			case NSOrderedAscending:
			{
				// end point remains the same, start point moves to next element.
				unsigned int endPoint = searchRange.location + searchRange.length;
				searchRange.location = checkIndex + 1;
				searchRange.length = endPoint - searchRange.location;
				break;
			}
				
			case NSOrderedDescending:
			{
				// start point remains the same, end point moves to previous element
				searchRange.length = (checkIndex - 1) - searchRange.location + 1;
				break;
			}
				
			case NSOrderedSame:
			{
                // found
                searchRange.location = checkIndex + 1;
                searchRange.length = 0;
				break;
			}
				
			default:
			{
				NSAssert(NO, @"wrong compareSelector result");
                
				break;
			}
		}
	}
	
	[self insertObject:object atIndex:searchRange.location];
}

@end
