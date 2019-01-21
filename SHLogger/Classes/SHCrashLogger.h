//
//  SHCrashLogger.h
//  SmartHome
//
//  Created by zhenwenl on 2017/7/9.
//  Copyright © 2017年 EverGrande. All rights reserved.
//
//  注意：
//      crash_log的文件名定义为:"uid_offline_crashlog_timestamp"(年月日时分秒)，举例："u1234567890_offline_crashlog_20170709000000.log"
//

#import "SHFileOfflineLogger.h"

@class NSException;

@interface SHCrashLogger : SHFileOfflineLogger

+(void)uncaughtExceptionHandler:(NSException*)exception logNamePrefix:(NSString*)logNamePrefix;

/**
 * 上报crash日志文件
 */
- (void)reportAllCrashLogFiles;

@end
