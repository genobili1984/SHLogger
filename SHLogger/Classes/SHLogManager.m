//
//  SHLogManager.m
//  SmartHome
//
//  Created by zhenwenl on 2017/7/4.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import "SHLogManager.h"
#import "SHLogConfig.h"
//#import "Reachability.h"
#import <Reachability/Reachability.h>
#import "SHRealTimeLogger.h"
#import "SHFileOfflineLogger.h"
#import "SHCrashLogger.h"
#import "SSZipArchive.h"
#import "SHPerformanceLogger.h"
#import "SHLogUploadMgr.h"
#import "SHLogMessage.h"


static NSString * const kSHLogManagerQueueLabel = @"SHLOGMANAGER_QUEUE"; //队列

@interface SHLogManager() {
    Reachability* _netReach;
    BOOL _enableLog;
    BOOL _enablePerformanceLog;
    dispatch_semaphore_t _semaphore;
}
//队列
@property (strong, nonatomic) dispatch_queue_t      logManagerQueue;

//网络状态
@property (nonatomic, assign)  NetworkStatus networkStatus;

//实时远程日志管理器
@property (strong, nonatomic) SHRealTimeLogger      *realtimeLogger;

//离线文件日志管理器
@property (strong, nonatomic) SHFileOfflineLogger   *fileOfflineLogger;
//崩溃日志管理器
@property (strong, nonatomic) SHCrashLogger         *crashLogger;

//性能收集日志
@property (nonatomic, strong) SHPerformanceLogger   *performanceLogger;

@end

@implementation SHLogManager


@synthesize filterLogModule = _filterLogModule;

#pragma mark ## initialize ##

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _logManagerQueue = dispatch_queue_create([kSHLogManagerQueueLabel UTF8String], DISPATCH_QUEUE_SERIAL);
        _realtimeLogger = [[SHRealTimeLogger alloc]init];
        _fileOfflineLogger = [[SHFileOfflineLogger alloc]init];
        _crashLogger = [[SHCrashLogger alloc]init];
        _performanceLogger  = [[SHPerformanceLogger alloc] init];
        
        _netReach = [Reachability reachabilityForInternetConnection];
        __weak typeof(self) wself = self;
        _netReach.reachableBlock = ^(Reachability*reach) {
            __strong typeof(wself) sself = wself;
            if( !sself ){
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                sself.networkStatus = reach.currentReachabilityStatus;
                if( sself->_logConfig ){
                    if( !sself->_logConfig.isDefaultLogConfig ) {
                        return;
                    }
                    if( reach.currentReachabilityStatus  ==  ReachableViaWWAN) {
                        sself->_logConfig.currentLogFlag = SHLogFlagWarning;
                        sself->_logConfig.currentLogFormatMode = SHLogFormatModeSimple;
                    }else if( reach.currentReachabilityStatus == ReachableViaWiFi ) {
                        sself->_logConfig.currentLogFlag = SHLogFlagVerbose;
                        sself->_logConfig.currentLogFormatMode = SHLogFormatModePlain;
                    }
                }
            });
        };
        _netReach.unreachableBlock = ^(Reachability*reach) {
            __strong typeof(wself) sself = wself;
            if( !sself ){
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                sself.networkStatus = reach.currentReachabilityStatus;
                if( sself->_logConfig ){
                    if( !sself->_logConfig.isDefaultLogConfig ) {
                        return;
                    }
                }
            });
        };
        self.networkStatus = _netReach.currentReachabilityStatus;
        [_netReach startNotifier];
        //初始化一个默认的logConfig配置
        _logConfig = [SHLogConfigModel new];
        _logConfig.currentReportMethod = SHLogReportMethodViaFile;
        _logConfig.isDefaultLogConfig = YES;
        _enableLog = YES;
        _enablePerformanceLog = NO;
        _semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

