//
//  SHOfflineLogger.m
//  SmartHome
//
//  Created by zhenwenl on 2017/7/9.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import "SHFileOfflineLogger.h"
#import "SSZipArchive.h"
#import "SHLogType.h"
#import "SHLogUploadMgr.h"
#import "SHLogManager.h"
#import "SHLoggerMacro.h"
#import "NSData+FastHex.h"
#import <sys/mman.h>
#import "LogBuffer.h"

//日志缓存内存中的最大值200KB
#define MAX_LOG_CACHE_SIZE          (200*1024)
//日志写入文件最大时间间隔为2分钟
#define MAX_LOG_WRITE_INTERVAL      120
//日志文件创建检测时间间隔为5分钟
#define DEFAULT_LOG_FILE_INTERVAL   300

//日志文件大小临界 300M
#define MAX_SUM_FILES_SIZE          (300*1024*1024)
#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);

//队列Label
static NSString * const kLogOfflineFileQueueLabel = @"SHOFFLINEFILELOGGER_QUEUE";
//日志上传的服务器路径
//static NSString * const kLogFileDestServerPath = @"http://iot-dev-upgrade-center-tice.egtest.cn:9000/file_upload/";

NSTimeInterval    const kLogDefaultRollingFrequency = 259200; //3*24*60*60
NSTimeInterval    const kLogDefaultRollingTimerPeriod = 3600; //设置查询文件老化的循环时间间隔：半小时

@interface FileInfo : NSObject

@property (nonatomic, copy) NSString* filePath;
@property (nonatomic, assign) UInt64 fileSize;
@property (nonatomic, strong) NSDate* createDate;

@end


@implementation FileInfo

@end

@interface SHFileOfflineLogger(){
    dispatch_semaphore_t _logBufferSemphore;
    dispatch_semaphore_t _logFileSemphore;
    void*  _mmapBuffer;
    LogBuffer* _log_buff;
    volatile BOOL _log_close;
    volatile BOOL _logEncrypt;
}

@property (strong, nonatomic) dispatch_source_t timer;

@property (strong, nonatomic) NSDateFormatter *dateFormatter;     //日期格式
@property (copy, nonatomic) NSString        *currentFileName;      //当前日志文件名
//@property (copy, atomic) NSString        *currentFilePath;      //当前日志文件路径


@property (assign, atomic) NSTimeInterval  lastLogFileCreateTime; //上次创建的日志文件时间
@property (assign, nonatomic) NSTimeInterval  logFileCreateInterval; //日志文件创建时间间隔

@property (assign, atomic) NSTimeInterval  lastLogWriteTime;      //上一次日志写入时间
@property (assign, atomic) BOOL            isWritingToLogFile;    //是否正在写入到文件中

@end

@implementation SHFileOfflineLogger

@synthesize usrLogData = _usrLogData;

#pragma mark ## initialize ##

- (instancetype)init {
    if (self = [super init]) {
        _log_buff = nil;
        _log_close = NO;
        _mmapBuffer = MAP_FAILED;
    }
    return self;
}

- (void)commonSetup {
    self.formatMode = SHLogFormatModePlain;
    self.logFormatter = [SHLogPlainFommatter new];
    //_isToReportToServer = NO;

    _logFileCreateInterval = DEFAULT_LOG_FILE_INTERVAL;
    

    //此信号量用来防止多线程访问日志内存缓存
    _logBufferSemphore = dispatch_semaphore_create(1);
    _logFileSemphore = dispatch_semaphore_create(1);

    //5秒后执行文件老化检测，每30分钟执行老化文件检测。
    [self rollingToRemoveLogFiles];
}

#pragma mark ## lazy initializer ##

- (NSString *)offLogDirectory{
    if ( self.logDirectory.length == 0 ) {
        NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        self.logDirectory = [NSString stringWithFormat:@"%@/%@", pathDocuments, kLogOfflineFileCacheDirectory];
    }
    return self.logDirectory;
}

