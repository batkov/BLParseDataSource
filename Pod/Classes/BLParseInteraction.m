//
//  BLParseInteraction.m
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

@implementation BLParseInteraction

- (instancetype) init {
    if (self = [super init]) {
        self.pinName = PFObjectDefaultPin;
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
    NSAssert(self.offlineQueriesBlock, @"You need to set offlineQueriesBlock if -offlineFetchAvailable is YES");
    NSArray<PFQuery *> * queries = self.offlineQueriesBlock();
    dispatch_queue_t queue = self.offlineFetchQueue ? : dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
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

- (void)fetchOfflineObject:(id<BLDataObject> _Nonnull)dataObject
                  callback:(BLIdResultBlock _Nonnull)callback {
    NSString * pinName = self.pinName;
    NSArray<PFObject *> * objectsToFetch = [self fetchObjectsFrom:dataObject];
    if (objectsToFetch) {
        dispatch_queue_t queue = self.offlineFetchQueue ? : dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue, ^{
            NSMutableArray * array = [NSMutableArray array];
            NSError * error = nil;
            for (PFObject * object in objectsToFetch) {
                NSAssert(object.objectId, @"Cannot fetch not saved object");
                PFQuery * query = [[object class] query];
                [query fromPinWithName:pinName];
                [query whereKey:@"objectId" equalTo:object.objectId];
                id result = [query getFirstObject:&error];
                if (error) {
                    break;
                }
                [array addObject:result];;
            }
            callback([NSArray arrayWithArray:array], error);
        });
        return;
    }
    
    NSError * error = nil;
    PFObject * objectToFetch = [self fetchObjectFrom:dataObject];
    NSAssert(objectToFetch.objectId, @"Cannot fetch not saved object");
    PFQuery * query = [[objectToFetch class] query];
    [query fromPinWithName:pinName];
    [query whereKey:@"objectId" equalTo:objectToFetch.objectId];
    id result = [query getFirstObject:&error];
    callback(result, error);
}


- (void)fetchOnlineObject:(id<BLDataObject> _Nonnull)dataObject
                 callback:(BLIdResultBlock _Nonnull)callback {
    NSArray<PFObject *> * objectsToFetch = [self fetchObjectsFrom:dataObject];
    if (objectsToFetch) {
        [PFObject fetchAllInBackground:objectsToFetch
                                 block:^(NSArray * _Nullable objects, NSError * _Nullable error) {
                                     callback(objects, error);
                                 }];
        return;
    }
    PFObject * objectToFetch = [self fetchObjectFrom:dataObject];
    [objectToFetch fetchInBackgroundWithBlock:^(PFObject * _Nullable object, NSError * _Nullable error) {
        callback(object, error);
    }];
}

- (PFObject *) fetchObjectFrom:(id<BLDataObject> _Nonnull)dataObject {
    if ([dataObject respondsToSelector:@selector(objectToFetch)]) {
        PFObject * objectToFetch = [dataObject objectToFetch];
        NSAssert([objectToFetch isKindOfClass:[PFObject class]], @"Wrong object returned from 'objectToFetch', %@", objectToFetch);
        return objectToFetch;
    }
    NSAssert([dataObject isKindOfClass:[PFObject class]], @"Wrong object provided to fetch, %@", dataObject);
    return (PFObject *)dataObject;
}
- (NSArray<PFObject *> *) fetchObjectsFrom:(id<BLDataObject> _Nonnull)dataObject {
    if ([dataObject respondsToSelector:@selector(objectsToFetch)]) {
        NSArray * objectsToFetch = [dataObject objectsToFetch];
        NSAssert([objectsToFetch isKindOfClass:[NSArray class]], @"Wrong object returned from 'objectsToFetch'");
        for (id obj in objectsToFetch) {
            NSAssert([obj isKindOfClass:[PFObject class]], @"Wrong object returned from 'objectsToFetch', %@", obj);
        }
        return objectsToFetch;
    }
    return nil;
}



- (void) storeItems:(BLBaseFetchResult *__nullable)fetchResult
      removeOldData:(BOOL)removeOldData
           callback:(BLBoolResultBlock __nonnull) callback; {
    NSArray * itemsToSave = [self itemsToSaveFrom:fetchResult];
    NSString * pinName = [self pinName];
    if (!self.offlineQueriesBlock || !removeOldData) {
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


- (void) saveNewObject:(id<BLDataObject> __nonnull)object callback:(BLIdResultBlock __nonnull)callback {
    NSAssert([object isKindOfClass:[PFObject class]], @"Cannot operate with obects that is not kind of PFObject");
    PFObject * pfObject = (PFObject *)object;
    [pfObject saveInBackgroundWithBlock:^(BOOL succeeded, NSError * _Nullable error) {
        if (succeeded) {
            callback(pfObject, nil);
            return;
        }
        callback(nil, error);
    }];
}

- (void) updateObject:(id<BLDataObject> __nonnull)object callback:(BLIdResultBlock __nonnull)callback {
    NSAssert([object isKindOfClass:[PFObject class]], @"Cannot operate with obects that is not kind of PFObject");
    PFObject * pfObject = (PFObject *)object;
    [pfObject saveInBackgroundWithBlock:^(BOOL succeeded, NSError * _Nullable error) {
        if (succeeded) {
            callback(pfObject, nil);
            return;
        }
        callback(nil, error);
    }];
}

- (void) deleteObject:(id<BLDataObject> __nonnull)object callback:(BLBoolResultBlock __nonnull)callback {
    NSAssert([object isKindOfClass:[PFObject class]], @"Cannot operate with obects that is not kind of PFObject");
    PFObject * pfObject = (PFObject *)object;
    [pfObject deleteInBackgroundWithBlock:^(BOOL succeeded, NSError * _Nullable error) {
        callback(succeeded, error);
    }];
}

@end
