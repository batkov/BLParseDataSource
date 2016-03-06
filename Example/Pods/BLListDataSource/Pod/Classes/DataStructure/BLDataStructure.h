//
//  BLDataStructure.h
//  https://github.com/batkov/BLDataSource
//
// Copyright (c) 2016 Hariton Batkov
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import <Foundation/Foundation.h>
#import "BLDataObject.h"

@class BLBaseFetchResult;

@interface BLDataStructure : NSObject

+ (instancetype) dataStructureWithFetchResult:(BLBaseFetchResult *) fetchResult;

- (void) processFetchResult:(BLBaseFetchResult *) fetchResult;

@property (nonatomic, copy) dispatch_block_t changedBlock;
#pragma mark - Table View conviniency methods
- (NSUInteger) sectionsCount;
- (NSUInteger) itemsCountForSection:(NSUInteger) section;
- (id) metadataForSection:(NSUInteger) section;
- (id<BLDataObject>) objectForIndexPath:(NSIndexPath *) indexPath;

#pragma mark - Data Source Methods
- (NSArray<id<BLDataObject>> *) processItems:(NSArray<id<BLDataObject>> *)items inSection:(NSUInteger) section;
- (BOOL) hasContent;
- (BOOL) removeItem:(id) item fromSection:(NSUInteger) section;
- (void) insertItem:(id) item toSection:(NSUInteger) section;
- (NSUInteger) dataSize;

- (NSIndexPath *) indexPathForObject:(id <BLDataObject>) item;

#pragma mark -
- (void)enumerateObjectsUsingBlock:(void (^)(id<BLDataObject> obj, NSIndexPath * indexPath, BOOL *stop))block;

@end