- (NSString *)logFileNamePrefix{
    if (_logFileNamePrefix.length == 0) {
        NSArray * files = [SHLogManager offlineListFiles:false];
        if (files.count > 0) {
            _logFileNamePrefix = [self getFileNamePrefix:[files objectAtIndex:0]];
        }
    }
    
    return _logFileNamePrefix;
}

- (NSString *)currentFileName{
    if (_currentFileName.length == 0) {
        NSArray * files = [SHLogManager offlineListFiles:false];
        if (files.count > 0) {
            NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
            NSString * path = [files objectAtIndex:0];
            NSError* error = nil;
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
            NSTimeInterval createInteval = [attributes[NSFileCreationDate] timeIntervalSince1970];
            if(  self.enableLogAppendMode ) {
                NSDate *date = [NSDate date];
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                [formatter setDateStyle:NSDateFormatterMediumStyle];
                [formatter setTimeStyle:NSDateFormatterShortStyle];
                [formatter setDateFormat:@"yyyy-MM-dd-HH-00-00"];
                NSString *dateTime = [formatter stringFromDate:date];
                NSString *fileName = [NSString stringWithFormat:@"appendOffLog_%@.log", dateTime];
                NSArray * components = [path componentsSeparatedByString:@"/"];
                if (components.count > 0  && [fileName isEqualToString:[components lastObject]] ) {
                    _currentFileName = fileName;
                    self.lastLogFileCreateTime = createInteval;
                }else{
                    [self createLogFile];
                }
            }else{
                NSTimeInterval offset = currentTime - createInteval;
                if (offset <= self.logFileCreateInterval) {
                    NSArray * components = [path componentsSeparatedByString:@"/"];
                    if (components.count > 0) {
                        _currentFileName = [components lastObject];
                    }
                    self.lastLogFileCreateTime = createInteval;
                }
                else{
                    [self createLogFile];
                }
            }
        }else{
            [self createLogFile];
        }
    }
    return _currentFileName;
}

- (NSTimeInterval)logFileCreateInterval{
    if (_logFileCreateInterval == 0) {
        __unused NSString * name = [self currentFileName];
    }
    return _logFileCreateInterval;
}

- (dispatch_queue_t)loggerQueue{
    if (!_loggerQueue) {
        _loggerQueue = dispatch_queue_create([kLogOfflineFileQueueLabel UTF8String], NULL);
    }
    return _loggerQueue;
}

-(void)encryptOfflineLog:(BOOL)encrypt {
    _logEncrypt = encrypt;
}

-(void)setUsrLogData:(NSDictionary *)usrLogData {
    @synchronized(self) {
        _usrLogData = usrLogData;
    }
    if( usrLogData ) {
        NSString* str = [NSString stringWithFormat:@"%@-----\n%@\n", @"$$usrLogData$$", [usrLogData description]];
        [self appendLog:str];
    }
}

-(NSDictionary*)usrLogData {
    @synchronized(self) {
        NSDictionary* dic = [_usrLogData copy];
        return dic;
    }
}

- (NSDateFormatter *)dateFormatter {
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = @"yyyy-MM-dd-HH-mm-ss";
    }
    return _dateFormatter;
}

#pragma mark ## inner interface ##

#pragma mark 离线日志文件的老化
/**
 * 将NSDate格式转化为NSTimeInterval
 */
