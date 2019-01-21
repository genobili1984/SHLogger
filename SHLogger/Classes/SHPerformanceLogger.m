//
//  SHPerformanceLogger.m
//  AFNetworking
//
//  Created by Genobili Mao on 2018/5/31.
//

#import "SHPerformanceLogger.h"
#import "SHLogType.h"
#import "SHBaseLogger.h"

//日志缓存内存中的最大值20KB
#define MAX_LOG_CACHE_SIZE          20480
//日志写入文件最大时间间隔为2分钟
#define MAX_LOG_WRITE_INTERVAL      120
//日志文件创建检测时间间隔为5分钟
#define DEFAULT_LOG_FILE_INTERVAL   300

//队列Label
static NSString * const kLogPerformanceFileQueueLabel = @"SHPERFORMANCEFILELOGGER_QUEUE";

NSTimeInterval    const kLogPerformanceDefaultRollingFrequency = 259200; //3*24*60*60


@interface SHPerformanceLogger(){
    dispatch_semaphore_t _semaphore;
    NSMutableDictionary*  _moduleDataDic;
    NSMutableDictionary* _moduleNameFilePathDic;
}
@property (copy, nonatomic) NSString        *logDirectory;         //保存日志所在的目录
@property (strong, nonatomic) dispatch_queue_t  loggerQueue; //队列
@property (assign, atomic) NSTimeInterval  lastLogWriteTime;      //上一次日志写入时间
@property (copy, nonatomic) NSString        *currentFileName;      //当前日志文件名
@property (assign, atomic) BOOL          isWritingToLogFile;    //是否正在写入到文件中

@end

@implementation SHPerformanceLogger

- (instancetype)init {
    if (self = [super init]) {
        [self commonSetup];
    }
    return self;
}

- (void)commonSetup {
    _moduleDataDic = [NSMutableDictionary new];
    _moduleNameFilePathDic = [NSMutableDictionary new];

    //此信号量用来防止多线程访问数据， 多线程写文件
    _semaphore = dispatch_semaphore_create(1);
    
    //5秒后执行文件老化检测，每30分钟执行老化文件检测。
    [self rollingToRemoveLogFiles];
}

#pragma mark ## lazy initializer ##

