//
//  BLDataStructure.m
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

#import "BLDataStructure+Subclass.h"
#import "BLBaseFetchResult.h"
#import <UIKit/UIKit.h>

@implementation BLDataStructure

+ (instancetype) dataStructureWithFetchResult:(BLBaseFetchResult *) fetchResult {
    BLDataStructure * dataStructure = [self new];
    [dataStructure processFetchResult:fetchResult];
    return dataStructure;
}

- (void) processFetchResult:(BLBaseFetchResult *) fetchResult {
    for (int i = 0; i < [[fetchResult sections] count]; i++) {
        [self putSection:[self processItems:[fetchResult sections][i]
                                  inSection:i]
                 section:i];
    }
    if (self.changedBlock) {
        self.changedBlock();
    }
}

- (void) putSection:(NSArray<id<BLDataObject>> *) array section:(NSUInteger) section {
    if (!self.sections) {
        self.sections = [NSMutableArray array];
    }
    while ([self.sections count] <= section) {
        [self.sections addObject:@[]];
    }
    
    self.sections[section] = array;
}

- (NSUInteger) sectionsCount {
    return [self.sections count];
}

- (NSUInteger) itemsCountForSection:(NSUInteger) section {
    return [[self sections][section] count];
}

- (id) metadataForSection:(NSUInteger) section {
    return self.metadata[@(section)]; // For subclassing
}

- (id<BLDataObject>) objectForIndexPath:(NSIndexPath *) indexPath {
    return [self sections][indexPath.section][indexPath.row];
}

- (BOOL) removeItem:(id) item fromSection:(NSUInteger) section {
    NSArray * items = self.sections[section];
    NSMutableArray * mutable = [items mutableCopy];
    NSUInteger oldCount = [mutable count];
    [mutable removeObject:item];
    items = nil;
    self.sections[section] = [self processItems:mutable inSection:section];
    if (self.changedBlock) {
        self.changedBlock();
    }
    BOOL result = oldCount > [items count];
    return result;
}

- (void) insertItem:(id) item toSection:(NSUInteger) section {
    NSAssert(item, @"Cannot insert nil item");
    self.sections[section] = [self processItems:@[item] inSection:section];
    if (self.changedBlock) {
        self.changedBlock();
    }
}

- (BOOL) hasContent {
    NSUInteger sectionsCount = [self sectionsCount];
    if (!sectionsCount) {
        return NO;
    }
    for (int i = 0; i < sectionsCount; i++) {
        if ([self itemsCountForSection:i]) {
            return YES;
        }
    }
    return NO;
}

- (NSUInteger) dataSize {
    NSUInteger dataSize = 0;
    for (NSArray<id<BLDataObject>> * section in self.sections) {
        dataSize += [section count];
    }
    return dataSize;
}

- (NSArray<id<BLDataObject>> *) processItems:(NSArray<id<BLDataObject>> *)items inSection:(NSUInteger) section; {
    if (!items)
        return nil;
    NSArray<id<BLDataObject>> * oldItems = [self.sections count] <= section ? @[] : self.sections[section];
    NSArray<id<BLDataObject>> * array = [NSArray arrayWithArray:oldItems ? [oldItems arrayByAddingObjectsFromArray:items] : items];
    NSArray<id<BLDataObject>> * arryWithoutDuplicates = [[NSSet setWithArray:array] allObjects];
    switch (self.sorting) {
        case BLDataStructureSortingUpdatedAt:
            return [arryWithoutDuplicates sortedArrayUsingComparator:^NSComparisonResult(id<BLDataObject>  _Nonnull obj1, id<BLDataObject> _Nonnull obj2) {
                return [obj2.updatedAt compare:obj1.updatedAt];
            }];
        case BLDataStructureSortingCreatedAt:
            return [arryWithoutDuplicates sortedArrayUsingComparator:^NSComparisonResult(id<BLDataObject>  _Nonnull obj1, id<BLDataObject> _Nonnull obj2) {
                return [obj1.createdAt compare:obj2.createdAt];
            }];
        case BLDataStructureSortingCreatedAtReverse:
            return [arryWithoutDuplicates sortedArrayUsingComparator:^NSComparisonResult(id<BLDataObject>  _Nonnull obj1, id<BLDataObject> _Nonnull obj2) {
                return [obj2.createdAt compare:obj1.createdAt];
            }];
            
        default:
            break;
    }
    return [self orderedArrayFromArray:arryWithoutDuplicates];
}

- (NSArray<id<BLDataObject>> *) orderedArrayFromArray:(NSArray<id<BLDataObject>> *)sourceArray {
    return sourceArray; // For subclassing
}

- (NSIndexPath *) indexPathForObject:(id <BLDataObject>) item {
    __block NSIndexPath * indexPathToReturn = nil;
    [self enumerateObjectsUsingBlock:^(id<BLDataObject> obj, NSIndexPath *indexPath, BOOL *stop) {
        if (obj == item
            || [[obj objectId] isEqualToString:[item objectId]]) {
            indexPathToReturn = indexPath;
            *stop = YES;
        }
    }];
    return indexPathToReturn;
}

#pragma mark -
- (void)enumerateObjectsUsingBlock:(void (^)(id<BLDataObject> obj, NSIndexPath * indexPath, BOOL *stop))block {
    BOOL stop = NO;
    for (int section = 0; section < [self sectionsCount]; section++) {
        for (int row = 0; row < [self itemsCountForSection:section]; row++) {
            NSIndexPath * indexPath = [NSIndexPath indexPathForRow:row inSection:section];
            id <BLDataObject> obj = [self objectForIndexPath:indexPath];
            
            block(obj, indexPath, &stop);
            if (stop)
                break;
        }
    }
}
@end