- (NSTimeInterval)dateFormatToIntervalFormat:(NSString *)dateString {
    //dateString格式如下:1111111_offlog_2018-05-21-11-26-24.log
    if (dateString.length <= 0) {
        return 0;
    }
    
    //切割字符串
    NSArray *array = [[dateString stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    if (!array || array.count <= 0) {
        return 0;
    }
    NSDate *date = [self.dateFormatter dateFromString:array.lastObject];
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
    if ([[NSDate date] timeIntervalSince1970] - tempTime < kLogDefaultRollingFrequency) { //未过老化时间戳
        return NO;
    }
    return YES;
}

/**
 * 重复执行定时删除老化的离线日志文件
 */
- (void)rollingToRemoveLogFiles {
    __weak typeof(self) wself = self;
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.loggerQueue);
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), kLogDefaultRollingTimerPeriod * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(_timer, ^{
        __strong typeof(wself) sself = wself;
        if( !sself ) {
            return;
        }
        //文件达到老化则进行删除文件, 先按创建时间倒序排， 累计文件大小， 超过300M后删除文件
        dispatch_async(sself.loggerQueue, ^{
            NSMutableArray* tmpArray = [NSMutableArray new];
            NSFileManager * manager = [NSFileManager defaultManager];
            NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:[self offLogDirectory]] objectEnumerator];
            NSString * fileName = nil;
            while ((fileName = [childFilesEnumerator nextObject]) != nil) {
                NSString *filePath = [[sself offLogDirectory] stringByAppendingString:fileName];
                NSDictionary* fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
                NSDate* createDate = [fileAttribs objectForKey:NSFileCreationDate];
                UInt64 fileSize = [[fileAttribs objectForKey:NSFileSize] longLongValue];
                FileInfo* fileInfo = [FileInfo new];
                fileInfo.filePath = filePath;
                fileInfo.fileSize = fileSize;
                fileInfo.createDate = createDate;
                [tmpArray addObject:fileInfo];
//                if (![sself isFileAgeOut:filePath]) { //如果文件未老化
//                    continue;
//                }
//                [manager removeItemAtPath:filePath error:nil];
            }
            
            [tmpArray sortUsingComparator:^NSComparisonResult(FileInfo*  _Nonnull obj1, FileInfo*  _Nonnull obj2) {
                if( obj1.createDate.timeIntervalSince1970 > obj2.createDate.timeIntervalSince1970 ) {
                    return NSOrderedAscending;
                }else if( obj1.createDate.timeIntervalSince1970 < obj2.createDate.timeIntervalSince1970 ) {
                    return NSOrderedDescending;
                }else{
                    return NSOrderedSame;
                }
            }];
            UInt64 sumSize = 0;
            for(FileInfo* fileInfo in tmpArray) {
                if( sumSize > MAX_SUM_FILES_SIZE ) {
                    [manager removeItemAtPath:fileInfo.filePath error:nil];
                }else{
                    sumSize += fileInfo.fileSize;
                }
            }
        });
    });
    dispatch_resume(_timer);
}

#pragma mark 离线日志文件上报

/**
 * 上报指定文件名的日志
 *
 * @param fileName 文件名
 */
- (void)reportLogFileToServerWithFileName:(NSString *)fileName {
    __weak typeof(self) wself = self;
    dispatch_async(self.loggerQueue, ^{
        __strong typeof(wself) sself = wself;
        if( !sself ) {
            return;
        }
        NSString *filePath = [[sself offLogDirectory] stringByAppendingString:fileName];
        [sself reportLogFileToServerWithPath:filePath deleteLocalFile:YES complete:nil];
    });
}

#pragma mark 日志的缓存与写入文件

/**
 * 生成日志文件名
 *      格式:UID_MODULE_DATE_TIME (例子:1234567890_offlog_2017-07-09-00-00-00.log)
 *
 * @return 日志文件名
 */
- (NSString *)generateLogFileNameWithPrefix:(NSString *)prefix {
    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterNoStyle];
    //追加模式下，不处理文件名前缀
    if( self.enableLogAppendMode ) {
        [formatter setDateFormat:@"yyyy-MM-dd-HH-00-00"];
        NSString *dateTime = [formatter stringFromDate:date];
        NSString *fileName = [NSString stringWithFormat:@"appendOffLog_%@.log", dateTime];
        return fileName;
    }
    if ( prefix.length == 0 ) {
        prefix = @"";
    }
    [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *dateTime = [formatter stringFromDate:date];
    
    NSString *fileName = [NSString stringWithFormat:@"%@_offlog_%@.log", prefix, dateTime];
    return fileName;
}

/**
 * 创建日志文件
 *
 * @param logFileName 日志文件名
 */