-(void)setLogConfig:(SHLogConfigModel *)logConfig {
    @synchronized(self){
        _logConfig = logConfig;
        
        self->_realtimeLogger.logFileNamePrefix = logConfig.logFileNamePrefix;
        self->_realtimeLogger.formatMode = logConfig.currentLogFormatMode;
        
        self->_fileOfflineLogger.uploadServerURL = logConfig.upLoadToServerURL;
        self->_fileOfflineLogger.logFileNamePrefix = logConfig.logFileNamePrefix;
        self->_fileOfflineLogger.formatMode = logConfig.currentLogFormatMode;
        self->_fileOfflineLogger.usrLogData = logConfig.userLogData;
        
        self->_crashLogger.logFileNamePrefix = logConfig.logFileNamePrefix;
        self->_crashLogger.uploadServerURL = logConfig.crashUploadServerURL;
        
        if( _logConfig.logFileNamePrefix.length > 0  && _logConfig.monitorLogFileNamePrefix.length > 0 && [_logConfig.logFileNamePrefix isEqualToString:_logConfig.monitorLogFileNamePrefix] ) {
            _logConfig.currentLogFlag = SHLogFlagVerbose;
            _logConfig.currentLogFormatMode = SHLogFormatModePlain;
        }
    }
}

-(void)setFilterLogModule:(NSArray *)filterLogModule {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    _filterLogModule = filterLogModule;
    dispatch_semaphore_signal(_semaphore);
}

-(NSArray*)filterLogModule {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    NSArray* fileterModules = [_filterLogModule copy];
    dispatch_semaphore_signal(_semaphore);
    return fileterModules;
}

//日志模块是否是需要过滤的模块
-(BOOL)checkLogModuleCanOutput:(NSString*)logModule {
    if( logModule.length == 0 ) {
        return YES;
    }
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    BOOL needOutput = NO;
    if( _filterLogModule.count == 0 ) {
        needOutput = YES;
    }else{
        needOutput = [_filterLogModule containsObject:logModule];
    }
    dispatch_semaphore_signal(_semaphore);
    return needOutput;
}

#pragma mark ## inner interface ##

- (void)logModule:(NSString *)module
             flag:(SHLogFlag)flag
             file:(const char *)file
         function:(const char *)function
             line:(NSUInteger)line
          message:(NSString *)message {
    //如果禁止输出日志， 直接return
    if( !_enableLog ) {
        return;
    }
    //生成SHLogMessage对象，根据上报形式选择
    SHLogMessage *logItem = [SHLogMessage newLogWithMessage:message
                                                       flag:flag
                                                     module:module
                                                   filepath:[NSString stringWithFormat:@"%s", file]
                                                   function:[NSString stringWithFormat:@"%s", function]
                                                       line:line
                                                  timestamp:nil];
#ifdef DEBUG
    //不是过滤的模块，直接console不打印
    if( [self checkLogModuleCanOutput:module] ){
        dispatch_async(_logManagerQueue, ^{
            printf("%s", [logItem.plainDescription UTF8String]);
            fflush(stdout);
        });
    }
#endif

    //日志等级过滤:低于当前日志等级则跳过
    if ( self.logConfig.currentLogFlag > flag ) {
        return;
    }

    //日志上报过滤:服务器上报开关关闭
    if ( !self.logConfig.isLogReportToServer ) {
        //TODO:保存为离线日志形式
        [self.fileOfflineLogger generateLogItem:logItem logConfig:self.logConfig networkStatus:self.networkStatus];
        return;
    }

    //上报实时日志
    if (self.logConfig.currentReportMethod & SHLogReportFlagRealTime) {
        [self.realtimeLogger generateLogItem:logItem logConfig:self.logConfig networkStatus:self.networkStatus];
    }
}

/**
 * 日志条目的生成
 *      调用该接口时不需要管内部逻辑
 *
 * @param module        日志功能模块
 * @param flag          日志等级标签
 * @param file          当前文件路径
 * @param function      当前函数
 * @param line          当前行
 * @param format        输出格式
 */

