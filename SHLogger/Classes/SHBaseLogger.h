//
//  SHBaseLogger.h
//  SmartHome
//
//  Created by zhenwenl on 2017/7/3.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Reachability/Reachability.h>
#import "SHLogType.h"
#import "SHLogUploadMgr.h"

@class  SHLogMessage;
@class  SHLogConfigModel;


#define LOGSAFESTRING(string) [string isKindOfClass:[NSString class]]?string:@""

#ifndef dispatch_queue_async_safe
#define dispatch_queue_async_safe(queue, block)\
if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(queue)) == 0) {\
block();\
} else {\
dispatch_async(queue, block);\
}
#endif

#ifndef dispatch_queue_sync_safe
#define dispatch_queue_sync_safe(queue, block)\
if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(queue)) == 0) {\
block();\
} else {\
dispatch_sync(queue, block);\
}
#endif

#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block) dispatch_queue_async_safe(dispatch_get_main_queue(), block)
#endif

#pragma mark -

@protocol SHLogFormatter <NSObject>

- (NSString *)formatForLogItem:(SHLogMessage *)logItem;

@end

#pragma mark -

@protocol SHLogProtocol <NSObject>

/**
 * 生成日志缓存以及相应的后续操作
 *
 * @param logItem  日志条目
 * @param logConfig 策略
 */
- (void)generateLogItem:(SHLogMessage *)logItem logConfig:(SHLogConfigModel*)logConfig networkStatus:(NetworkStatus)netStatus;


@end

#pragma mark - 

@interface SHLogPlainFommatter : NSObject <SHLogFormatter>

@end

@interface SHLogSimpleFormatter : NSObject <SHLogFormatter>

@end

#pragma mark -

@interface SHBaseLogger : NSObject <SHLogProtocol>
{
    dispatch_queue_t     _loggerQueue;
    //dispatch_semaphore_t _semaphore;
    
    NSInteger            _currentUid;
    id<SHLogFormatter>   _logFormatter;
    
    NSMutableData        *_logCacheData;
    NSMutableData        *_tempCacheData;
    
    NSString             *_logFileNamePrefix;
}

@property (strong, nonatomic) dispatch_queue_t      loggerQueue; //队列
//@property (strong, nonatomic) dispatch_semaphore_t  semaphore;   //信号量,写互斥锁
//说明，这里不用OSSpinLock，是因为自旋锁不再线程安全，详见:http://blog.ibireme.com/2016/01/16/spinlock_is_unsafe_in_ios/

@property (strong, nonatomic) id <SHLogFormatter> logFormatter;

@property (copy, atomic) NSString* uploadServerURL;

@property (assign, nonatomic) SHLogFormatMode formatMode;

@property (strong, nonatomic) NSMutableData       *logCacheData;  //日志缓存
@property (strong, nonatomic) NSMutableData       *tempCacheData; //临时缓存，当在写文件时的logCacheData的暂时缓存区

@property (copy, nonatomic) NSString        *logDirectory;         //保存日志所在的目录
@property (copy, nonatomic) NSString        *logFileNamePrefix;    //文件名前缀

-(void)commonSetup;


/**
 * 上报日志文件接口
 *
 * @param filePath          日志文件全路径，文件目录+文件名
 * @param deleteLocalFile   是否删除本地日志文件
 * @param complete          完成回调
 */
- (void)reportLogFileToServerWithPath:(NSString *)filePath deleteLocalFile:(BOOL)deleteLocalFile complete:(SHUploadCompleteBlock)complete;


@end