- (BOOL)createLogFileWithLogFileName:(NSString *)logFileName {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *path = [NSString stringWithFormat:@"%@%@", [self offLogDirectory], logFileName];\
    BOOL isDir = YES;
    BOOL exist = [manager fileExistsAtPath:path isDirectory:&isDir];
    if (!exist || isDir) {
        BOOL result = [manager createFileAtPath:path contents:nil attributes:nil];
        NSDictionary* dic = self.usrLogData;
        if( dic ) {
            NSString* str = [NSString stringWithFormat:@"%@-----\n%@\n", @"$$usrLogData$$", [dic description]];
             [self appendLog:str];
        }
        return result;
    }
    return YES;
}

/**
 * 创建日志文件
 */
- (void)createLogFile {
    //创建新的日志文件
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSString *fileName = [self generateLogFileNameWithPrefix:self.logFileNamePrefix];
    [self initMMAPWithDir:self.logDirectory];
    [self createLogFileWithLogFileName:fileName];
    self.currentFileName = fileName;
    
    //设置时间戳
    self.lastLogFileCreateTime = currentTime;
    
    self.lastLogWriteTime = 0;
}

- (NSString *)getFileNamePrefix:(NSString *)name{
    NSArray * ar = [name componentsSeparatedByString:@"_"];
    if (ar.count > 0) {
        return [ar objectAtIndex:0];
    }
    return @"";
}

/**
 * 将日志写入到文件
 *      日志保存策略，每次生成的日志条目，添加到logCacheData中去，然后按以下步骤写入到文件中去：
 *      如果logCacheData大小超过MAX_LOG_CACHE_SIZE，或者超过MAX_LOG_WRITE_INTERVAL，则写入对应文件
 */
- (void)writeCacheToLogFile:(BOOL)sync{
    __weak typeof(self) wself = self;
    void(^block)(void) = ^{
        __strong typeof(wself) sself = wself;
        if( !sself ) {
            return;
        }
        //信号量互斥锁
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        AutoBuffer tmp;
        LOCK(sself->_logBufferSemphore);
        if( sself->_log_buff != NULL) {
            sself->_log_buff->Flush(tmp);
            sself.lastLogWriteTime = currentTime;
        }
        UNLOCK(sself->_logBufferSemphore);
        if( tmp.Ptr() != NULL ) {
            //将缓存数据写入到文件中去
            NSMutableString* logFilePath = [NSMutableString new];
            [logFilePath appendString:[sself offLogDirectory]];
            [logFilePath appendString:sself.currentFileName];
            [self write2File:logFilePath data:tmp.Ptr() size:tmp.Length()];
        }
        //判断文件时间戳是否达到，达到则创建新的日志文件
        NSTimeInterval offset = currentTime - sself.lastLogFileCreateTime;
        if (offset > sself.logFileCreateInterval) {
            [sself createLogFile];
        }
    };
    if (sync) {
        block();
    }
    else{
        dispatch_queue_async_safe(self.loggerQueue, block);
    }
}

-(void)appendEncryptLog:(NSMutableData*)destData originData:(NSData *)orgData  {
    if( orgData.length == 0 ) {
        return;
    }
    NSData* encryptData = [orgData hexDataRepresentation];
    //加头
    uint8_t header[] = {0x08, 0x08};
    [destData appendBytes:header length:sizeof(header)];
    [destData appendData:encryptData];
    //这里再加一个换行符号，因为formatForLogItem被加密了
    uint8_t tail[] = {0xA};
    [destData appendBytes:tail length:sizeof(tail)];
}

-(NSData*)encryptLog:(NSString*)log  {
    NSData* orgData = [log dataUsingEncoding:NSUTF8StringEncoding];
    if( orgData == nil ) {
        return nil;
    }
    NSMutableData* retData = [NSMutableData data];
    NSData* encryptData = [orgData hexDataRepresentation];
    //加头
    uint8_t header[] = {0x08, 0x08};
    [retData appendBytes:header length:sizeof(header)];
    [retData appendData:encryptData];
    //这里retData加一个换行符号，因为formatForLogItem被加密了
    uint8_t tail[] = {0xA};
    [retData appendBytes:tail length:sizeof(tail)];
    return retData;
}