- (NSString *)logDirectory{
    if ( _logDirectory.length == 0 ) {
        NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        _logDirectory = [NSString stringWithFormat:@"%@/%@", pathDocuments, kLogPerformanceDirectory];
        if (![[NSFileManager defaultManager] fileExistsAtPath:_logDirectory]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:_logDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return _logDirectory;
}

- (dispatch_queue_t)loggerQueue{
    if (!_loggerQueue) {
        _loggerQueue = dispatch_queue_create([kLogPerformanceFileQueueLabel UTF8String], NULL);
    }
    return _loggerQueue;
}

#pragma mark ## inner interface ##

#pragma mark 离线日志文件的老化
/**
 * 将NSDate格式转化为NSTimeInterval
 */
- (NSTimeInterval)dateFormatToIntervalFormat:(NSString *)dateString {
    //dateString格式如下:performancelog_2018-05-21.log
    if (dateString.length <= 0) {
        return 0;
    }
    
    //切割字符串
    NSArray *array = [[dateString stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    if (!array || array.count <= 0) {
        return 0;
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    NSDate *date = [formatter dateFromString:array.lastObject];
    return [date timeIntervalSince1970];
}

/**
 * 判断日志文件是否老化
 */
- (BOOL)isFileAgeOut:(NSString *)filename {
    NSTimeInterval tempTime = [self dateFormatToIntervalFormat:filename];
    if (tempTime == 0) { //文件名格式异常
        return YES;
    }
    if ([[NSDate date] timeIntervalSince1970] - tempTime < kLogPerformanceDefaultRollingFrequency) { //未过老化时间戳
        return NO;
    }
    return YES;
}

/**
 * 重复执行定时删除老化的离线日志文件
 */
- (void)rollingToRemoveLogFiles {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), self.loggerQueue, ^{
        NSFileManager * manager = [NSFileManager defaultManager];
        NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:self.logDirectory] objectEnumerator];
        NSString * fileName = nil;
        while ((fileName = [childFilesEnumerator nextObject]) != nil) {
            NSString *filePath = [self.logDirectory stringByAppendingString:fileName];
            if (![self isFileAgeOut:filePath]) { //如果文件未老化
                continue;
            }
            [manager removeItemAtPath:filePath error:nil];
        }
    });
}

#pragma mark 日志的缓存与写入文件

/**
 * 生成日志文件名
 *      格式:UID_MODULE_DATE_TIME (例子:1234567890_performancelog_2017-07-09.log)
 *
 * @return 日志文件名
 */
- (NSString *)generateLogFileNameWithPrefix:(NSString *)prefix {
    if ( prefix.length == 0 ) {
        prefix = @"";
    }

    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    NSString *dateTime = [formatter stringFromDate:date];

    NSString *fileName = [NSString stringWithFormat:@"%@_performancelog_%@.log", prefix, dateTime];
    return fileName;
}

/**
 * 创建日志文件
 *
 * @param logFileName 日志文件名
 */
- (void)createLogFileWithLogFileName:(NSString *)logFileName handle:(void (^)(BOOL, NSString*))handler {
    BOOL result = YES;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *path = [NSString stringWithFormat:@"%@%@", self.logDirectory, logFileName];
    if (![manager fileExistsAtPath:path]) {
         result = [manager createFileAtPath:path contents:nil attributes:nil];
    }
    if ( handler ) {
        handler(result, path);
    }
}

-(NSUInteger)logCacheDataSize {
    NSUInteger size = 0;
    for( NSString* key in _moduleDataDic ) {
        NSMutableData* data = [_moduleDataDic objectForKey:key];
        size += data.length;
    }
    return size;
}

/**
 * 将日志写入到文件
 *      日志保存策略，每次生成的日志条目，添加到logCacheData中去，然后按以下步骤写入到文件中去：
 *      如果logCacheData大小超过MAX_LOG_CACHE_SIZE，或者超过MAX_LOG_WRITE_INTERVAL，则写入对应文件
 */
- (void)writeCacheToLogFile{
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval timeOffset = currentTime - self.lastLogWriteTime;
    if ([self logCacheDataSize] > MAX_LOG_CACHE_SIZE || timeOffset > MAX_LOG_WRITE_INTERVAL ) {
        self.isWritingToLogFile = YES;
        
        __weak typeof(self) wself = self;
        dispatch_queue_async_safe(self.loggerQueue, ^{
            //dispatch_async(self.loggerQueue, ^{
            __strong typeof(wself) sself = wself;
            if( !sself ) {
                return;
            }
            //信号量互斥锁
            dispatch_semaphore_wait(sself->_semaphore, DISPATCH_TIME_FOREVER);
            
            for( NSString* key in sself->_moduleDataDic ) {
                NSMutableData* data = [sself->_moduleDataDic objectForKey:key];
                if( data.length > 0 ) {
                    //将缓存数据写入到文件中去
                    NSString* logFilePath = [sself->_moduleNameFilePathDic objectForKey:key];
                    if( logFilePath.length > 0 ){
                        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
                        [fh seekToEndOfFile];
                        [fh writeData:data];
                        [fh closeFile];
                    }
                    //清空缓存
                    [data resetBytesInRange:NSMakeRange(0, data.length)];
                    [data setLength:0];
                    
                    //锁释放
                    dispatch_semaphore_signal(sself->_semaphore);
                    //设置时间戳
                    sself.lastLogWriteTime = currentTime;
                }
            }
            sself.isWritingToLogFile = NO;
        });
    }
}

#pragma mark ## outer interface ##


-(void)writePerformaceLog:(NSString *)moduleName log:(NSString *)log {
    if (moduleName.length == 0 || log.length == 0 ) {
        return;
    }
    __weak typeof(self) wself = self;
    dispatch_queue_async_safe(self.loggerQueue, ^{
        //dispatch_async(self.loggerQueue, ^{
        __strong typeof(wself) sself =  wself;
        if( !sself ) {
            return;
        }
        
        //信号量互斥锁
        dispatch_semaphore_wait(sself->_semaphore, DISPATCH_TIME_FOREVER);
        
        NSString* filePath = [sself->_moduleNameFilePathDic objectForKey:moduleName];
        if ( filePath.length <= 0 ) {
            //创建日志文件
            NSString* fileName = [sself generateLogFileNameWithPrefix:moduleName];
            [sself createLogFileWithLogFileName:fileName handle:^(BOOL result, NSString *filePath) {
                if( result && filePath ) {
                    [sself->_moduleNameFilePathDic setObject:moduleName forKey:filePath];
                }
            }];
        }
        
        //写入内存缓存
        NSMutableData* tmpData = [sself->_moduleDataDic objectForKey:moduleName];
        if( !tmpData ){
            tmpData = [NSMutableData new];
            [sself->_moduleDataDic setObject:tmpData forKey:moduleName];
        }
        [tmpData appendData:[log dataUsingEncoding:NSUTF8StringEncoding]];
        //锁释放
        dispatch_semaphore_signal(sself->_semaphore);
        
        //写到文件
        [sself writeCacheToLogFile];
    });
}


/**
 * 强制将缓存的日志写入到文件
 */
- (void)forceFlushCacheToLogFile{
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    //将缓存数据写入到文件中去
    dispatch_semaphore_wait(self->_semaphore, DISPATCH_TIME_FOREVER);
    if( [self logCacheDataSize] > 0 ) {
        for( NSString* moduleName in self->_moduleDataDic ) {
            NSMutableData* data = [self->_moduleDataDic objectForKey:moduleName];
            if( data.length > 0 ) {
                NSString* filePath = [self->_moduleNameFilePathDic objectForKey:moduleName];
                if ( filePath.length <= 0 ) {
                    //创建日志文件
                    NSString* fileName = [self generateLogFileNameWithPrefix:moduleName];
                    [self createLogFileWithLogFileName:fileName handle:^(BOOL result, NSString *filePath) {
                        if( result && filePath ) {
                            [self->_moduleNameFilePathDic setObject:moduleName forKey:filePath];
                            NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
                            [fh seekToEndOfFile];
                            [fh writeData:data];
                            [fh closeFile];
                            //清空缓存
                            [data resetBytesInRange:NSMakeRange(0, data.length)];
                            [data setLength:0];
                        }
                    }];
                }
            }
        }
        //设置时间戳
        self.lastLogWriteTime = currentTime;
    }
    self.isWritingToLogFile = NO;
    dispatch_semaphore_signal(self->_semaphore);
}


#pragma mark ## others ##

- (void)dealloc {
  
}

@end
