//
//  SHFileLogger.m
//  SmartHome
//
//  Created by zhenwenl on 2017/7/3.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import "SHFileLogger.h"
#import "SHLogMessage.h"
//#import "SHFileUploader.h"
//#import "SHFileUploadManager.h"
#include <string.h>
#import "SHLogConfig.h"
#import "SHLogType.h"

//日志缓存内存中的最大值20KB
#define MAX_LOG_CACHE_SIZE          20480
//日志写入文件最大时间间隔为2分钟:120
#define MAX_LOG_WRITE_INTERVAL      120
//日志文件创建检测时间间隔为5分钟
#define DEFAULT_LOG_FILE_INTERVAL   300


static NSString * const kLogFileDestServerPath = @"http://iot-dev-upgrade-center-tice.egtest.cn:9000/file_upload/";
static NSString * const kLogFileQueueLabel = @"SHFILELOGGER_QUEUE"; //队列Label

@interface SHFileLogger()

@property (strong, atomic) NSString       *currentLogFileName;   //当前日志文件名

@property (assign, atomic) NSTimeInterval lastLogFileCreateTime; //上次创建的日志文件时间
@property (assign, atomic) NSTimeInterval logFileCreateInterval; //日志文件创建时间间隔

@property (assign, atomic) NSTimeInterval lastLogWriteTime;      //上一次日志写入时间
@property (assign, atomic) BOOL           isWritingToLogFile;    //是否正在写入到文件中

@property (assign, atomic) BOOL           isToReportLogFile;     //是否上报日志文件

@end

@implementation SHFileLogger

#pragma mark ## initialize ##

- (instancetype)init {
    if (self = [super init]) {
        _logFileCreateInterval = DEFAULT_LOG_FILE_INTERVAL; //TODO:需注意时间间隔的填充
    }
    return self;
}

- (void)commonSetup {
    self.formatMode = SHLogFormatModePlain;
    _logFormatter = [SHLogPlainFommatter new];
    //设置队列名称
    
    //_semaphore = dispatch_semaphore_create(1);
    
    //日志文件
    _currentLogFileName = nil;
    _lastLogWriteTime = [[NSDate date] timeIntervalSince1970]; //当前时间的时间戳
    _lastLogFileCreateTime = _lastLogWriteTime;
    _isWritingToLogFile = NO;
    
    _isToReportLogFile = NO;
}

#pragma mark ## lazy initializer ##

- (NSMutableData *)logCacheData {
    if (!_logCacheData) {
        _logCacheData = [[NSMutableData alloc] init];
    }
    return _logCacheData;
}

- (NSMutableData *)tempCacheData {
    if (!_tempCacheData) {
        _tempCacheData = [[NSMutableData alloc] init];
    }
    return _tempCacheData;
}

- (dispatch_queue_t)loggerQueue{
    if (!_loggerQueue) {
        _loggerQueue = dispatch_queue_create([kLogFileQueueLabel UTF8String], NULL);
    }
    return _loggerQueue;
}

- (NSString *)logDirectory {
    if ( [super logDirectory].length == 0 ) {
        NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        self.logDirectory = [NSString stringWithFormat:@"%@/%@", pathDocuments, kLogFileCacheDirectory];
    }
    return [super logDirectory];
}

#pragma mark ## inner interface ##

/**
 * 生成日志文件名
 *      格式:UID_MODULE_DATE_TIME (栗子:u1234567890_201707041459)
 *
 * @return 日志文件名
 */
- (NSString *)generateLogFileNameWithPrefix:(NSString *)prefix {
    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *dateTime = [formatter stringFromDate:date];

    NSString *fileName = [NSString stringWithFormat:@"%@_%@", LOGSAFESTRING(prefix), dateTime];
    return fileName;
}

/**
 * 创建日志文件
 *
 * @param logFileName 日志文件名
 */
- (BOOL)createLogFileWithLogFileName:(NSString *)logFileName {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *path = [NSString stringWithFormat:@"%@%@", self.logDirectory, logFileName];
    if (![manager fileExistsAtPath:path]) {
        return [manager createFileAtPath:path contents:nil attributes:nil];
    }
    return YES;
}

/**
 * 将日志写入到文件
 *      日志保存策略，每次生成的日志条目，添加到logCacheData中去，然后按以下步骤写入到文件中去：
 *      如果logCacheData大小超过MAX_LOG_CACHE_SIZE，或者超过MAX_LOG_WRITE_INTERVAL，则写入对应文件
 */