#pragma mark ## outer interface ##

/**
 * 将生成的日志条目写入到缓存中去
 *      注意：当logCacheData正在写入文件的过程中，需要将缓存写到tempCacheData中过渡
 *           然后在文件写完后再将tempCacheData添加到logCacheData后清空。
 *
 * @param logItem  日志条目
 * @param logConfig 具体日志配置
 * @param netStatus 网络状态
 */
- (void)generateLogItem:(SHLogMessage *)logItem logConfig:(SHLogConfigModel *)logConfig networkStatus:(NetworkStatus)netStatus{
    
    if (!logItem) {
        return;
    }
    //self.isToReportToServer = (netStatus == ReachableViaWiFi);
    NSString* strLog = [self.logFormatter formatForLogItem:logItem];
    if( strLog.length == 0  ) {
        return;
    }
    LOCK(_logBufferSemphore);
    if( NULL != _log_buff ) {
        NSData* retData =  _logEncrypt ? [self encryptLog:strLog] : [strLog dataUsingEncoding:NSUTF8StringEncoding];
        _log_buff->Write([retData bytes], retData.length);
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval timeOffset = currentTime - self.lastLogWriteTime;
        if( _log_buff->GetData().Length() >= MAX_LOG_CACHE_SIZE/2  || timeOffset > MAX_LOG_WRITE_INTERVAL ) {
            [self writeCacheToLogFile:NO];
        }
    }
    UNLOCK(_logBufferSemphore);
//
//    if ( self.currentFileName.length <= 0 ) {
//        //创建日志文件
//        self.currentFileName = [self generateLogFileNameWithPrefix:self.logFileNamePrefix];
//        [self createLogFileWithLogFileName:self.currentFileName]; //创建日志文件
//    }
//
//    __weak typeof(self) wself = self;
//    void(^block)(void) = ^{
//        __strong typeof(wself) sself =  wself;
//        if( !sself ) {
//            return;
//        }
//
//        //写入内存缓存
//        if (sself.isWritingToLogFile) { //当前正在将缓存写入到文件
//            if(sself.logEncrypt) {  //处理日志加密， 如果加密，在行头加两个uint8_t标记，ascii码为\x8\x8
//                [sself appendEncryptLog:sself.tempCacheData originData:[[self.logFormatter formatForLogItem:logItem] dataUsingEncoding:NSUTF8StringEncoding]];
//            }else{
//                [sself.tempCacheData appendData:[[sself.logFormatter formatForLogItem:logItem] dataUsingEncoding:NSUTF8StringEncoding]];
//            }
//        } else {
//            if (sself.tempCacheData.length > 0) { //如果临时缓存中有内容则将临时缓存输出到日志缓存中去
//                [sself.logCacheData appendData:sself.tempCacheData];
//                [sself.tempCacheData resetBytesInRange:NSMakeRange(0, sself.tempCacheData.length)];
//                [sself.tempCacheData setLength:0];
//            }
//            if( sself.logEncrypt ) {
//                [sself appendEncryptLog:sself.logCacheData originData:[[self.logFormatter formatForLogItem:logItem] dataUsingEncoding:NSUTF8StringEncoding]];
//            }else{
//                [sself.logCacheData appendData:[[sself.logFormatter formatForLogItem:logItem] dataUsingEncoding:NSUTF8StringEncoding]];
//            }
//        }
//
//        //锁释放
////        dispatch_semaphore_signal(sself->_semaphore);
//
//        //写到文件
//        [sself writeCacheToLogFile:false];
//    };
//    dispatch_queue_async_safe(self.loggerQueue, block);

}

/**
 * 强制将缓存的日志写入到文件
 */
- (void)forceFlushCacheToLogFile{
    [self writeCacheToLogFile:YES];
    [self closeMMAP];
}

#pragma mark ## 上报日志 ##

