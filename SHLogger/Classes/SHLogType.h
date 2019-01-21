//
//  SHLogType.h
//  Pods
//
//  Created by genobili on 5/19/18.
//
//
#ifndef SHLogType_h
#define SHLogType_h

#import "SHLogType.h"

//无相关日志文件通知
static NSString *const kNotificationNoUploadFile = @"kNotificationNoUploadFile";

//崩溃日志缓存所在目录路径
static NSString * const kLogCrashFileCacheDirectory = @"/log_crash_files/";
//日志缓存所在目录路径
static NSString * const kLogFileCacheDirectory = @"/log_temp_files/";
//离线日志所在目录路径
static NSString * const kLogOfflineFileCacheDirectory = @"/log_offline_files/";
//性能日志所在目录路径
static NSString * const kLogPerformanceDirectory  = @"/log_performance_files/";

typedef void(^SHUploadCompleteBlock)(id response,NSError * error);


typedef NS_ENUM(NSInteger, SHLogFileType) {
    SHLogFileTypeOffline        = 0,
    SHLogFileTypeCrash          = 1,
    SHLogFileTypePerformance    = 2,
    SHLogFileTypeRealTime       = 3
};

//日志等级标签
typedef NS_OPTIONS(NSUInteger, SHLogFlag) {
    SHLogFlagOff          = 0,
    SHLogFlagVerbose      = (1 << 0),
    SHLogFlagDebug        = (1 << 1),
    SHLogFlagInfo         = (1 << 2),
    SHLogFlagWarning      = (1 << 3),
    SHLogFlagError        = (1 << 4)
};

//
//typedef NS_ENUM(NSUInteger, SHLogLevel) {
//    SHLogLevelOff       = 0,
//    SHLogLevelError     = (SHLogFlagError),
//    SHLogLevelWarning   = (SHLogLevelError   | SHLogFlagWarning),
//    SHLogLevelInfo      = (SHLogLevelWarning | SHLogFlagInfo),
//    SHLogLevelDebug     = (SHLogLevelInfo    | SHLogFlagDebug),
//    SHLogLevelVerbose   = (SHLogLevelDebug   | SHLogFlagVerbose),
//};

//上报日志方式
typedef NS_OPTIONS(NSUInteger, SHLogReportFlag) {
    SHLogReportFlagRealTime = (1 << 0),  //实时上报
    SHLogReportFlagViaFile  = (1 << 1)   //存储在文件后定期上报
};

typedef NS_ENUM(NSUInteger, SHLogReportMethod) {
    SHLogReportMethodRealTime   = SHLogReportFlagRealTime,    //实时上报
    SHLogReportMethodViaFile    = SHLogReportFlagViaFile,     //存储在文件后定期上报
    SHLogReportMethodAll        = (SHLogReportFlagRealTime | SHLogReportFlagViaFile) //所有形式的都上报
};

//日志格式
typedef NS_ENUM(NSUInteger, SHLogFormatMode) {
    SHLogFormatModePlain    = 0,
    SHLogFormatModeSimple   = 1
};

#endif /* SHLogType_h */
