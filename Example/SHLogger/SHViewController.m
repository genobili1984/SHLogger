//
//  SHViewController.m
//  SHLogger
//
//  Created by genobili on 05/17/2018.
//  Copyright (c) 2018 genobili. All rights reserved.
//

#import "SHViewController.h"
#import "SHLoggerMacro.h"
#import "SHLogFileListViewController.h"


@interface SHViewController (){
    dispatch_queue_t _loggerQueuer1;
    dispatch_queue_t _loggerQueuer2;
    dispatch_queue_t _loggerQueuer3;
    dispatch_queue_t _loggerQueuer4;
    dispatch_queue_t _loggerQueuer5;
}

@property (strong, nonatomic) dispatch_source_t timer;

@end

@implementation SHViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    
}

-(void)configLog {
    SHLogConfigModel* config = [SHLogConfigModel new];
    config.isLogReportToServer = NO;
    config.currentLogFormatMode = SHLogFormatModePlain;
    config.currentLogFlag = SHLogFlagVerbose;
    config.currentReportMethod =  SHLogReportMethodViaFile;
    config.logFileNamePrefix = @"34545";
    config.upLoadToServerURL = @"http://iot-dev-upgrade-center-tice.egtest.cn:9000/file_upload/";
    //config.upLoadToServerURL = @"https://httpbin.org/post";
    config.userLogData = @{@"current_env":@"developt_text"};
    SHLogConfig(config);
    
    //SHLogEnable(NO);
}


- (IBAction)resetLogConifg:(id)sender {
//    SHLogConfigModel* config = [SHLogConfigModel new];
//    config.isLogReportToServer = NO;
//    config.currentLogFormatMode = SHLogFormatModePlain;
//    config.currentLogFlag = SHLogFlagVerbose;
//    config.currentReportMethod =  SHLogReportMethodViaFile;
//    config.logFileNamePrefix = @"1111111";
//    config.upLoadToServerURL = @"http://iot-dev-upgrade-center-tice.egtest.cn:9000/file_upload/";
//    //config.upLoadToServerURL = @"https://httpbin.org/post";
//    SHLogConfig(config);
    
    [[SHLogManager sharedInstance] enableOfflineLogEncrypt:YES];
    
    SHLogVerbose(@"UIModule", @"server response is %@", @"4544454545fggfgsdfgdsfsfsfsfsfsdfjsd;lgjslgjds;lgkj");
    SHLogDebug(@"UIModule", @"send request data is %@", @"skdjgsdljgsdlkjgdlskjgsdlkjglskdjglsdkjgsldkgjsdlkgjsl");
    SHLogInfo(@"UIModule", @"%@, %@", @"ererer", @(5555555));
    SHLogWarn(@"UIModule", @"waring conteng = @%", @"hkljslkdfgjsdljgsdlkjgsdlkjgsdlkjgsdl;kgjs;dlkgjsdlkgjlkdjgsdlk");
    SHLogError(@"UIModule", @"server response error data = %@", @"{response = 555555555555}");
}


- (IBAction)btnClick:(id)sender {
    //[self configLog];
     [[SHLogManager sharedInstance] enableOfflineLogEncrypt:NO];
    SHLogVerbose(@"NetworkModule", @"server response is %@", @"sldjfklsjlsf");
    SHLogDebug(@"NetworkModule", @"send request data is %@", @"dklfjksdjfsjflksjfssfsfs");
    SHLogInfo(@"NetworkModule", @"%@, %@", @"ererer", @(333));
    SHLogWarn(@"NetworkModule", @"waring conteng = @%", @"woiruwoiruwoiruwioruwe");
    SHLogError(@"NetworkModule", @"server response error data = %@", @"{ret = -1}");
}

- (IBAction)airDropFiles:(id)sender {
    SHLogFileListViewController* controller = [[SHLogFileListViewController alloc] initWithNibName:@"SHLogFileListViewController" bundle:nil];
    [self.navigationController pushViewController:controller animated:YES];
}


