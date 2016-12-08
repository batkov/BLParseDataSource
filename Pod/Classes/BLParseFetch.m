//
//  FSParseFetch.m
//  https://github.com/batkov/BLParseFetch
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

#import "BLParseFetch.h"

@implementation BLParseFetch

- (instancetype) init {
    if (self = [super init]) {
        self.pinName = PFObjectDefaultPin;
        self.offlineFetchAvailable = [Parse isLocalDatastoreEnabled];
        self.offlineStoreAvailable = [Parse isLocalDatastoreEnabled];
    }
    return self;
}

- (void) fetchOnline:(BLPaging *__nullable) paging callback:(BLIdResultBlock __nonnull)callback {
    if (self.cloudFuncName) {
        [self fetchFromCloudOnline:paging callback:callback];
    } else {
        [self fetchFromQueryOnline:paging callback:callback];
    }
}

- (void) fetchFromCloudOnline:(BLPaging *__nullable) paging
                     callback:(BLIdResultBlock __nonnull)block {
    NSDictionary * params = self.cloudParamsBlock ? self.cloudParamsBlock(paging) : @{};
    [PFCloud callFunctionInBackground:self.cloudFuncName
                       withParameters:params
                                block:^(id  _Nullable object, NSError * _Nullable error) {
                                    block(object, error);
                                }];
}

- (void) fetchFromQueryOnline:(BLPaging *__nullable) paging
                     callback:(BLIdResultBlock __nonnull)block {
    NSAssert(self.queryBlock, @"Should be set either queryBlock or cloudFuncName");
    PFQuery * query = self.queryBlock();
    if (paging) {
        query.skip = paging.skip;
        query.limit = paging.limit;
    }
    [query findObjectsInBackgroundWithBlock:block];
}


#pragma mark - Offline
- (void) fetchOffline:(BLIdResultBlock __nonnull)block {
    if (!self.offlineFetchAvailable) {
        return;
    }
    NSAssert(self.offlineQueriesBlock, @"You need to set offlineQueriesBlock if -offlineFetchAvailable is YES");
    NSArray<PFQuery *> * queries = self.offlineQueriesBlock();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSMutableArray * array = [NSMutableArray array];
        NSError * error = nil;
        for (PFQuery * query in queries) {
            [query fromPinWithName:[self pinName]];
            NSArray * fetchResult = [query findObjects:&error];
            if (fetchResult) {
                [array addObjectsFromArray:fetchResult];
            }
        }
        if (block) {
            block([NSArray arrayWithArray:array], error);
        }
    });
}

- (void) storeItems:(BLBaseFetchResult *__nullable)fetchResult
           callback:(BLBoolResultBlock _Nonnull)callback {
    if (!self.offlineStoreAvailable) {
        return;
    }
    NSArray * itemsToSave = [self itemsToSaveFrom:fetchResult];
    NSString * pinName = [self pinName];
    if (!self.offlineFetchAvailable) {
        [self storeItemsInternal:itemsToSave callback:callback];
        return;
    }
    [self fetchOffline:^(id  _Nullable object, NSError * _Nullable error) {
        if (error || ![object isKindOfClass:[NSArray class]]) {
            [self storeItemsInternal:itemsToSave callback:callback];
            return;
        }
        NSArray * itemsToRemove = (NSArray *) object;
        [PFObject unpinAllInBackground:itemsToRemove
                              withName:pinName
                                 block:^(BOOL succeeded, NSError * _Nullable error) {
                                     [self storeItemsInternal:itemsToSave callback:callback];
        }];
        
    }];
}

- (void) storeItemsInternal:(NSArray *__nullable)itemsToSave
                   callback:(BLBoolResultBlock _Nonnull)callback {
    [PFObject pinAllInBackground:itemsToSave withName:[self pinName] block:callback];
}

- (NSArray *) itemsToSaveFrom:(BLBaseFetchResult *) fetchResult {
    NSMutableArray * itemsToSave = [NSMutableArray array];
    for (NSArray * section in fetchResult.sections) {
        for (id<BLDataObject> dataObject in section) {
            BOOL gotArray = NO;
            if ([dataObject respondsToSelector:@selector(objectsToStore)]) {
                NSArray * array = [dataObject objectsToStore];
                if (array) {
                    [itemsToSave addObjectsFromArray:array];
                    continue;
                }
            }
            
            if ([dataObject respondsToSelector:@selector(objectToStore)]) {
                id theObject = [dataObject objectToStore];
                if (theObject) {
                    [itemsToSave addObject:theObject];
                    continue;
                }
            }
            
            [itemsToSave addObject:dataObject];
        }
    }
    return [NSArray arrayWithArray:itemsToSave];
}

@end