- (void)writeCacheToLogFile:(BOOL)forceWrite {
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval timeOffset = currentTime - self.lastLogWriteTime;

    if (self.logCacheData.length > MAX_LOG_CACHE_SIZE || timeOffset > MAX_LOG_WRITE_INTERVAL || forceWrite) {
        self.isWritingToLogFile = YES;
        
        __weak typeof(self) wself = self;
        void(^block)(void) = ^{
            __strong typeof(wself) sself = wself;
            if( !sself ) {
                return;
            }
            //信号量互斥锁
            //dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
            
            if ( sself.currentLogFileName.length == 0) {
                //创建日志文件
                sself.currentLogFileName = [sself generateLogFileNameWithPrefix:sself.logFileNamePrefix];
                [sself createLogFileWithLogFileName:sself.currentLogFileName]; //创建日志文件
            }
            //将缓存数据写入到文件中去
            NSMutableString* logFilePath = [NSMutableString new];
            [logFilePath appendString:sself.logDirectory];
            [logFilePath appendString:sself.currentLogFileName];
            NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingAtPath:logFilePath];
            [fh seekToEndOfFile];
            [fh writeData:sself.logCacheData];
            [fh closeFile];
            
            //清空缓存
            [sself.logCacheData resetBytesInRange:NSMakeRange(0, sself.logCacheData.length)];
            [sself.logCacheData setLength:0];
            
            //锁释放
            // dispatch_semaphore_signal(self.semaphore);
            
            //设置时间戳
            sself.lastLogWriteTime = currentTime;
            
            //判断文件时间戳是否达到，达到则创建新的日志文件
            NSTimeInterval offset = currentTime - sself.lastLogFileCreateTime;
            if (offset > sself.logFileCreateInterval) {
                
                if (sself.isToReportLogFile) {
                    [sself reportLogFileToServerWithFileName:sself.currentLogFileName];
                }
                
                //创建新的日志文件
                NSString *fileName = [sself generateLogFileNameWithPrefix:self.logFileNamePrefix];
                [sself createLogFileWithLogFileName:fileName];
                sself.currentLogFileName = fileName;
                
                //设置时间戳
                sself.lastLogFileCreateTime = currentTime;
            }
        };
        dispatch_queue_async_safe(self.loggerQueue, block);
    }
    
    self.isWritingToLogFile = NO;
}

/**
 * 上报日志文件接口
 *
 * @param filePath          日志文件全路径，文件目录+文件名
 * @param fileName          文件名
 * @param deleteLocalFile   是否删除本地日志文件
 */
- (void)reportLogFileToServerWithPath:(NSString *)filePath fileName:(NSString *)fileName deleteLocalFile:(BOOL)deleteLocalFile {
//    NSString *dstPath = kLogFileDestServerPath;
//    NSFileManager *manager = [NSFileManager defaultManager];
//    if (![manager fileExistsAtPath:filePath]) {
//        return;
//    }
//
//    UInt64 srcFileSize = [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
//    if (srcFileSize == 0) {
//        return;
//    }
    
    //to do
//    //构建上传任务并添加到上传队列中去
//    SHFileUploader *uploadItem = [[SHFileUploader alloc] initWithSourceFileName:fileName sourceFilePath:filePath destFilePath:dstPath sourceFileSize:srcFileSize uploadedFileSize:0 shouldDeleteTempFile:deleteLocalFile];
//    [SHFileUploadManager addUploadTaskWithItem:uploadItem];

}

/**
 * 上报指定文件名的日志
 *
 * @param fileName 文件名
 */
- (void)reportLogFileToServerWithFileName:(NSString *)fileName {
    __weak typeof(self) wself = self;
    void(^block)(void) = ^{
        __strong typeof(wself) sself = wself;
        if( !sself ) {
            return;
        }
        NSString *filePath = [sself.logDirectory stringByAppendingString:fileName];
        [sself reportLogFileToServerWithPath:filePath fileName:fileName deleteLocalFile:YES];
    };
    dispatch_queue_async_safe(self.loggerQueue, block);
}

#pragma mark ## outter interface ##

#pragma mark ## 日志缓存生成 ##

/**
 * 将生成的日志条目写入到缓存中去
 *      注意：当logCacheData正在写入文件的过程中，需要将缓存写到tempCacheData中过渡
 *           然后在文件写完后再将tempCacheData添加到logCacheData后清空。
 *
 * @param logItem  日志条目
 * @param logConfig 日志策略配置
 */
- (void)generateLogItem:(SHLogMessage *)logItem logConfig:(SHLogConfigModel*)logConfig networkStatus:(NetworkStatus)netStatus{
    
    if (!logItem) {
        return;
    }
    
    self.isToReportLogFile = (netStatus == ReachableViaWiFi);
    
    __weak typeof(self) wself = self;
    void(^block)(void) = ^{
        __strong typeof(wself) sself = wself;
        if( !sself ) {
            return;
        }
        
        //信号量互斥锁
        //dispatch_semaphore_wait(sself.semaphore, DISPATCH_TIME_FOREVER);
        //写入内存缓存
        if (sself.isWritingToLogFile) { //当前正在将缓存写入到文件
            [sself.tempCacheData appendData:[[sself.logFormatter formatForLogItem:logItem] dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            if (sself.tempCacheData.length > 0) { //如果临时缓存中有内容则将临时缓存输出到日志缓存中去
                [sself.logCacheData appendData:sself.tempCacheData];
                
                [sself.tempCacheData resetBytesInRange:NSMakeRange(0, sself.tempCacheData.length)];
                [sself.tempCacheData setLength:0];
            }
            [sself.logCacheData appendData:[[sself.logFormatter formatForLogItem:logItem] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        
        //锁释放
        //dispatch_semaphore_signal(sself.semaphore);
        
        //写到文件
        [sself writeCacheToLogFile:NO];
    };
    dispatch_queue_async_safe(self.loggerQueue, block);
}

- (void)forceFlushCacheToLogFile {
    [self writeCacheToLogFile:YES];
}

-(void)setLogFileNamePrefix:(NSString *)logFileNamePrefix {
    __weak typeof(self) wself = self;
    void(^block)(void) = ^{
        __strong typeof(wself) sself = wself;
        if( !sself ) {
            return;
        }
        if( ![LOGSAFESTRING(logFileNamePrefix) isEqualToString:LOGSAFESTRING([super logFileNamePrefix]) ] ){
            [sself forceFlushCacheToLogFile];
            sself.currentLogFileName = @"";
        }
        [super setLogFileNamePrefix:logFileNamePrefix];
    };
    dispatch_queue_async_safe(self.loggerQueue, block);
}

@end
