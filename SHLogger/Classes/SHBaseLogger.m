//
//  SHBaseLogger.m
//  SmartHome
//
//  Created by zhenwenl on 2017/7/3.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import "SHBaseLogger.h"
#import "SHLogMessage.h"
#import "SHLogConfig.h"
#import "SSZipArchive.h"
#import <Reachability/Reachability.h>
#import "SHLogUploadMgr.h"
#import "SHFileOfflineLogger.h"
#import "SHPerformanceLogger.h"
#import "SHCrashLogger.h"

#pragma mark - 

@implementation SHLogPlainFommatter

- (NSString *)formatForLogItem:(SHLogMessage *)logItem {
    return [logItem plainDescription];
}

@end

#pragma mark -

@implementation SHLogSimpleFormatter

- (NSString *)formatForLogItem:(SHLogMessage *)logItem {
    return [logItem simpleDescription];
}

@end

#pragma mark -

@implementation SHBaseLogger

- (instancetype)init {
    if (self = [super init]) {
        [self commonSetup];
    }
    return self;
}

- (void)commonSetup {
}

- (void)generateLogItem:(SHLogMessage *)logItem logConfig:(SHLogConfigModel*)logConfig networkStatus:(NetworkStatus)netStatus{
    // Override
}

-(void)setLogDirectory:(NSString *)logDirectory {
    if( logDirectory.length > 0  ) {
        _logDirectory = logDirectory;
        //创建文件夹
        NSFileManager *manager = [NSFileManager defaultManager];
        if (![manager fileExistsAtPath:_logDirectory]) {
            [manager createDirectoryAtPath:_logDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
}

-(void)setFormatMode:(SHLogFormatMode)formatMode {
    __weak typeof(self) wself = self;
    void(^block)(void) = ^{
        __strong typeof(wself) sself = wself;
        if( !sself ) {
            return;
        }
        if(  formatMode != sself->_formatMode ){
            self.logFormatter = (formatMode == SHLogFormatModePlain) ? [SHLogPlainFommatter new] : [SHLogSimpleFormatter new];
            sself->_formatMode = formatMode;
        }
    };
    dispatch_queue_async_safe(self.loggerQueue, block);
}

/**
 * 上报日志文件接口
 *
 * @param filePath          日志文件全路径，文件目录+文件名
 * @param deleteLocalFile   是否删除本地日志文件
 * @param complete          完成回调
 */
- (void)reportLogFileToServerWithPath:(NSString *)filePath deleteLocalFile:(BOOL)deleteLocalFile complete:(SHUploadCompleteBlock)complete {
    //服务器路径
    if( self.uploadServerURL.length == 0  ) {
        return;
    }
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:filePath]) {
        return;
    }
    
    UInt64 srcFileSize = [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    if (srcFileSize == 0) {
        return;
    }
    
    //构建上传任务
    SHLogUploader* uploader = [[SHLogUploader alloc] initWithFilePath:filePath serverURL:self.uploadServerURL sourceSize:srcFileSize deleteFileAfterUploaded:deleteLocalFile];
    [[SHLogUploadMgr sharedInstance] uploadTaskWithItem:uploader complete:complete];
}

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

@end
