//
//  SHCrashLogger.m
//  SmartHome
//
//  Created by zhenwenl on 2017/7/9.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import "SHCrashLogger.h"
#import "SHLogType.h"
#import "SHLogUploadMgr.h"

static SHCrashLogger *selfClass = nil;

//队列Label
static NSString * const kLogCrashFileQueueLabel = @"SHCRASHFILELOGGER_QUEUE";
//日志上传的服务器路径
static NSString * const kLogFileDestServerPath = @"http://iot-dev-upgrade-center-tice.egtest.cn:9000/file_upload/";

@interface SHCrashLogger()

@property (strong, nonatomic) NSDateFormatter *dateFormatter;        //日期格式

@end

@implementation SHCrashLogger

#pragma mark ## initialize ##

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

- (void)commonSetup {
    //设置队列名称
    self.formatMode = SHLogFormatModePlain;
    self.logFormatter = [SHLogPlainFommatter new];
    selfClass = self;
}

#pragma mark ## lazy initializer ##

- (NSString *)crashLogDirectory {
    if ( self.logDirectory.length == 0 ) {
        NSString *pathDocuments = NSHomeDirectory();
        self.logDirectory = [NSString stringWithFormat:@"%@/Documents%@", pathDocuments, kLogCrashFileCacheDirectory];
    }
    return self.logDirectory;
}

- (dispatch_queue_t)loggerQueue{
    if (!_loggerQueue) {
        _loggerQueue = dispatch_queue_create([kLogCrashFileQueueLabel UTF8String], NULL);
    }
    return _loggerQueue;
}

#pragma mark ## outer interface ##

#pragma mark crash日志获取

+(void)uncaughtExceptionHandler:(NSException*)exception logNamePrefix:(NSString*)logNamePrefix{
    
    //异常的堆栈信息
    NSArray *stackArray = [exception callStackSymbols];
    if( stackArray.count == 0 ) {
        id callStack = exception.userInfo[@"callStack"];
        if( callStack && [callStack isKindOfClass:[NSString class]] ) {
            stackArray = @[callStack];
        }
    }
    
    //出现异常的原因
    NSString *reason = [exception reason];
    
    //异常名
    NSString *name = [exception name];
    
    
    NSString *exceptionInfo = [NSString stringWithFormat:@"Exception reason:%@\nException name:%@\nException stack:%@",name, reason, stackArray];
    
    NSMutableArray *tmpArr = [NSMutableArray arrayWithArray:stackArray];
    
    [tmpArr insertObject:reason atIndex:0];

    //文件名栗子:u1234567890_offline_crashlog_20170709000000.log
    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *dateTime = [formatter stringFromDate:date];

    NSString *fileName = [NSString stringWithFormat:@"%@_crashlog_%@.log", LOGSAFESTRING(logNamePrefix), dateTime];
    NSString *filePath = [NSString stringWithFormat:@"%@/Documents%@%@", NSHomeDirectory(), kLogCrashFileCacheDirectory, fileName];

    //创建文件夹
    NSString *crashLogDirectory = [NSString stringWithFormat:@"%@/Documents%@", NSHomeDirectory(), kLogCrashFileCacheDirectory];
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:crashLogDirectory]) {
        if ([manager createDirectoryAtPath:crashLogDirectory withIntermediateDirectories:YES attributes:nil error:nil]) {
            [exceptionInfo writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    } else {
        [exceptionInfo writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

-(void)setLogFileNamePrefix:(NSString *)logFileNamePrefix {
    
}

#pragma mark 上报crash日志文件

/**
 * 上报crash日志文件
 */
- (void)reportAllCrashLogFiles {
    __weak typeof(self) wself = self;
    NSFileManager * manager = [NSFileManager defaultManager];
    NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:[self crashLogDirectory]] objectEnumerator];
    NSString * fileName = nil;
    while ((fileName = [childFilesEnumerator nextObject]) != nil) {
        dispatch_async(self.loggerQueue, ^{
            __strong typeof(wself) sself = wself;
            if( !sself ) {
                return;
            }
            NSString *filePath = [[self crashLogDirectory] stringByAppendingString:fileName];
            [sself reportLogFileToServerWithPath:filePath deleteLocalFile:true complete:nil];
        });
    }
}

@end
