//
//  SHLogMessage.m
//  SmartHome
//
//  Created by zhenwenl on 2017/7/5.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import "SHLogMessage.h"
#import <pthread.h>

#ifndef kCFCoreFoundationVersionNumber_iOS_8_0
#define kCFCoreFoundationVersionNumber_iOS_8_0 1140.10
#endif
#define USE_PTHREAD_THREADID_NP                (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0)

@implementation SHLogMessage

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

- (instancetype)initWithMessage:(NSString *)message
                           flag:(SHLogFlag)flag
                         module:(NSString *)module
                       filepath:(NSString *)filepath
                       function:(NSString *)function
                           line:(NSUInteger)line
                      timestamp:(NSDate *)timestamp {
    if (self = [super init]) {
        _flag = flag;
        _module = module;
        _filepath = filepath;
        _function = function;
        _line = line;
        _message = message;
        _timestamp = timestamp ?: [NSDate new];
        
        if (USE_PTHREAD_THREADID_NP) {
            __uint64_t tid;
            pthread_threadid_np(NULL, &tid);
            _threadID = [[NSString alloc] initWithFormat:@"%llu", tid];
        } else {
            _threadID = [[NSString alloc] initWithFormat:@"%x", pthread_mach_thread_np(pthread_self())];
        }
        _threadName   = [NSThread isMainThread] ? @"main thread" : (NSThread.currentThread.name ? NSThread.currentThread.name : @"work thread");
        
        
        _filename = [_filepath lastPathComponent];
    }
    return self;
}

+ (instancetype)newLogWithMessage:(NSString *)message
                             flag:(SHLogFlag)flag
                           module:(NSString *)module
                         filepath:(NSString *)filepath
                         function:(NSString *)function
                             line:(NSUInteger)line
                        timestamp:(NSDate *)timestamp {
    SHLogMessage *log = [[SHLogMessage alloc] initWithMessage:message flag:flag module:module filepath:filepath function:function line:line timestamp:timestamp];
    return log;
}


- (id)copyWithZone:(NSZone *)zone {
    SHLogMessage *message = [[SHLogMessage alloc] init];
    
    message.flag = _flag;
    message.module = _module;
    message.filepath = _filepath;
    message.filename = _filename;
    message.function = _function;
    message.line = _line;
    message.message = _message;
    message.timestamp = _timestamp;
    message.threadID = _threadID;
    message.threadName = _threadName;
    
    return message;
}

- (NSString *)description {
    NSString *datetime = @"2017-00-00 00:00:00";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    if (self.timestamp) {
        datetime = [formatter stringFromDate:self.timestamp];
    }

    //时间戳_模块_文件名_行数_函数名_线程_等级_具体消息
    //TODO:
    NSString *desc = nil;
    NSString * suffix = @"===================================\n";
    if (![self.message hasSuffix:@"\n"]) {
        desc = [NSString stringWithFormat:@"%@ [%@] [%@:%tu,%@] [ThreadId:%@] [ThreadName:%@] [Level:%tu]: %@\n%@", datetime, self.module, self.filename, self.line, self.function, self.threadID,self.threadName, self.flag, self.message,suffix];
    } else {
        desc = [NSString stringWithFormat:@"%@ [%@] [%@:%tu,%@] [ThreadId:%@] [ThreadName:%@] [Level:%tu]: %@%@", datetime, self.module, self.filename, self.line, self.function, self.threadID,self.threadName, self.flag, self.message,suffix];
    }
    return desc;
}

/**
 * 简化格式的字符串
 */
- (NSString *)simpleDescription {
    NSString *datetime = @"2017-00-00 00:00:00";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    if (self.timestamp) {
        datetime = [formatter stringFromDate:self.timestamp];
    }

    //时间戳 [模块] [文件名:行数]: 具体消息
    NSString * suffix = @"===================================\n";
    NSString *desc = [NSString stringWithFormat:@"%@ [%@] [%@:%tu]: %@\n%@", datetime, self.module, self.filename, self.line, self.message,suffix];
    if (![self.message hasSuffix:@"\n"]) {
        desc = [NSString stringWithFormat:@"%@\n", desc];
    }
    

    return desc;
}

- (NSString *)plainDescription {
    return [self description];
}


@end