- (void)logModule:(NSString *)module
             flag:(SHLogFlag)flag
             file:(const char *)file
         function:(const char *)function
             line:(NSUInteger)line
           format:(NSString *)format, ... {
    
    //生成日志条目
    va_list args;
    
    if (format) {
        va_start(args, format);
        
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        
        va_end(args);
        
        va_start(args, format);
        
        [self logModule:module flag:flag file:file function:function line:line message:message];

        va_end(args);
    }
}


/**
 * 强制将缓存的日志写入到文件
 */
- (void)forceFlushCacheToFile {
    if (self.fileOfflineLogger) {
        [self.fileOfflineLogger forceFlushCacheToLogFile];
    }
    if( self.performanceLogger ) {
        [self.performanceLogger forceFlushCacheToLogFile];
    }
}


-(void)enableLog:(BOOL)enable {
    _enableLog = enable;
}

-(void)airDropFiles:(NSArray*)filePathArray needPackCompress:(BOOL)packCompress viewController:(UIViewController*)viewController {
#if    TARGET_OS_IPHONE
    [[SHLogManager sharedInstance] forceFlushCacheToFile];
    
    if( filePathArray.count == 0  || viewController == nil  ) {
        return;
    }
    NSMutableArray* urls = [NSMutableArray new];
    if( packCompress ) {
        NSString* tempDir = NSTemporaryDirectory();
        NSDateFormatter *formatter = [NSDateFormatter new];
        [formatter setDateStyle:NSDateFormatterMediumStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
        [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
        NSString *dateTime = [formatter stringFromDate:[NSDate date]];
        NSInteger randomNumber = arc4random() % 102400;
        NSLog(@"randomNumber = %@", @(randomNumber));
        NSString *zipPath = [tempDir stringByAppendingString:[NSString stringWithFormat:@"offlineLog_%@_%@.zip", dateTime, @(randomNumber)]];
        BOOL isDir = NO;
        if( [[NSFileManager defaultManager] fileExistsAtPath:zipPath isDirectory:&isDir] && !isDir ) {
            NSError* error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:zipPath error:&error];
        }
        BOOL isZipSuccess = [SSZipArchive createZipFileAtPath:zipPath  withFilesAtPaths:filePathArray];
        if (isZipSuccess) {
            NSURL* url = [NSURL fileURLWithPath:zipPath];
            [urls addObject:url];
        }
    }else{
        for( NSString* filePath in filePathArray ) {
            NSURL* url = [NSURL fileURLWithPath:filePath];
            [urls addObject:url];
        }
    }
    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil];
    // Present the controller
    [viewController presentViewController:controller animated:YES completion:nil];
#else
#endif
}

-(void)uploadAllOfflineLogs{
    [_fileOfflineLogger reportAllLogFileToServer];
}

-(void)uploadOfflineLogsWithBeginDate:(NSString *)beginDate {
    if( ![[self class] matchDate:beginDate] ) {
        return;
    }
    [_fileOfflineLogger reportLogFileToServerWithBeginDate:beginDate];
}

-(void)uploadOfflineLogsWithEndDate:(NSString *)endDate {
    if( ![[self class] matchDate:endDate] ) {
        return;
    }
    [_fileOfflineLogger reportLogFileToServerWithEndDate:endDate];
}

-(void)uploadOfflineLogBetweenDate:(NSString *)beginDate end:(NSString *)endDate {
    if( ![[self class] matchDate:beginDate] || ![[self class] matchDate:endDate] ) {
        return;
    }
    if (strcmp([beginDate UTF8String], [endDate UTF8String]) >= 0 ) {
        return;
    }
    [_fileOfflineLogger reportLogFileToServerWithBeginDate:beginDate endDate:endDate];
}

-(void)enableLogAppendMode:(BOOL)append  {
    _fileOfflineLogger.enableLogAppendMode = append;
}

-(void)enableOfflineLogEncrypt:(BOOL)encrypt {
    [_fileOfflineLogger encryptOfflineLog:encrypt];
}


