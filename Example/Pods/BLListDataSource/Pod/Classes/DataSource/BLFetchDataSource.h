//
//  BLFetchDataSource.h
//  BLListDataSource
//
//  Created by Hariton Batkov on 10/26/17.
//

#import "BLDataSource.h"
#import "BLBaseFetch.h"
#import "BLBaseUpdate.h"

@interface BLFetchDataSource : BLDataSource
@property (nonatomic, assign) BLFetchMode fetchMode; // BLFetchModeOnlineOffline by default

// 15 second. How long till we reload data. Set -1 to disable reload
@property (nonatomic, assign) NSTimeInterval defaultFetchDelay;

// 5 second. How long till we reload data if error occurred. Set -1 to disable reload
@property (nonatomic, assign) NSTimeInterval defaultErrorFetchDelay;

@property (nonatomic, strong, readonly, nonnull) id<BLBaseFetch> fetch;
@property (nonatomic, strong, readonly, nullable) id<BLBaseUpdate> update;
@property (nonatomic, strong, readonly, nullable) id fetchedObject;
@property (nonatomic, copy, nullable) BLObjectBlock fetchedObjectChanged;
@property (nonatomic, copy, nullable) BLFetchResultBlock fetchResultBlock; // Will return results from BLSimpleListFetchResult by default

// Default YES
// If YES will stop auto-refresh when app gone to background and start again
// if delay conditions are met
@property (nonatomic, assign) BOOL respectBackgroundMode;

- (__nonnull instancetype) init NS_UNAVAILABLE;
- (__nonnull instancetype) new NS_UNAVAILABLE;
- (__nonnull instancetype) initWithFetch:(id <BLBaseFetch> __nonnull) fetch NS_DESIGNATED_INITIALIZER;
- (__nonnull instancetype) initWithFetch:(id <BLBaseFetch> __nonnull) fetch update:(id <BLBaseUpdate> __nullable) update NS_DESIGNATED_INITIALIZER;

- (BOOL) failIfNeeded:(NSError * __nullable)error;
@end
