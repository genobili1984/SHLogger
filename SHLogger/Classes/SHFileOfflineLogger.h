//
//  SHFileOfflineLogger.h
//  SmartHome
//
//  Created by zhenwenl on 2017/7/9.
//  Copyright © 2017年 EverGrande. All rights reserved.
//
//  注意：
//      offline_log的文件名定义为:"uid_offlog_timestamp"(年月日时分秒)，举例："1234567890_offlog_2017-07-09-00-00-00.log"
//
#import "SHBaseLogger.h"

@interface SHFileOfflineLogger : SHBaseLogger <SHLogProtocol>

//@property (assign, nonatomic) BOOL isToReportToServer;


//为了体现日志的连续性，可以设置此属性为YES, 则本地日志文件名不包含用户ID信息，日志文件民为appendOffLog_YYYY-MM-dd-HH-00-00.log
//日志文件每一个小时创建一个， 如果存在则日志追加， 发布时候此开关应该关闭
//此属性默认为NO
@property (assign, nonatomic) BOOL enableLogAppendMode;

@property (nonatomic, strong) NSDictionary* usrLogData;

-(void)encryptOfflineLog:(BOOL)encrypt;

/**
 * 将全部的离线日志文件上报服务器
 */
- (void)reportAllLogFileToServer;


/**
 * 上报某段时间内的日志到服务器
 */
- (void)reportLogFileToServerWithBeginDate:(NSString *)beginDate endDate:(NSString *)endDate;
 
- (void)reportLogFileToServerWithBeginDate:(NSString *)beginDate;

- (void)reportLogFileToServerWithEndDate:(NSString *)endDate;


/**
 * 强制将缓存的日志写入到文件
 */
- (void)forceFlushCacheToLogFile;

@end
