//
//  SHLogManager.h
//  SmartHome
//
//  Created by zhenwenl on 2017/7/4.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SHLogConfig.h"


@class SHLogConfigModel;

@interface SHLogManager : NSObject

@property (nonatomic, strong) SHLogConfigModel* logConfig;

//需要过滤的模块名， 如果为空则默认输出所有的日志， 如不为空则输出指定的日志模块名日志
@property (nonatomic, strong) NSArray* filterLogModule;
/**
 * 单例对象
 */
+ (instancetype)sharedInstance;


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
           format:(NSString *)format, ...;


/**
 * 强制将缓存的日志写入到文件
 */
- (void)forceFlushCacheToFile;


/**
 是否写日志的开关

 @param enable YES:写日志， NO:不写日志
 日志开关默认打开
 */
-(void)enableLog:(BOOL)enable;



/**
 通过airdrop投送文件，此接口需要在UIViewController中调用, 且需要在主线程调用

 @param filePathArray 需要投送的文件路径列表
 @param packCompress 是否需要打包压缩， 如果需要，会将文件打包压缩成一个zip文件
 @param viewController UIActivityViewController需要在此viewController中present
 */
-(void)airDropFiles:(NSArray*)filePathArray  needPackCompress:(BOOL)packCompress viewController:(UIViewController*)viewController;


/**
 上传所有的离线日志
 */
-(void)uploadAllOfflineLogs;


/**
 上传从指定日期开始的日志

 @param beginDate 开始的日期， 格式必须为yyyy-MM-dd
 */
-(void)uploadOfflineLogsWithBeginDate:(NSString*)beginDate;


/**
 上传到指定日期结束的日志

 @param endDate 结束日期， 格式必须为yyyy-MM-dd
 */
-(void)uploadOfflineLogsWithEndDate:(NSString*)endDate;


/**
 上传指定日志区间内的日志

 @param beginDate 开始日期，格式必须为yyyy-MM-dd
 @param endDate 结束日期， 格式必须为yyyy-MM-dd
 */
-(void)uploadOfflineLogBetweenDate:(NSString*)beginDate end:(NSString*)endDate;



/**
 是否开启离线日志的追加模式， 默认不开启，开启后日志将不以UserID格式命名
 @param append 是否开启追加模式
 */
-(void)enableLogAppendMode:(BOOL)append;

/**
 是否开启离线日志加密， 默认不开启
 @param encrypt 是否开启追加模式
 */
-(void)enableOfflineLogEncrypt:(BOOL)encrypt;

/**
 抓取异常
 @param exception 异常结构
 */
+(void)caughtException:(NSException*)exception;

/**
 上传崩溃日志， 调用caughtException：接口后才会生成崩溃日志
 */
-(void)uploadAllCrashLogs;


/**
 设置实时日志的回调，这个实时传输的过程交个外面去处理，因为调用者很可能创建者建立了一个tcp, ucp连接。
 如果模块内部再建立一个tcp, ucp连接会不会冲突？
 
 @param uploadHandler 上传日志的回调
 block回调中data回调的类型可能是NSMutableData, NSString， 且回调不在主线程
 */
-(void)setRealtimeLogUploadHandle:(void (^)(id data))uploadHandler;


/**
 是否开启性能日志开关，默认关闭
 @param enable YES:开启， NO:关闭
 */
-(void)enableLogPerformance:(BOOL)enable;
/**
 生成性能日志

 @param moduleName 模块名，相同的模块同一天内会放在一个文件中
 @param logContent 日志内容
 */
-(void)logPerformanceWithModuleName:(NSString*)moduleName log:(NSString*)logContent;

/**
 * 压缩日志文件上报接口
 *
 * @param paths             日志文件全路径数组，文件目录+文件名
 * @param deleteLocalFile   是否删除本地日志文件
 * @param type              日志文件类型
 * @param complete          完成回调
 */
- (void)reportLogFileToServerWithPaths:(NSArray *)paths deleteLocalFile:(BOOL)deleteLocalFile type:(SHLogFileType)type complete:(SHUploadCompleteBlock)complete;


/**
  获取性能日志日志的文件路径列表， 空文件会被过滤, 按照文件时间倒序
  性能日志超过3天的会被删除
 @return 放回文日志文件全路径的列表
 */
+(NSArray*)performaceListFiles;

/**
 崩溃文件列表， 调用[SHLogManager caughtException:] 接口后才会生成崩溃日志
 返回崩溃文件列表
 */
+(NSArray*)crashLogFiles;

/**
 获取离线日志的文件路径列表， 空文件会被过滤, 按照文件时间倒叙
 * @param bNeedMoreThan0        文件大小是否需要大于0
 @return 文件路径数组
 */
+(NSArray*)offlineListFiles:(BOOL)bNeedMoreThan0;


/**
 设置日志用户数据， 设置后，用户日志在新生成日志文件后会写到文件中去

 @param dic 用户自定义数据
 */
-(void)setUsrOfflineLogData:(NSDictionary*)dic;


/**
 获取用户自定义日志数据

 @return 用户设置的日志数据
 */
-(NSDictionary*)getUsrOfflineLogData;


@end
