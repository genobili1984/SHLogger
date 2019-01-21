//
//  SHShowLogViewController.m
//  SmartVillage
//
//  Created by genobili on 5/25/18.
//  Copyright © 2018 administrator. All rights reserved.
//

#import "SHShowLogViewController.h"
#import "SHFilterLogConditionViewController.h"

@interface SHShowLogViewController (){
    NSString* _filterLogModule;
    NSString* _filterLogLevel;
    NSString* _filterLogContent;
}

@property (weak, nonatomic) IBOutlet UITextView *textView;


@property (nonatomic, strong) NSMutableDictionary* indexModuleDic;  //行数->模块名
@property (nonatomic, strong) NSMutableDictionary* indexContentDic; //行数->内容

@property (nonatomic, strong) NSMutableArray* matchedArray;
@property (weak, nonatomic) IBOutlet UILabel *moduleLabel;
@property (weak, nonatomic) IBOutlet UILabel *levelLabel;

@property (weak, nonatomic) IBOutlet UIButton *filterBtn;

@property (weak, nonatomic) IBOutlet UITextField *editTextview;

@property (nonatomic, strong) NSMutableArray* moduleNameArray;
@end

@implementation SHShowLogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.indexModuleDic = [NSMutableDictionary new];
    self.indexContentDic = [NSMutableDictionary new];
    self.matchedArray = [NSMutableArray new];
    self.moduleNameArray = [NSMutableArray new];
    [self loadLogWithPath:self.logFilePath];
    self.textView.editable = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)selectModuleNameClick:(id)sender {
    SHFilterLogConditionViewController* controller = [[SHFilterLogConditionViewController alloc] initWithNibName:@"SHFilterLogConditionViewController" bundle:nil];
    controller.dataList = self.moduleNameArray;
    controller.selectedValue = _filterLogModule;
    __weak typeof(self) wself = self;
    controller.handler = ^(NSString *moduleName) {
        __strong typeof(wself) sself = wself;
        if( !sself ) {
            return;
        }
        if( moduleName.length > 0  ){
           sself->_filterLogModule = moduleName;
            sself->_moduleLabel.text = moduleName;
        }
    };
    [self.navigationController pushViewController:controller animated:YES];
}

- (IBAction)selectLevelClick:(id)sender {
    SHFilterLogConditionViewController* controller = [[SHFilterLogConditionViewController alloc] initWithNibName:@"SHFilterLogConditionViewController" bundle:nil];
    controller.dataList = @[@"SHLogFlagVerbose", @"SHLogFlagDebug",  @"SHLogFlagInfo", @"SHLogFlagWarning", @"SHLogFlagError"];
    controller.selectedValue = _levelLabel.text;
    __weak typeof(self) wself = self;
    controller.handler = ^(NSString *logLevel) {
        __strong typeof(wself) sself = wself;
        if( !sself ) {
            return;
        }
        if( logLevel.length > 0  ){
            sself->_filterLogLevel = [[self class] convertLogLevel:logLevel];
            sself->_levelLabel.text = logLevel;
        }
    };
    [self.navigationController pushViewController:controller animated:YES];
}

- (IBAction)filterBtnClick:(id)sender {
    _filterLogContent = self.editTextview.text;
    [self.editTextview resignFirstResponder];
    [self fileterContent];
}



 -(void)loadLogWithPath:(NSString*)filePath {
     [self.indexModuleDic removeAllObjects];
     [self.indexContentDic removeAllObjects];
     
     //现在直接读到内存里，再每行查找， 如果文件很大，需要通过流的方式增量读取，解析
     BOOL isDir = NO;
     if( [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir] && !isDir ) {
         NSError* error = nil;
         NSString* fileContents = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
         NSArray* allLinedStrings = [fileContents componentsSeparatedByCharactersInSet:
          [NSCharacterSet newlineCharacterSet]];
         //先过滤出有哪些模块， 再将内容缓存起来
         for( NSInteger i = 0; i < allLinedStrings.count; i++ ) {
             NSString* str = [allLinedStrings objectAtIndex:i];
             NSRange rightRange = [str rangeOfString:@"]"];
             if( rightRange.location == NSNotFound ) {
                 continue;
             }
             NSRange leftRange = [str rangeOfString:@"["];
             if( leftRange.location == NSNotFound || leftRange.location > rightRange.location ){
                 continue;
             }
             NSString* moduleName = [str substringWithRange:NSMakeRange(leftRange.location, rightRange.location - leftRange.location +1)];
             if( moduleName.length == 0 ) {
                 continue;
             }
             if( ![self.moduleNameArray containsObject:moduleName] ) {
                 [self.moduleNameArray addObject:moduleName];
             }
             [self.indexModuleDic setObject:moduleName forKey:@(i)];
             [self.indexContentDic setObject:str forKey:@(i)];
         }
     }
 }

