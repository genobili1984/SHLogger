# SHLogger

[![CI Status](https://img.shields.io/travis/genobili/SHLogger.svg?style=flat)](https://travis-ci.org/genobili/SHLogger)
[![Version](https://img.shields.io/cocoapods/v/SHLogger.svg?style=flat)](https://cocoapods.org/pods/SHLogger)
[![License](https://img.shields.io/cocoapods/l/SHLogger.svg?style=flat)](https://cocoapods.org/pods/SHLogger)
[![Platform](https://img.shields.io/cocoapods/p/SHLogger.svg?style=flat)](https://cocoapods.org/pods/SHLogger)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

SHLogger is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SHLogger'
```

## Usage

### 设置日志配置,  具体各个属性的取值及意义见SHLogCof ig.h
``` 
SHLogConfigModel* config = [SHLogConfigModel new];
config.isLogReportToServer = NO;  
config.currentLogFormatMode = SHLogFormatModePlain;
config.currentLogFlag = SHLogFlagVerbose;
config.currentReportMethod =  SHLogReportMethodViaFile;
config.logFileNamePrefix = @"1111111";
config.upLoadToServerURL = @"http://iot-dev-upgrade-center-tice.egtest.cn:9000/file_upload/";
SHLogConfig(config);

```

###  写日志
```
SHLogVerbose(@"ModuleName", @"server response is %@", @"dateResponse");
SHLogDebug(@"ModuleName", @"send request data is %@", @"hello");
SHLogInfo(@"ModuleName", @"%@, %@", @"ererer", @(5555555));
SHLogWarn(@"ModuleName", @"waring content = @%", @"hello");
SHLogError(@"ModuleName", @"server response error data = %@", @"{response = 555555555555}");
```

### 强制写离线日志， 由于日志会缓存在一个队列中，每隔数秒或是缓存达到1K才会写日志
```
SHLogFlushCacheToFile;
```

### 日志开关，日志默认是开启的， 禁止写日志需要手动调用
```
SHLogEnable(NO);
```

###  获取离线日志列表， 空文件会被过滤， 按照文件创建时间倒叙返回
```
NSArray* offlineLogFileArray = [[SHLogManager sharedInstance] offlineListFiles];
```

### 通过Airdrop, 分享指定的文件到其它设备
```
 [[SHLogManager sharedInstance] airDropFiles:filePathArray needPackCompress:YES viewController:self];
```

### 上传所有的离线文件到服务器
```
[[SHLogManager sharedInstance] uploadAllOfflineLogs];
```

### 上传从某天之后（包括当天）的离线日志
```
[[SHLogManager sharedInstance] uploadOfflineLogsWithBeginDate:beginDate];
```

### 上传某天之前（包括当天）的离线日志
```
[[SHLogManager sharedInstance] uploadOfflineLogsWithEndDate:endDate];
```

###  上传一段区间内的离线日志
```
[[SHLogManager sharedInstance] uploadOfflineLogBetweenDate:beginDate end:endDate];
```

### 生成崩溃日志
```
[SHLogManager sharedInstance] caughtException:exception];
```

### 崩溃日志列表， 按照创建时间倒叙返回
```
NSArray* crashLogFileArray = [[SHLogManager sharedInstance] crashLogFiles];
```

### 上传所有崩溃日志
```
[[SHLogManager sharedInstance] uploadAllCrashLogs];
```

### 设置实时日志上传回调， 此回调真正实现数据的上传
```
[[SHLogManager sharedInstance] setRealtimeLogUploadHandle: ^(id data) {
    //do upload log data
}];
```

### 设置性能日志开关， 默认关闭，不写文件
```
   [[SHLogManager sharedInstance] enableLogPerformance:YES]
```

### 写性能日志, 第一个参数是分类名， 第二个参数日志内容
```
   [[SHLogManager sharedInstance] logPerformanceWithModuleName:@"TV" log:@"slkdfjsjlkfjskfskfjskf"];
```

### 性能日志列表， 按照创建时间倒叙返回
```
NSArray*  logFileArray = [[SHLogManager sharedInstance] performaceListFiles];
```



## Author

genobili, genobili@evergrande.cn

## License

SHLogger is available under the MIT license. See the LICENSE file for more info.