/**
 * 将全部的日志文件上报服务器
 *      遍历日志文件所在的目录下的所有日志文件，然后上报服务器
 */
- (void)reportAllLogFileToServer {

    //这里可能在主线程调用， 切换线程压缩
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(wself) sself = wself;
        if( !sself ) {
            return;
        }
        NSFileManager * manager = [NSFileManager defaultManager];
        NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:[sself offLogDirectory]] objectEnumerator];
        NSString * fileName = nil;
        //文件集合
        NSMutableArray *paths = [NSMutableArray array];

        while ((fileName = [childFilesEnumerator nextObject]) != nil) {
            NSString *filePath = [[sself offLogDirectory] stringByAppendingString:fileName];
            [paths addObject:filePath];
        }
        if (paths.count > 0) {
            NSString* tempDir = NSTemporaryDirectory();
            NSDateFormatter *formatter = [NSDateFormatter new];
            [formatter setDateStyle:NSDateFormatterMediumStyle];
            [formatter setTimeStyle:NSDateFormatterShortStyle];
            [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
            NSString *dateTime = [formatter stringFromDate:[NSDate date]];
            //生成一个随机数，添加到文件名中
            NSInteger randomNumber = arc4random() % 102400;
            NSLog(@"randomNumber = %@", @(randomNumber));
            NSString *zipPath = [tempDir stringByAppendingString:[NSString stringWithFormat:@"offlineLog_%@_%@.zip", dateTime, @(randomNumber)]];
         
            BOOL isZipSuccess = [SSZipArchive createZipFileAtPath:zipPath  withFilesAtPaths:paths];
            if (isZipSuccess) {
                [sself reportLogFileToServerWithPath:zipPath deleteLocalFile:YES complete:nil];
            }
        }
        else {
            //无相关日志文件
            dispatch_main_async_safe( ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNoUploadFile object:nil];
            });
        }
    });
}

/**
 * 上报某一段时间区间内的日志文件
 *
 * @param beginDate 起始日期
 * @param endDate   结束日期
 */
- (void)reportLogFileToServerWithBeginDate:(NSString *)beginDate endDate:(NSString *)endDate {
    //生成日志文件名的格式为xxxx_offlog_1984-09-09-20-43-44.log
    //这里比较的时候，需要比较文件的前缀相同， 且日期在指定区间
    NSString *begin = @"0000-00-00";
    NSString *end = @"9999-99-99";
    
    if (beginDate) {
        begin = [NSString stringWithFormat:@"%@", beginDate];
    }
    if (endDate) {
        end = [NSString stringWithFormat:@"%@", endDate];
    }
    __weak typeof(self) wself = self;
    //因为设置文件名前缀在loggerQueue, 故先切换到loggerQueue线程，等logFileNamePrefix生效
    dispatch_async(self.loggerQueue, ^{
         //这里可能在主线程调用， 切换线程进行文件过滤，压缩
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __strong typeof(wself) sself = wself;
            if(  !sself ) {
                return;
            }
            NSFileManager * manager = [NSFileManager defaultManager];
            NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:[sself offLogDirectory]] objectEnumerator];
            NSString * fileName = nil;
            //文件集合
            NSMutableArray *paths = [NSMutableArray array];

            while ((fileName = [childFilesEnumerator nextObject]) != nil) {
                NSString* name = [fileName stringByDeletingPathExtension];
                NSArray* arr = [name componentsSeparatedByString:@"_"];
                if( !( arr.count == 3 || (_enableLogAppendMode  && arr.count == 2) ) ) {
                    continue;
                }
//              NSString* prefix = [arr objectAtIndex:0];
                NSString* dt = [arr objectAtIndex:(_enableLogAppendMode ? 1 : 2)];
//                if( ![prefix isEqualToString:LOGSAFESTRING(self.logFileNamePrefix)] ) {
//                    continue;
//                }
                if( dt.length < 10 ) {
                    continue;
                }
                NSString* date = [dt substringToIndex:10];
                if (strcmp([date UTF8String], [begin UTF8String]) >=  0 && strcmp([date UTF8String], [end UTF8String]) <= 0) {
                    NSString *filePath = [[sself offLogDirectory] stringByAppendingString:fileName];
                    [paths addObject:filePath];
                }
            }
            if (paths.count > 0) {
                NSString* tempDir = NSTemporaryDirectory();
                NSDateFormatter *formatter = [NSDateFormatter new];
                [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
                NSString *dateTime = [formatter stringFromDate:[NSDate date]];
                NSInteger randomNumber = arc4random() % 102400;
                NSLog(@"randomNumber = %@", @(randomNumber));
                NSString *zipPath = [tempDir stringByAppendingString:[NSString stringWithFormat:@"%@_offlineLog_%@_%@.zip", self.logFileNamePrefix, dateTime, @(randomNumber)]];
                BOOL isZipSuccess = [SSZipArchive createZipFileAtPath:zipPath  withFilesAtPaths:paths];
                if (isZipSuccess) {
                    [sself reportLogFileToServerWithPath:zipPath deleteLocalFile:YES complete:^(id response, NSError *error) {
//                        if( error == nil ) {
//                            id obj = [response objectForKey:@"code"];
//                            if( [obj isKindOfClass:[NSNumber class]] ) {
//                                NSNumber* num = obj;
//                                if( num.integerValue == 0 ) {
//                                    //删除文件
//                                    for(NSString* path in paths) {
//                                        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
//                                    }
//                                }
//                            }
//                        }
                    }];
                }
            } else {
                //无相关日志文件
                dispatch_main_async_safe( ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNoUploadFile object:nil];
                });
            }
        });
    });
}