-(void)fileterContent {
    [self.matchedArray removeAllObjects];
    self.textView.text = @"";
    
    NSMutableArray* indexArray = [NSMutableArray new];
    if( _filterLogModule.length > 0  ){
        for( NSNumber* key in _indexModuleDic ) {
            NSString* module = [_indexModuleDic objectForKey:key];
            if( module.length > 0  && [_filterLogModule isEqualToString:module] ) {
                [indexArray addObject:key];
            }
        }
    }
    NSArray* tmpArray = indexArray.count > 0 ? indexArray : _indexContentDic.allKeys;
    tmpArray = [tmpArray sortedArrayUsingComparator:^NSComparisonResult(NSNumber* obj1, NSNumber* obj2) {
        return obj1.integerValue > obj2.integerValue;
    }];
    for( NSNumber* key in tmpArray ) {
        NSString* strLogConrent = [_indexContentDic objectForKey:key];
        if( _filterLogLevel.length > 0 ) {
            NSRange range = [strLogConrent rangeOfString:_filterLogLevel];
            if( range.location == NSNotFound ){
                continue;
            }
            if( _filterLogContent.length > 0 ) {
                NSRange r = [strLogConrent rangeOfString:_filterLogContent];
                if( r.location == NSNotFound ) {
                    continue;
                }
            }
            [self.matchedArray addObject:key];
        }else{
            if( _filterLogContent.length > 0 ) {
                NSRange r = [strLogConrent rangeOfString:_filterLogContent];
                if( r.location == NSNotFound ) {
                    continue;
                }
            }
            [self.matchedArray addObject:key];
        }
        
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showFilterLogs];
    });
}

-(void)showFilterLogs {
    self.textView.text=@"";
    NSMutableString* content = [NSMutableString new];
    for( NSNumber* index in self.matchedArray ) {
        NSString* log = [_indexContentDic objectForKey:index];
        [content appendString:log];
        [content appendString:@"\n\n"];
    }
    self.textView.text = content;
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"匹配结果"
                                                                             message:self.matchedArray.count == 0 ? @"未匹配到日志":[NSString stringWithFormat:@"共匹配到%@条日志", @(self.matchedArray.count)]
                                                                preferredStyle:UIAlertControllerStyleAlert];
    //We add buttons to the alert controller by creating UIAlertActions:
    UIAlertAction *actionOk = [UIAlertAction actionWithTitle:@"Ok"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil]; //You can use a block here to handle a press on this button
    [alertController addAction:actionOk];
    [self presentViewController:alertController animated:YES completion:nil];
}

+(NSString*)convertLogLevel:(NSString*)level {
    if( level.length == 0 ) {
        return @"";
    }
    //"SHLogFlagVerbose", @"SHLogFlagDebug",  @"SHLogFlagInfo", @"SHLogFlagWarning", @"SHLogFlagError"
    if( [level isEqualToString:@"SHLogFlagVerbose"] ){
        return @"[Level:0]";
    }else if( [level isEqualToString:@"SHLogFlagDebug"] ) {
        return @"[Level:1]";
    }else if( [level isEqualToString:@"SHLogFlagInfo"] ) {
        return @"[Level:2]";
    }else if( [level isEqualToString:@"SHLogFlagInfo"] ) {
        return @"[Level:4]";
    }else if( [level isEqualToString:@"SHLogFlagWarning"] ) {
        return @"[Level:8]";
    }
    return @"[Level:16]";
}

#pragma mark --UITextFieldDelegate
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    if( [string isEqualToString:@"\n"] ) {
        [textField resignFirstResponder];
        return NO;
    }
    _filterLogContent = string;
    return YES;
}

@end
