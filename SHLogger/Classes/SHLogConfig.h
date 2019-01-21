//
//  SHLogStrategyManager.h
//  SmartHome
//
//  Created by zhenwenl on 2017/7/7.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SHLogType.h"

#pragma mark -
@interface SHLogConfigModel : NSObject

//是否上传到服务器，默认NO，只在本地生成离线日志， 设置为YES, 则同时必须设置upLoadToServerURL为有效值
@property (assign, atomic) BOOL isLogReportToServer;

//要上传的服务器路径, 如果需要上传到服务器，必须是有效地址， 且isLogReportToServer需置为YES
@property (atomic, copy) NSString*  upLoadToServerURL;

//当前日志模式, 默认是SHLogFormatModePlain
@property (assign, atomic) SHLogFormatMode currentLogFormatMode;

//当前日志标记， 日志标记值低于此会被忽略, 默认值SHLogFlagVerbose
@property (assign, atomic) SHLogFlag currentLogFlag;

//当前日志上报方法：远程调试，沙盒文件，or两者兼有。
@property (assign, atomic) SHLogReportMethod currentReportMethod;

//设置日志文件名前缀, 此属性设置便于查找日志， 如果以用户ID为文件前缀
@property (atomic, copy)  NSString* logFileNamePrefix;

//crash文件的上传地址
@property (atomic, copy) NSString*  crashUploadServerURL;

//设置当前监控文件前缀， 如果此字段与logFileNamePrefix相同，则生成所有级别的日志
@property (atomic, copy) NSString*  monitorLogFileNamePrefix;

//是否是默认的日志配置， 于此对应的是服务器下发的日志配置， 服务器下发的日志配置， 网络变化的情况下一些属性不做变更
@property (atomic, assign) BOOL isDefaultLogConfig;

//用户自定义的日志数据， NSDictionary类型
@property (atomic, strong)  NSDictionary* userLogData;

@end

