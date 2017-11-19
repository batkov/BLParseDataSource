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

#define kBLParseListDefaultPagingLimit 25


@implementation BLListDataSource

- (instancetype) initWithFetch:(id<BLBaseFetch>) fetch {
    NSAssert(fetch, @"You need to provide fetch");
    if (self = [super init]) {
        self.fetch = fetch;
        self.update = nil;
        [self commonInit];
    }
    return self;
}

- (instancetype) initWithFetch:(id<BLBaseFetch>) fetch update:(id<BLBaseUpdate>) update {
    NSAssert(fetch, @"You need to provide fetch");
    if (self = [super init]) {
        self.fetch = fetch;
        self.update = update;
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.storagePolicy = self.update ? BLOfflineFirstPage : BLOfflineDoNotStore;
    self.pagingEnabled = YES;
    self.autoAdvance = NO;
    self.fetchResultBlock = ^(id object, BOOL isLocal) {
        if (isLocal) {
            return [BLSimpleListFetchResult fetchResultForLocalObject:object];
        }
        return [BLSimpleListFetchResult fetchResultForObject:object];
    };
    self.defaultPageSize = kBLParseListDefaultPagingLimit;
}

- (BLPaging *) paging {
    if (!self.pagingEnabled) {
        return nil;
    }
    if (!_paging) {
        BLMutablePaging * paging = [BLMutablePaging new];
        paging.skip = 0;
        paging.limit = self.defaultPageSize;
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
            if (selff.fetchMode == BLFetchModeOfflineOnly && [selff shouldClearList]) {
                selff.dataStructure = nil;
            }
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
    if (!self.pagingEnabled) {
        return YES;
    }
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
    if (self.fetchMode == BLFetchModeOfflineOnly) {
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
    BOOL calledForStore = NO;
    if ([self shouldClearList]) {
        self.dataStructure = nil;
        if (self.storagePolicy == BLOfflineFirstPage) {
            calledForStore = YES;
            [self storeItems:fetchResult];
        }
    }
    
    if (self.storagePolicy == BLOfflineAllData && !calledForStore) {
        [self storeItems:fetchResult];
    }
    [self processFetchResult:fetchResult];
    [self updatePagingFlagsForListSize];
    [self contentLoaded:nil];
    [self loadNextPageIfAutoAdvance];
}

- (void) storeItems:(BLBaseFetchResult *) fetchResult {
    NSAssert(self.update, @"You need to provide 'update' to store something");
    __weak typeof(self) selff = self;
    [self.update storeItems:fetchResult
              removeOldData:self.storagePolicy == BLOfflineFirstPage
                   callback:^(BOOL result, NSError * _Nullable error) {
        if (selff.storedBlock) {
            self.storedBlock(error);
        }
    }];
}

- (void) loadNextPageIfAutoAdvance {
    if (!self.autoAdvance) {
        return;
    }
    if (!self.pagingEnabled) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadNextPageIfNeeded];
    });
}

- (void) startContentLoading {
    [super startContentLoading];
    if (self.fetchMode != BLFetchModeOfflineOnly) {
        [self fetchOfflineData:NO];
    }
    [self runRequest];
}

- (void) startContentRefreshing {
    [super startContentRefreshing];
    [self runRequest];
}

- (BOOL) refreshContentIfPossible {
    NSAssert(self.state != BLDataSourceStateInit, @"We actually shouldn't be here");
    if (self.state == BLDataSourceStateLoadContent || self.state == BLDataSourceStateRefreshContent) {
        return NO;
    }
    self.paging = nil;
    [self startContentRefreshing];
    return YES;
}

- (BOOL) loadMoreIfPossible {
    NSAssert(self.state != BLDataSourceStateInit, @"We actually shouldn't be here");
    if (self.state != BLDataSourceStateContent) {
        return NO;
    }
    // We shouldn't check here for canLoadMore
    // Case user awaits for next item to appear
    // and swipe reload from bottom
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
        self.itemsChangedBlock (self.dataStructure);
    }
}

- (BLDataStructure *) dataStructureFromFetchResult:(BLBaseFetchResult *) fetchResult {
    if (self.dataStructureBlock) {
        NSAssert(self.dataSortingBlock == nil, @"dataSortingBlock is ignored if you are using dataStructureBlock");
        BLDataStructure * dataStructure = self.dataStructureBlock(fetchResult);
        NSAssert([dataStructure isKindOfClass:[BLDataStructure class]], @"Wrong class or nil");
        return dataStructure;
    }
    if (self.dataSortingBlock) {
        BLDataSorting sorting = self.dataSortingBlock(fetchResult);
        return [BLDataStructure dataStructureWithFetchResult:fetchResult
                                                     sorting:sorting
                                                       block:self.customSortingBlock];
    }
    return [BLDataStructure dataStructureWithFetchResult:fetchResult];
}

#pragma mark - Abstract Methods
- (BLBaseFetchResult * __nonnull) createFetchResultFor:(id)object {
    if (self.fetchResultBlock) {
        return self.fetchResultBlock(object, NO);
    }
    return nil; // For subclassing
}

- (BLBaseFetchResult * __nonnull) createFetchResultForLocalObject:(id)object {
    if (self.fetchResultBlock) {
        return self.fetchResultBlock(object, YES);
    }
    return nil; // For subclassing
}

#pragma mark -
-(NSString *)description {
    NSString * fetchMode = @"OnlineAndOffline";
    if (self.fetchMode == BLFetchModeOnlineOnly) {
        fetchMode = @"Online";
    } else if (self.fetchMode == BLFetchModeOfflineOnly) {
        fetchMode = @"Offline";
    }
    return [NSString stringWithFormat:@"%@\nMode: %@\nFetch: %@\nDataStructure: %@\nPaging: %@", [super description], fetchMode, [self.fetch description], [self.dataStructure description], [self.paging description]];
}

@end
