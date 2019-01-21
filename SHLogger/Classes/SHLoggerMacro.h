//
//  SHLoggerMacro.h
//  SmartHome
//
//  Created by zhenwenl on 2017/7/4.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#ifndef SHLoggerMacro_h
#define SHLoggerMacro_h

#import "SHLogManager.h"

#ifndef SHLogFlushCacheToFile
#define SHLogFlushCacheToFile   [[SHLogManager sharedInstance] forceFlushCacheToFile]
#endif

#ifndef SHLOGGER_MACRO
#define SHLOGGER_MACRO(flg, func, module, frmt, ...)                      \
        [[SHLogManager sharedInstance] logModule : module                  \
                                            flag : flg                     \
                                            file : __FILE__                \
                                        function : func                    \
                                            line : __LINE__                \
                                          format : (frmt), ##__VA_ARGS__]
#endif


#ifndef SHLogError
#define SHLogError(module, format, ...)     SHLOGGER_MACRO(SHLogFlagError, __PRETTY_FUNCTION__, module, format, ##__VA_ARGS__)
#endif

#ifndef SHLogWarn
#define SHLogWarn(module, format, ...)      SHLOGGER_MACRO(SHLogFlagWarning, __PRETTY_FUNCTION__, module, format, ##__VA_ARGS__)
#endif

#ifndef SHLogInfo
#define SHLogInfo(module, format, ...)      SHLOGGER_MACRO(SHLogFlagInfo, __PRETTY_FUNCTION__, module, format, ##__VA_ARGS__)
#endif

#ifndef SHLogDebug
#define SHLogDebug(module, format, ...)     SHLOGGER_MACRO(SHLogFlagDebug, __PRETTY_FUNCTION__, module, format, ##__VA_ARGS__)
#endif

#ifndef SHLogVerbose
#define SHLogVerbose(module, format, ...)   SHLOGGER_MACRO(SHLogFlagVerbose, __PRETTY_FUNCTION__, module, format, ##__VA_ARGS__)
#endif

#ifndef SHLog
#define SHLog(module, format, ...)          SHLOGGER_MACRO(SHLogFlagVerbose, __PRETTY_FUNCTION__, module, format, ##__VA_ARGS__)
#endif

#ifndef SHLogConfig
#define SHLogConfig(logConfig)   \
    [[SHLogManager sharedInstance] setLogConfig:logConfig]
#endif

#ifndef SHLogEnable
#define SHLogEnable(enable)  \
        [[SHLogManager sharedInstance] enableLog:enable]
#endif

#ifndef SHUploadAllOfflineLogs
#define SHUploadAllOfflineLogs  \
        [[SHLogManager sharedInstance] uploadAllOfflineLogs]
#endif

#ifndef SHUploadOfflineLogWithBeginDate
#define SHUploadOfflineLogWithBeginDate(beginDate)   \
    [[SHLogManager sharedInstance] uploadOfflineLogsWithBeginDate:beginDate]
#endif

#ifndef SHUploadOfflineLogWithEndDate
#define SHUploadOfflineLogWithEndDate(endDate)   \
    [[SHLogManager sharedInstance] uploadOfflineLogsWithEndDate:endDate]
#endif

#ifndef SHUploadOfflineLogBetweenDate
#define SHUploadOfflineLogBetweenDate(beginDate, endDate)   \
[[SHLogManager sharedInstance] uploadOfflineLogBetweenDate:beginDate end:endDate]
#endif

#ifndef SHLogPerformance
#define SHLogPerformance(moduleName, logContent) \
    [[SHLogManager sharedInstance] logPerformanceWithModuleName:moduleName log:logContent]
#endif


#endif /* SHLoggerMacro_h */
