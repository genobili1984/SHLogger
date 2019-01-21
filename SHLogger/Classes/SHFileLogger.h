//
//  SHFileLogger.h
//  SmartHome
//
//  Created by zhenwenl on 2017/7/3.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import "SHBaseLogger.h"

@class SHLogMessage;

@interface SHFileLogger : SHBaseLogger <SHLogProtocol>

- (void)forceFlushCacheToLogFile;

@end