- (void)reportLogFileToServerWithBeginDate:(NSString *)beginDate {
    [self reportLogFileToServerWithBeginDate:beginDate endDate:nil];
}

- (void)reportLogFileToServerWithEndDate:(NSString *)endDate {
    [self reportLogFileToServerWithBeginDate:nil endDate:endDate];
}


-(void)setLogFileNamePrefix:(NSString *)logFileNamePrefix {
//    __weak typeof(self) wself = self;
//    void(^block)(void) = ^{
//        __strong typeof(wself) sself = wself;
//        if( !sself ) {
//            return;
//        }
//
//        if( ![LOGSAFESTRING(logFileNamePrefix) isEqualToString:LOGSAFESTRING([super logFileNamePrefix])]
//           && ![[self getFileNamePrefix:self.currentFileName] isEqualToString:logFileNamePrefix] ){
//            if( self.enableLogAppendMode ) {
//                [self appendLog:@"\n\n---$$$$$$$$$$$$$$$$$---\n\n"];
//            }
//            [sself forceFlushCacheToLogFile];
//            [super setLogFileNamePrefix:logFileNamePrefix];
//            [sself createLogFile];
//        }
//    };
//    dispatch_queue_async_safe(self.loggerQueue,block);
    LOCK(_logFileSemphore);
    if( ![LOGSAFESTRING(logFileNamePrefix) isEqualToString:LOGSAFESTRING([super logFileNamePrefix])]
      && ![[self getFileNamePrefix:self.currentFileName] isEqualToString:logFileNamePrefix] ){
        [self writeCacheToLogFile:YES];
        if( self.enableLogAppendMode ) {
            [self appendLog:@"\n\n---$$$$$$$$$$$$$$$$$---\n\n"];
        }
       [super setLogFileNamePrefix:logFileNamePrefix];
       [self createLogFile];
   }
    UNLOCK(_logFileSemphore);
}

//添加分割行
- (void)appendLog:(NSString*)log {
    if( log.length == 0 ) {
        return;
    }
    LOCK(_logBufferSemphore);
    if( NULL != _log_buff ) {
        NSData* retData =  _logEncrypt ? [self encryptLog:log] : [log dataUsingEncoding:NSUTF8StringEncoding];
        _log_buff->Write([retData bytes], retData.length);
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval timeOffset = currentTime - self.lastLogWriteTime;
        if( _log_buff->GetData().Length() >= MAX_LOG_CACHE_SIZE/2  || timeOffset > MAX_LOG_WRITE_INTERVAL ) {
            [self writeCacheToLogFile:NO];
        }
    }
    UNLOCK(_logBufferSemphore);
}