+(void)caughtException:(NSException *)exception {
    NSString* prefix = [SHLogManager sharedInstance].logConfig.logFileNamePrefix;
    [SHCrashLogger uncaughtExceptionHandler:exception logNamePrefix:prefix];
}

-(void)uploadAllCrashLogs {
    [_crashLogger reportAllCrashLogFiles];
}

-(void)setRealtimeLogUploadHandle:(void (^)(id data))uploadHandler {
    _realtimeLogger.uploadBlock = uploadHandler;
}

-(void)enableLogPerformance:(BOOL)enable {
    _enablePerformanceLog = enable;
}

-(void)logPerformanceWithModuleName:(NSString *)moduleName log:(NSString *)logContent {
    if( moduleName.length == 0 || logContent.length == 0 ){
        return;
    }
    if( !_enablePerformanceLog ) {
        return;
    }
    [_performanceLogger  writePerformaceLog:moduleName log:logContent];
}

+(NSArray*)performaceListFiles {
    NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* dir = [NSString stringWithFormat:@"%@/%@", pathDocuments, kLogPerformanceDirectory];
    NSFileManager * manager = [NSFileManager defaultManager];
    NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:dir] objectEnumerator];
    NSString * fileName = nil;
    //文件集合
    NSMutableArray *paths = [NSMutableArray array];
    while ((fileName = [childFilesEnumerator nextObject]) != nil) {
        NSString *filePath = [dir stringByAppendingString:fileName];
        UInt64 srcFileSize = [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
        if( srcFileSize == 0 ){
            continue;
        }
        [paths addObject:filePath];
    }
    
    [paths sortUsingComparator:^NSComparisonResult(NSString* path1, NSString* path2) {
        NSError* error = nil;
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:&error];
        NSDate* createDate1 = attributes[NSFileCreationDate];
        attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path2 error:&error];
        NSDate* createDate2 = attributes[NSFileCreationDate];
        return [createDate2 compare:createDate1];
    }];
    return paths;
}

+(NSArray*)crashLogFiles {
    NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* dir = [NSString stringWithFormat:@"%@/%@", pathDocuments, kLogCrashFileCacheDirectory];
    NSFileManager * manager = [NSFileManager defaultManager];
    NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:dir] objectEnumerator];
    NSString * fileName = nil;
    //文件集合
    NSMutableArray *paths = [NSMutableArray array];
    while ((fileName = [childFilesEnumerator nextObject]) != nil) {
        NSString *filePath = [dir stringByAppendingString:fileName];
        UInt64 srcFileSize = [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
        if( srcFileSize == 0 ){
            continue;
        }
        [paths addObject:filePath];
    }
    
    [paths sortUsingComparator:^NSComparisonResult(NSString* path1, NSString* path2) {
        NSError* error = nil;
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:&error];
        NSDate* createDate1 = attributes[NSFileCreationDate];
        attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path2 error:&error];
        NSDate* createDate2 = attributes[NSFileCreationDate];
        return [createDate2 compare:createDate1];
    }];
    return paths;
}

+(NSArray*)offlineListFiles:(BOOL)bNeedMoreThan0 {
    NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* dir = [NSString stringWithFormat:@"%@/%@", pathDocuments, kLogOfflineFileCacheDirectory];
    NSFileManager * manager = [NSFileManager defaultManager];
    NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:dir] objectEnumerator];
    NSString * fileName = nil;
    //文件集合
    NSMutableArray *paths = [NSMutableArray array];
    while ((fileName = [childFilesEnumerator nextObject]) != nil) {
        NSString *filePath = [dir stringByAppendingString:fileName];
        UInt64 srcFileSize = [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
        if(bNeedMoreThan0 && srcFileSize == 0 ){
            continue;
        }
        [paths addObject:filePath];
    }
    
    [paths sortUsingComparator:^NSComparisonResult(NSString* path1, NSString* path2) {
        NSError* error = nil;
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:&error];
        NSDate* createDate1 = attributes[NSFileCreationDate];
        attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path2 error:&error];
        NSDate* createDate2 = attributes[NSFileCreationDate];
        return [createDate2 compare:createDate1];
    }];
    return paths;
}