- (IBAction)multiThreadTest:(id)sender {
    
    
    if(  !_loggerQueuer1 ){
         _loggerQueuer1 = dispatch_queue_create([@"multihreadtest1" UTF8String], NULL);
    }
    if(  !_loggerQueuer2 ){
        _loggerQueuer2 = dispatch_queue_create([@"multihreadtest2" UTF8String], NULL);
    }
    if(  !_loggerQueuer3 ){
        _loggerQueuer3 = dispatch_queue_create([@"multihreadtest3" UTF8String], NULL);
    }
    if(  !_loggerQueuer4 ){
        _loggerQueuer4 = dispatch_queue_create([@"multihreadtest4" UTF8String], NULL);
    }
    if(  !_loggerQueuer5 ){
        _loggerQueuer5 = dispatch_queue_create([@"multihreadtest5" UTF8String], NULL);
    }
    
    __weak typeof(self) wself = self;
    if( !_timer ) {
       [self configLog];
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, nil);
        dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), 0.1 * NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(_timer, ^{
            __strong typeof(wself) sself = self;
            if( !sself) {
                return;
            }
            dispatch_async(sself->_loggerQueuer1, ^{
                SHLogVerbose(@"loggerQueue1", @"server response is %@", @"loggerQueue1loggerQueue1loggerQueue1loggerQueue1loggerQueue1loggerQueue1");
                SHLogDebug(@"loggerQueue1", @"send request data is %@", @"loggerQueue1loggerQueue1loggerQueue1loggerQueue1loggerQueue1");
                SHLogInfo(@"loggerQueue1", @"%@, %@", @"ererer", @(333));
                SHLogWarn(@"loggerQueue1", @"waring conteng = @%", @"loggerQueue1loggerQueue1loggerQueue1loggerQueue1");
                SHLogError(@"loggerQueue1", @"server response error data = %@", @"{ret = -1}");
            });
            dispatch_async(sself->_loggerQueuer2, ^{
                SHLogVerbose(@"loggerQueue2", @"server response is %@", @"loggerQueue2loggerQueue2loggerQueue2loggerQueue2loggerQueue2");
                SHLogDebug(@"loggerQueue2", @"send request data is %@", @"loggerQueue2loggerQueue2loggerQueue2loggerQueue2");
                SHLogInfo(@"loggerQueue2", @"%@, %@", @"ererer", @(333));
                SHLogWarn(@"loggerQueue2", @"waring loggerQueue2loggerQueue2loggerQueue2 = @%", @"loggerQueue1loggerQueue1loggerQueue1loggerQueue1");
                SHLogError(@"loggerQueue2", @"server response error data = %@", @"{loggerQueue2loggerQueue2loggerQueue2 = -1}");
            });
            dispatch_async(sself->_loggerQueuer3, ^{
                SHLogVerbose(@"loggerQueue3", @"server response is %@", @"loggerQueue3loggerQueue3loggerQueue3");
                SHLogDebug(@"loggerQueue3", @"send request data is %@", @"loggerQueue3loggerQueue3loggerQueue3loggerQueue3loggerQueue3");
                SHLogInfo(@"loggerQueue3", @"%@, %@", @"ererer", @(333));
                SHLogWarn(@"loggerQueue3", @"waring loggerQueue3loggerQueue3 = @%", @"loggerQueue3loggerQueue3loggerQueue3loggerQueue3");
                SHLogError(@"loggerQueue3", @"server response error data = %@", @"loggerQueue3loggerQueue3loggerQueue3");
            });
            dispatch_async(sself->_loggerQueuer4, ^{
                SHLogVerbose(@"loggerQueue4", @"server response is %@", @"loggerQueue4");
                SHLogDebug(@"loggerQueue4", @"send request data is %@", @"loggerQueue4");
                SHLogInfo(@"loggerQueue4", @"%@, %@", @"ererer", @(333));
                SHLogWarn(@"loggerQueue4", @"waring loggerQueue4 = @%", @"loggerQueue1loggerQueue1loggerQueue1loggerQueue1");
                SHLogError(@"loggerQueue4", @"server response error data = %@", @"{loggerQueue4 = -1}");
            });
            dispatch_async(sself->_loggerQueuer5, ^{
                SHLogVerbose(@"loggerQueue5", @"server response is %@", @"loggerQueue5loggerQueue5loggerQueue5loggerQueue5");
                SHLogDebug(@"loggerQueue5", @"send request data is %@", @"loggerQueue5loggerQueue5loggerQueue5");
                SHLogInfo(@"loggerQueue5", @"%@, %@", @"ererer", @(333));
                SHLogWarn(@"loggerQueue5", @"waring loggerQueue5loggerQueue5 = @%", @"loggerQueue1loggerQueue1loggerQueue1loggerQueue1");
                SHLogError(@"loggerQueue5", @"server loggerQueue5loggerQueue5 error data = %@", @"{ret = -1}");
            });
        });
        dispatch_resume(_timer);
    }
}


- (IBAction)stopMultiThreadLog:(id)sender {
    if( _timer ) {
        dispatch_cancel(_timer);
        _timer = nil;
    }
}

- (IBAction)uploadOfflineLog:(id)sender {
    [self configLog];
    SHUploadAllOfflineLogs;
    //SHUploadOfflineLogBetweenDate(@"2018-05-20", @"2018-05-23");
    //SHUploadOfflineLogWithBeginDate(@"2018-05-21");
    //SHUploadOfflineLogWithEndDate(@"2018-05-21");
}

- (IBAction)performanceLogBtnClick:(id)sender {
    [[SHLogManager sharedInstance] enableLogPerformance:YES];
    [[SHLogManager sharedInstance] logPerformanceWithModuleName:@"TV" log:@"slkdfjsjlkfjskfskfjskf"];
    [[SHLogManager sharedInstance] logPerformanceWithModuleName:@"Light" log:@"2323333333333333333"];
    [[SHLogManager sharedInstance] logPerformanceWithModuleName:@"AirCondition" log:@"444444444444444444444"];
    [[SHLogManager sharedInstance] logPerformanceWithModuleName:@"Fridge" log:@"55555555555555555555555555"];
    [[SHLogManager sharedInstance] logPerformanceWithModuleName:@"WashMachine" log:@"6666666666666666"];
}


@end
