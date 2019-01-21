//
//  SHPerformanceLogger.h
//  AFNetworking
//
//  Created by Genobili Mao on 2018/5/31.
//

#import <Foundation/Foundation.h>

@interface SHPerformanceLogger : NSObject

-(void)writePerformaceLog:(NSString*)moduleName log:(NSString*)log;
/**
 * 强制将缓存的日志写入到文件
 */
- (void)forceFlushCacheToLogFile;

@end
