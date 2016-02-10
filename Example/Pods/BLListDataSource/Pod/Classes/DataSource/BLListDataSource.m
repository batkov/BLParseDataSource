//
//  BLListDataSource.m
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

#import "BLListDataSource.h"
#import "BLSimpleListFetchResult.h"
#import "BLListDataSource+Subclass.h"

#define kBLParseListDefaultPagingLimit 15


@implementation BLListDataSource

- (instancetype) initWithFetch:(id<BLBaseFetch>) fetch {
    NSAssert(fetch, @"You need to provide fetch");
    if (self = [super init]) {
        self.pagingEnabled = YES;
        self.fetch = fetch;
    }
    return self;
}

- (BLPaging *) paging {
    if (!self.pagingEnabled) {
        return nil;
    }
    if (!_paging) {
        BLMutablePaging * paging = [BLMutablePaging new];
        paging.skip = 0;
        paging.limit = kBLParseListDefaultPagingLimit;
        _paging = [BLPaging pagingFromPaging:paging];
    }
    return _paging;
}

- (void)fetchOfflineData:(BOOL) refresh {
    if (self.fetchMode == BLFetchModeOnlineOnly) {
        return; // Offline disabled
    }
    __weak typeof(self) selff = self;
    [self.fetch fetchOffline:^(id  _Nullable object, NSError * _Nullable error) {
        if (error) {
            // TODO implement loging ?
        } else if (!selff.dataStructure || refresh) {
            BLBaseFetchResult * result = [selff createFetchResultForLocalObject:object];
            [selff processFetchResult:result];
        }
        if (refresh) {
            [selff contentLoaded:error];
        }
    }];
}

- (BOOL) hasContent {
    return [self.dataStructure hasContent];
}

- (BOOL) shouldClearList {
    return self.paging && self.paging.skip == 0;
}

- (void) updatePagingFlagsForListSize {
    if (!self.pagingEnabled) {
        return;
    }
    NSUInteger size = [self.dataStructure dataSize];
    self.canLoadMore = self.paging.skip + self.paging.limit <= size;
    BLMutablePaging * paging = [BLMutablePaging pagingFromPaging:self.paging];
    paging.skip = size;
    self.paging = paging;
}

- (void) resetData {
    self.canLoadMore = YES;
    self.paging = nil;
    self.dataStructure = nil;
}

- (void) loadNextPageIfNeeded {
    if (!self.canLoadMore)
        return;
    if (self.state != BLDataSourceStateContent)
        return;
    [self startContentRefreshing];
}

- (void) runRequest {
    if (self.fetchMode == BLFetchModeOnfflineOnly) {
        [self fetchOfflineData:YES];
        return;
    }
    [self.fetch fetchOnline:self.paging
                   callback:[self createResultBlock]];
}

- (BLIdResultBlock) createResultBlock {
    return ^(id object, NSError * error){
        if ([self failIfNeeded:error])
            return;
        BLBaseFetchResult * fetchResult = [self createFetchResultFor:object];
        if (![fetchResult isValid]) {
            [self contentLoaded:fetchResult.lastError];
            return;
        }
        [self itemsLoaded:fetchResult];
    };
}

- (BOOL) failIfNeeded:(NSError *)error {
    if (error) {
        [self contentLoaded:error];
        return YES;
    }
    return NO;
}

- (void) itemsLoaded:(BLBaseFetchResult *) fetchResult {
    if ([self shouldClearList]) {
        self.dataStructure = nil;
        [self.fetch storeItems:fetchResult];
    }
    
    [self processFetchResult:fetchResult];
    [self updatePagingFlagsForListSize];
    [self contentLoaded:nil];
}

- (void) startContentLoading {
    [super startContentLoading];
    [self fetchOfflineData:NO];
    [self runRequest];
}

- (void) startContentRefreshing {
    [super startContentRefreshing];
    [self runRequest];
}

- (BOOL) refreshContentIfPossible {
    NSAssert(self.state != BLDataSourceStateInit, @"We actually shouldn't be here");
    if (self.state == BLDataSourceStateLoadContent)
        return NO;
    if (self.state == BLDataSourceStateRefreshContent)
        return NO;
    self.paging = nil;
    [self startContentRefreshing];
    return YES;
    
}

- (BOOL) loadMoreIfPossible {
    if (self.state == BLDataSourceStateLoadContent)
        return NO;
    if (self.state == BLDataSourceStateRefreshContent)
        return NO;
    
    if (self.state != BLDataSourceStateContent)
        return NO;
    [self startContentRefreshing];
    return YES;
}

- (void) processFetchResult:(BLBaseFetchResult *) fetchResult {
    if (!self.dataStructure) {
        self.dataStructure = [self dataStructureFromFetchResult:fetchResult];
    } else {
        [self.dataStructure processFetchResult:fetchResult];
    }
    self.dataStructure.changedBlock = self.itemsChangedBlock;
    if (self.itemsChangedBlock) {
        self.itemsChangedBlock ();
    }
}

- (BLDataStructure *) dataStructureFromFetchResult:(BLBaseFetchResult *) fetchResult {
    return [BLDataStructure dataStructureWithFetchResult:fetchResult];
}

#pragma mark - Abstract Methods
- (BLBaseFetchResult * __nonnull) createFetchResultFor:(id)object {
    return [BLSimpleListFetchResult fetchResultForObject:object]; // For subclassing
}

- (BLBaseFetchResult * __nonnull) createFetchResultForLocalObject:(id)object {
    return [BLSimpleListFetchResult fetchResultForLocalObject:object]; // For subclassing
}

@end
