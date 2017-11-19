//
//  BLFetchDataSource.m
//  BLListDataSource
//
//  Created by Hariton Batkov on 10/26/17.
//

#import "BLFetchDataSource.h"
#import "BLDataSource+Subclass.h"
#import "BLSimpleListFetchResult.h"

@interface BLFetchDataSource ()

@property (nonatomic, strong) id fetchedObject;

@property (nonatomic, strong) id<BLBaseFetch> fetch;
@property (nonatomic, strong) id<BLBaseUpdate> update;

@property (nonatomic, strong) NSDate * goneToBackgroundTime;
@property (nonatomic, assign) BOOL isInBackgroundMode;
@end

@implementation BLFetchDataSource
- (instancetype) initWithFetch:(id <BLBaseFetch>) fetch update:(id <BLBaseUpdate>) update {
    NSAssert(fetch, @"You need to provide fetch");
    if (self = [super init]) {
        self.fetch = fetch;
        self.update = update;
    }
    return self;
}

- (instancetype) initWithFetch:(id<BLBaseFetch>) fetch {
    NSAssert(fetch, @"You need to provide fetch");
    if (self = [super init]) {
        self.fetch = fetch;
    }
    return self;
}

- (void) commonInit {
    self.defaultFetchDelay = 15;
    self.defaultErrorFetchDelay = 15;
    self.respectBackgroundMode = YES;
    self.fetchResultBlock = ^(id object, BOOL isLocal) {
        if (isLocal) {
            return [BLSimpleListFetchResult fetchResultForLocalObject:object];
        }
        return [BLSimpleListFetchResult fetchResultForObject:object];
    };
}

#pragma mark -

- (void)fetchOfflineData:(BOOL) refresh {
    if (self.fetchMode == BLFetchModeOnlineOnly) {
        return; // Offline disabled
    }
    __weak typeof(self) selff = self;
    [self.fetch fetchOffline:^(id  _Nullable object, NSError * _Nullable error) {
        if (error) {
            // TODO implement loging ?
        } else if (!selff.fetchedObject || refresh) {
            if (selff.fetchMode == BLFetchModeOfflineOnly) {
                selff.fetchedObject = nil;
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
    return self.fetchedObject != nil;
}

- (void) resetData {
    self.fetchedObject = nil;
}

- (void) runRequest {
    if (self.fetchMode == BLFetchModeOfflineOnly) {
        [self fetchOfflineData:YES];
        return;
    }
    [self.fetch fetchOnline:nil
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
    self.fetchedObject = nil;
    if (self.update) {
        [self storeItems:fetchResult];
    }
    [self processFetchResult:fetchResult];
    [self contentLoaded:nil];
}

- (void) storeItems:(BLBaseFetchResult *) fetchResult {
    [self.update storeItems:fetchResult
              removeOldData:YES
                   callback:^(BOOL result, NSError * _Nullable error) {
        
    }];
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
    if (self.state == BLDataSourceStateLoadContent)
        return NO;
    if (self.state == BLDataSourceStateRefreshContent)
        return NO;
    [self startContentRefreshing];
    return YES;
}

- (void) processFetchResult:(BLBaseFetchResult *) fetchResult {
    id object = fetchResult.items;
    if ([fetchResult.items count] == 0) {
        object = nil;
    } else if ([fetchResult.items count] == 1) {
        object = [fetchResult.items firstObject];
    }
    self.fetchedObject = object;
    if (self.fetchedObjectChanged) {
        self.fetchedObjectChanged (self.fetchedObject);
    }
}

#pragma mark -
- (NSTimeInterval) currentStateDelay {
    NSTimeInterval delay = self.defaultFetchDelay;
    switch (self.state) {
        case BLDataSourceStateInit:
        case BLDataSourceStateLoadContent:
        case BLDataSourceStateRefreshContent:
            return -1;
        case BLDataSourceStateError:
            delay = self.defaultErrorFetchDelay;
            break;
        default:
            break;
    }
    return delay;
}

- (void) reloadDataWithDelay {
    NSTimeInterval delay = [self currentStateDelay];
    
    // Do not reload
    if (![self automaticFetchActive:delay]) {
        return;
    }
    
    __weak typeof(self) selff = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Do not reload if we gone to background.
        // But remember that we have tried and respect
        // time when retry was scheduled
        if (selff.isInBackgroundMode) {
            NSDate * newGoneToBgDate = [NSDate dateWithTimeIntervalSinceNow:-delay];
            NSAssert([newGoneToBgDate timeIntervalSince1970] > [selff.goneToBackgroundTime timeIntervalSince1970], @"This does mean that reloadDataWithDelay was started AFTER gone to BG. Investigate what is going on.");
            selff.goneToBackgroundTime = newGoneToBgDate;
            return;
        }
        [selff refreshContentIfPossible];
    });
}

-(BOOL) automaticFetchActive:(NSTimeInterval)delay {
    return delay >= 0 && !self.isInBackgroundMode;
}

-(void)setState:(BLDataSourceState)state {
    [super setState:state];
    [self reloadDataWithDelay];
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

#pragma mark - Bg/Fg mode methods

-(void)setRespectBackgroundMode:(BOOL)respectBackgroundMode {
    _respectBackgroundMode = respectBackgroundMode;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    if (_respectBackgroundMode) {
        [self setupSwitchToBackgroundMode];
    }
}

-(void)setupSwitchToBackgroundMode {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(switchToBackgroundMode)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(switchToBackgroundMode)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(switchToForegroundMode)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(switchToForegroundMode)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

-(void)switchToBackgroundMode {
    self.isInBackgroundMode = YES;
    self.goneToBackgroundTime = [NSDate date];
}

-(void)switchToForegroundMode {
    self.isInBackgroundMode = NO;
    NSTimeInterval timeGone = [[NSDate date] timeIntervalSince1970] - [self.goneToBackgroundTime timeIntervalSince1970];
    NSTimeInterval delay = [self currentStateDelay];
    if ([self automaticFetchActive:delay] && timeGone > delay) {
        [self refreshContentIfPossible];
    }
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
-(NSString *)description {
    NSString * fetchMode = @"OnlineAndOffline";
    if (self.fetchMode == BLFetchModeOnlineOnly) {
        fetchMode = @"Online";
    } else if (self.fetchMode == BLFetchModeOfflineOnly) {
        fetchMode = @"Offline";
    }
    return [NSString stringWithFormat:@"%@\nMode: %@\nFetch: %@\nFetchedObject: %@", [super description], fetchMode, [self.fetch description], self.fetchedObject];
}
@end
