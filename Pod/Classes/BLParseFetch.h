//
//  FSParseFetch.h
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

@import BLListDataSource;
#import <Parse/Parse.h>

typedef NSDictionary * (^BLParseCloudParamsBlock)(BLPaging * paging);
typedef PFQuery * (^BLParseQueryBlock)();
typedef NSArray<PFQuery *> * (^BLParseOfflineQueriesBlock)();

@interface BLParseFetch : NSObject <BLBaseFetch>

#pragma mark - Online from cloud func
@property (nonatomic, strong) NSString * cloudFuncName;
@property (nonatomic, copy) BLParseCloudParamsBlock cloudParamsBlock;

#pragma mark - Online from query
@property (nonatomic, copy) BLParseQueryBlock queryBlock;

#pragma mark - Offline from queries
@property (nonatomic, assign) BOOL offlineFetchAvailable; // Default is [Parse isLocalDatastoreEnabled]
@property (nonatomic, assign) BOOL offlineStoreAvailable; // Default is [Parse isLocalDatastoreEnabled]
@property (nonatomic, strong) NSString * pinName; // PFObjectDefaultPin by default
@property (nonatomic, copy) BLParseOfflineQueriesBlock offlineQueriesBlock;

#pragma mark - Offline setup
// If this property is nil dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) will be used
// Default is nil
@property (nonatomic, strong) dispatch_queue_t offlineFetchQueue;
@end