/**
 * 压缩日志文件上报接口
 *
 * @param paths             日志文件全路径数组，文件目录+文件名
 * @param deleteLocalFile   是否删除本地日志文件
 * @param type              日志文件类型
 * @param complete          完成回调
 */
- (void)reportLogFileToServerWithPaths:(NSArray *)paths deleteLocalFile:(BOOL)deleteLocalFile type:(SHLogFileType)type complete:(SHUploadCompleteBlock)complete{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
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
            NSString * zipPrefix = @"";
            SHBaseLogger * logger = nil;
            switch (type) {
                case SHLogFileTypeOffline:
                    zipPrefix = @"offlineLog";
                    logger = self->_fileOfflineLogger;
                    break;
                case SHLogFileTypeCrash:
                    zipPrefix = @"crashLog";
                    logger = self->_crashLogger;
                    break;
                case SHLogFileTypePerformance:
                    zipPrefix = @"perfomanceLog";
                    logger = self->_performanceLogger;
                    break;
                case SHLogFileTypeRealTime:
                    
                    break;
                default:
                    break;
            }
            
            NSString *zipPath = [tempDir stringByAppendingString:[NSString stringWithFormat:@"%@_%@_%@.zip", zipPrefix,dateTime, @(randomNumber)]];
            BOOL isZipSuccess = [SSZipArchive createZipFileAtPath:zipPath  withFilesAtPaths:paths];
            if (isZipSuccess) {
                [logger reportLogFileToServerWithPath:zipPath deleteLocalFile:YES complete:^(id response, NSError *error) {
                    if( error == nil && deleteLocalFile ) {
                        for(NSString* path in paths) {
                            NSError* err = nil;
                            [[NSFileManager defaultManager] removeItemAtPath:path error:&err];
                        }
                    }
                    if( complete ) {
                        complete( response, error );
                    }
                }];
            }
        }
        else {
            
        }
    });
}

-(NSArray*)performaceListFiles {
    NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* dir = [NSString stringWithFormat:@"%@/%@", pathDocuments, kLogPerformanceDirectory];
    NSFileManager * manager = [NSFileManager defaultManager];
    NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:dir] objectEnumerator];
    NSString * fileName = nil;
    //文件集合
    NSMutableArray *paths = [NSMutableArray array];
    while ((fileName = [childFilesEnumerator nextObject]) != nil) {
        NSString *filePath = [dir stringByAppendingString:fileName];
        UInt64 srcFileSize = [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
        if( srcFileSize == 0 ){
            continue;
        }
        [paths addObject:filePath];
    }
    
    [paths sortUsingComparator:^NSComparisonResult(NSString* path1, NSString* path2) {
        NSError* error = nil;
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:&error];
        NSDate* createDate1 = attributes[NSFileCreationDate];
        attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path2 error:&error];
        NSDate* createDate2 = attributes[NSFileCreationDate];
        return [createDate2 compare:createDate1];
    }];
    return paths;
}

-(void)setUsrOfflineLogData:(NSDictionary *)dic {
    [_fileOfflineLogger setUsrLogData:dic];
}


-(NSDictionary*)getUsrOfflineLogData {
    return [_fileOfflineLogger usrLogData];
}


#pragma mark ## others ##
+(BOOL)matchDate:(NSString*)date {
    if( date.length == 0 ) {
        return NO;
    }
    NSString* pattern = @"^[0-9]{4}-[0-9]{2}-[0-9]{2}";
    NSError* error = nil;
    NSRegularExpression* expresson = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    if( error ||  !expresson ) {
        return NO;
    }
    NSUInteger countMatches = [expresson numberOfMatchesInString:date options:0 range:NSMakeRange(0, date.length)];
    return countMatches > 0;
}

- (void)dealloc {
    [_netReach stopNotifier];
}

@end
