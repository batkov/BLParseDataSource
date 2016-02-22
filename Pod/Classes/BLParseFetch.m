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
    [query findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        block(objects, error);
    }];
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
        for (PFQuery * query in queries) {
            [query fromPinWithName:[self pinName]];
            NSArray * fetchResult = [query findObjects];
            if (fetchResult) {
                [array addObjectsFromArray:fetchResult];
            }
        }
        if (block) {
            block([NSArray arrayWithArray:array], nil);
        }
    });
}

- (void) storeItems:(BLBaseFetchResult *__nullable)fetchResult {
    if (!self.offlineFetchAvailable) {
        return;
    }
    NSMutableArray * items = [NSMutableArray array];
    for (NSArray * section in fetchResult.sections) {
        [items addObjectsFromArray:section];
    }
    NSString * pinName = [self pinName];
    [PFObject unpinAllObjectsInBackgroundWithName:pinName block:^(BOOL succeeded, NSError * error) {
        [PFObject pinAllInBackground:items withName:pinName];
    }];
}

@end
