//
//  SHRealTimeLogger.h
//  SmartHome
//
//  Created by zhenwenl on 2017/7/3.
//  Copyright © 2017年 EverGrande. All rights reserved.
//

#import "SHBaseLogger.h"

typedef void (^realTimeLoguploadBlock)(id date);

@class SHLogMessage;

@interface SHRealTimeLogger : SHBaseLogger <SHLogProtocol>

@property (nonatomic, copy) realTimeLoguploadBlock uploadBlock;

@end
