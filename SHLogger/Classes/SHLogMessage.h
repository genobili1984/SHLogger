//
//  SHLogMessage.h
//  SmartHome
//
//  Created by zhenwenl on 2017/7/5.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SHLogType.h"
#pragma mark -

@interface SHLogMessage : NSObject <NSCopying>

@property (assign, nonatomic) SHLogFlag  flag;     //日志等级
@property (assign, nonatomic) NSString * module;   //功能模块

@property (strong, nonatomic) NSString * filepath;  //文件全路径
@property (strong, nonatomic) NSString * filename;  //文件名
@property (strong, nonatomic) NSString * function;  //函数名称
@property (assign, nonatomic) NSUInteger line;      //所在行
@property (strong, nonatomic) NSString * message;   //消息串

@property (strong, nonatomic) NSDate   * timestamp; //时间戳
@property (strong, nonatomic) NSString * threadID;  //线程ID
@property (strong, nonatomic) NSString * threadName;//线程名

- (instancetype)initWithMessage:(NSString *)message
                           flag:(SHLogFlag)flag
                         module:(NSString *)module
                       filepath:(NSString *)filepath
                       function:(NSString *)function
                           line:(NSUInteger)line
                      timestamp:(NSDate *)timestamp;

+ (instancetype)newLogWithMessage:(NSString *)message
                             flag:(SHLogFlag)flag
                           module:(NSString *)module
                         filepath:(NSString *)filepath
                         function:(NSString *)function
                             line:(NSUInteger)line
                        timestamp:(NSDate *)timestamp;

//简化格式的日志条目
- (NSString *)simpleDescription;

//全格式的日志条目
- (NSString *)plainDescription;

@end