-(void)initMMAPWithDir:(NSString*)dir {
    static bool mmapInited = NO;
    if( mmapInited ){
        return;
    }
    char mmap_file_path[512] = {0};
    snprintf(mmap_file_path, sizeof(mmap_file_path), "%s/offlineLog_%s.mmap2", [dir UTF8String], "default");
    bool use_mmap = false;
    NSString* mmapFilePath = [NSString stringWithUTF8String:mmap_file_path];
    if( [self openMMapFile:mmapFilePath fileSize:MAX_LOG_CACHE_SIZE] ) {
        _log_buff = new LogBuffer(_mmapBuffer, MAX_LOG_CACHE_SIZE);
        use_mmap = YES;
    }else{
        char* buffer = new char[MAX_LOG_CACHE_SIZE];
        _log_buff = new LogBuffer(buffer, MAX_LOG_CACHE_SIZE);
        use_mmap = NO;
    }
    if( _log_buff == NULL || NULL == _log_buff->GetData().Ptr() ) {
        if( use_mmap ) {
            [self closeMMapFile];
        }
        return;
    }
    AutoBuffer buffer;
    _log_buff->Flush(buffer);
    
    _log_close = NO;
    
    if( buffer.Ptr() ) {
        //writeToFile
        NSMutableString* logFilePath = [NSMutableString new];
        [logFilePath appendString:[self offLogDirectory]];
        [logFilePath appendString:self.currentFileName];
        [self write2File:logFilePath data:buffer.Ptr() size:buffer.Length()];
    }
    mmapInited = YES;
}

-(void)closeMMAP {
    if( _log_close ) {
        return;
    }
    _log_close = YES;
    
    //lock
    LOCK(self->_logBufferSemphore);
    if( _mmapBuffer != MAP_FAILED ) {
        memset(_mmapBuffer, 0, MAX_LOG_CACHE_SIZE);
        [self closeMMapFile];
    }else{
        if( _log_buff ) {
            delete[] (char*)((_log_buff->GetData()).Ptr());
        }
    }
    delete _log_buff;
    _log_buff = NULL;
    UNLOCK(self->_logBufferSemphore);
    
}

-(BOOL)openMMapFile:(NSString*)filePath fileSize:(NSUInteger)size {
    if( filePath.length == 0 || 0 == size ) {
        return NO;
    }
    BOOL isDir = YES;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir];
    FILE* fd = fopen([filePath UTF8String], "a+");
    if( fd == nil ) {
        return NO;
    }
    if( !exists || isDir ) {
        char* zeroData = new char[size];
        memset(zeroData, 0, size);
        if( size != fwrite(zeroData, sizeof(char), size, fd) ) {
            fclose(fd);
            delete[] zeroData;
            return NO;
        }
        delete[] zeroData;
    }
    _mmapBuffer = mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_FILE|MAP_SHARED, fileno(fd), 0);
    fclose(fd);
    return _mmapBuffer != MAP_FAILED;
}

-(void)closeMMapFile {
    if( _mmapBuffer != MAP_FAILED ) {
        munmap(_mmapBuffer, MAX_LOG_CACHE_SIZE);
        _mmapBuffer = MAP_FAILED;
    }
}

-(void)write2File:(NSString*)logPath data:(const void*)logData size:(NSUInteger)logSize {
    if( logData == NULL | logSize == 0  ){
        return;
    }
    NSData* data = [NSData dataWithBytes:logData length:logSize];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logPath];
    [fh seekToEndOfFile];
    [fh writeData:data];
    [fh closeFile];
}

#pragma mark ## others ##

- (void)dealloc {
    if (_timer) {
        dispatch_source_cancel(_timer);
    }
}

@end
