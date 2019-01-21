//
//  SHRealTimeLogger.m
//  SmartHome
//
//  Created by zhenwenl on 2017/7/3.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import "SHRealTimeLogger.h"
#import "SHLogMessage.h"
#import <mach/mach_time.h>
#import "SHLogConfig.h"

static NSString * const kLogRealTimeQueueLabel = @"SHREALTIMELOGGER_QUEUE"; //队列Label
NSInteger         const kLogMaxCacheLogItems = 1000;


@interface SHRealTimeLogger ()

@property (strong, nonatomic) NSMutableArray *cacheLogArray;

@end

@implementation SHRealTimeLogger

#pragma mark ## initialize ##

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

- (void)commonSetup {
    self.formatMode = SHLogFormatModePlain;
    self.logFormatter = [SHLogPlainFommatter new];
    //_semaphore = dispatch_semaphore_create(1);
}

#pragma mark ## lazy initializer ##

- (NSMutableArray *)cacheLogArray {
    if (!_cacheLogArray) {
        _cacheLogArray = [[NSMutableArray alloc] init];
    }
    return _cacheLogArray;
}

- (dispatch_queue_t)loggerQueue{
    if (!_loggerQueue) {
        _loggerQueue = dispatch_queue_create([kLogRealTimeQueueLabel UTF8String], NULL);
    }
    return _loggerQueue;
}


#pragma mark ## inner interface ##

/**
 * 将日志上传到服务器
 *
 * @param logString 日志字符串
 */
- (void)reportLogToServerWithLog:(NSString *)logString {
    if (!logString) {
        return;
    }
    
    //上传日志字符串到云端， 调用回调
    if( self.uploadBlock  ) {
        self.uploadBlock( logString );
    }
    
    printf("\n+++> 实时上报日志:%s\n", [logString UTF8String]);
}

- (void)reportLogToServerWithLogCache:(NSMutableData *)cacheData {
    if (!cacheData || cacheData.length <= 0) {
        return;
    }
    
    //将缓存的日志上报服务器, 调用回调
    if( self.uploadBlock ) {
        self.uploadBlock( cacheData );
    }
    
    //清空缓存，  所有的操作都在一个线程中，不用加锁了
    //dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);

    [self.cacheLogArray removeAllObjects];
    [self.logCacheData resetBytesInRange:NSMakeRange(0, self.logCacheData.length)];
    [self.logCacheData setLength:0];
    [self.tempCacheData resetBytesInRange:NSMakeRange(0, self.tempCacheData.length)];
    [self.tempCacheData setLength:0];

    //dispatch_semaphore_signal(_semaphore);
}

/**
 * 将日志添加到内存中
 *
 * @param logString 日志字符串
 */
- (void)cacheLogsToMemory:(NSString *)logString {
    //信号量互斥锁， 所有的操作都在一个线程中，不用加锁了
    //dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);

    if (self.cacheLogArray.count < kLogMaxCacheLogItems) {
        [self.cacheLogArray addObject:logString];
    } else {
        [self.cacheLogArray removeObjectAtIndex:0];
        [self.cacheLogArray addObject:logString];
    }
    
    //锁释放
   // dispatch_semaphore_signal(_semaphore);
}

- (void)reportAndClearMemoryCache {
    if (self.cacheLogArray.count <= 0) {
        return;
    }
    
#ifdef DEBUG
    //纳秒级的时间精度
    uint64_t start = mach_absolute_time ();
#endif
    
    //信号量互斥锁， 所有的操作都在一个线程中，不用加锁了
    //dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);

    for (NSString *logString in self.cacheLogArray) {
        [self.logCacheData appendData:[logString dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    //锁释放
    //dispatch_semaphore_signal(_semaphore);
    
#ifdef DEBUG
    uint64_t end = mach_absolute_time ();
    uint64_t elapsed = end - start;
    printf("\n------>时间差:%.3f毫秒\n", elapsed/1000000.0);
#endif
    
    [self reportLogToServerWithLogCache:self.logCacheData];
}

#pragma mark ## outer interface ##

- (void)generateLogItem:(SHLogMessage *)logItem logConfig:(SHLogConfigModel*)logConfig networkStatus:(NetworkStatus)netStatus {
    if (!logItem) {
        return;
    }
    __weak typeof(self) wself = self;
    void(^block)(void) = ^{
        __strong typeof(wself) sself = wself;
        if( !sself ) {
            return;
        }
        
        //上传服务器 or 缓存到内存
        if ( netStatus == NotReachable ) { //断网情况下将日志缓存到内存中
            [sself cacheLogsToMemory:[sself.logFormatter formatForLogItem:logItem]];
        } else { //联网情况下直接上传服务器
            [sself reportAndClearMemoryCache];
            [sself reportLogToServerWithLog:[sself.logFormatter formatForLogItem:logItem]];
        }
    };
    dispatch_queue_async_safe(self.loggerQueue, block);
}

@end
