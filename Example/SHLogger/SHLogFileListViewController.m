//
//  SHLogFileListViewController.m
//  SHLogger_Example
//
//  Created by genobili on 5/19/18.
//  Copyright © 2018 genobili. All rights reserved.
//

#import "SHLogFileListViewController.h"
#import "SHLogManager.h"
#import "SHShowLogViewController.h"

@interface SHLogFileListViewController ()<UITableViewDelegate, UITableViewDataSource>
{
    NSArray* _offlineLogFileArray;
    NSArray* _crashLogFileArray;
    NSArray* _performanceLogFileArray;
    NSMutableArray* _selectedCrashRows;
    NSMutableArray* _selectedLogRows;
    NSMutableArray* _selectedPerformanceLogRows;
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) UIButton* dropBtn;
@property (nonatomic, strong) UIButton* editBtn;
@property (weak, nonatomic) IBOutlet UIButton *selectAllBtn;

@end

@implementation SHLogFileListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
//    _selectedRows = [NSMutableArray new];
    _selectedCrashRows = [NSMutableArray new];
    _selectedLogRows = [NSMutableArray new];
    _selectedPerformanceLogRows = [NSMutableArray new];
    _offlineLogFileArray = [SHLogManager offlineListFiles:true];
    _crashLogFileArray = [SHLogManager crashLogFiles];
    _performanceLogFileArray = [SHLogManager performaceListFiles];
    [self.tableView reloadData];
    [self.tableView setEditing:self.editable];
    
    self.dropBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.dropBtn.frame = CGRectMake(0, 0, 48, 32);
    [self.dropBtn setTitle:@"drop" forState:UIControlStateNormal];
    [self.dropBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.dropBtn setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
    [self.dropBtn addTarget:self action:@selector(dropFile) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem* rightBarItem =  [[UIBarButtonItem alloc] initWithCustomView:self.dropBtn];
    self.navigationItem.rightBarButtonItem = rightBarItem;
    
    self.editBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.editBtn.frame = CGRectMake(0, 0, 48, 32);
    [self.editBtn setTitle:@"edit" forState:UIControlStateNormal];
    [self.editBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.editBtn setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
    [self.editBtn addTarget:self action:@selector(editBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem* leftBarItem =  [[UIBarButtonItem alloc] initWithCustomView:self.editBtn];
    self.navigationItem.leftBarButtonItem = leftBarItem;
    self.navigationItem.leftItemsSupplementBackButton = YES;
    
    
    //[self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"OfflineLogFileViewCell"];
    [self setTableViewEdit:self.editable];
    self.title = [NSString stringWithFormat:@"共%@日志", @(_offlineLogFileArray.count)];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark -- UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

#pragma mark -- UITableViewDataSource
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if( section == 0  ) {
        return @"崩溃日志列表";
    }else if( section == 1 ) {
        return @"离线日志列表";
    }else if( section == 2 ) {
        return @"性能日志列表";
    }
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if( section == 0  ) {
        return _crashLogFileArray.count;
    }else if( section == 1 ) {
        return _offlineLogFileArray.count;
    }else if(section == 2 ) {
        return _performanceLogFileArray.count;
    }
    return 0;
}

#pragma mark -- UITableViewDataSource
-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"OfflineLogFileViewCell"];
    if( !cell ) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"OfflineLogFileViewCell"];
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingHead;
    }
    NSString* path = @"";
    if( section == 0  ) {
        path = [_crashLogFileArray objectAtIndex:row];
        if( [_selectedCrashRows containsObject:@(row)] && tableView.isEditing ) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }else{
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }else if(section == 1 ) {
        path = [_offlineLogFileArray objectAtIndex:row];
        if( [_selectedLogRows containsObject:@(row)] && tableView.isEditing ) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }else{
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }else if( section == 2 ) {
        path = [_performanceLogFileArray objectAtIndex:row];
        if( [_selectedPerformanceLogRows containsObject:@(row)] && tableView.isEditing ) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }else{
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    NSString* filename = [path lastPathComponent];
    cell.textLabel.text = filename;
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 3;
}


-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    if( tableView.isEditing ){
        if(section == 0  ) {
            if( ![_selectedCrashRows containsObject:@(row)] ) {
                [_selectedCrashRows addObject:@(row)];
            }
        }else if(section == 1 ){
            if( ![_selectedLogRows containsObject:@(row)] ) {
                [_selectedLogRows addObject:@(row)];
            }
        }else {
            if( ![_selectedPerformanceLogRows containsObject:@(row)] ) {
                [_selectedPerformanceLogRows addObject:@(row)];
            }
        }
        [self updateSelectBtn];
    }else{
        SHShowLogViewController* showLogViewController = [[SHShowLogViewController alloc] initWithNibName:@"SHShowLogViewController" bundle:nil];
        NSString* filePath = @"";
        if( section == 0 ) {
           filePath = [_crashLogFileArray objectAtIndex:row];
        }else if( section == 1){
            filePath = [_offlineLogFileArray objectAtIndex:row];
        }else{
            filePath = [_performanceLogFileArray objectAtIndex:row];
        }
        showLogViewController.logFilePath = filePath;
        [self.navigationController pushViewController:showLogViewController animated:YES];
    }
}

-(void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    if( tableView.isEditing ) {
        if( section == 0  ){
            if( [_selectedCrashRows containsObject:@(row)]  ){
                 [_selectedCrashRows  removeObject:@(row)];
            }
        }else if(section == 1 ){
            if( [_selectedLogRows containsObject:@(row)]  ){
                [_selectedLogRows  removeObject:@(row)];
            }
        }else {
            if( [_selectedPerformanceLogRows containsObject:@(row)]  ){
                [_selectedPerformanceLogRows  removeObject:@(row)];
            }
        }
    }
    [self updateSelectBtn];
}

-(void)updateSelectBtn {
    if( (_selectedCrashRows.count + _selectedCrashRows.count + _selectedPerformanceLogRows.count) < (_offlineLogFileArray.count + _crashLogFileArray.count + _performanceLogFileArray.count) ) {
        [self.selectAllBtn setTitle:@"全选" forState:UIControlStateNormal];
    }else{
        [self.selectAllBtn setTitle:@"反选" forState:UIControlStateNormal];
    }
    self.dropBtn.enabled = (_selectedCrashRows.count + _selectedLogRows.count + _performanceLogFileArray.count) > 0;
}

- (IBAction)selectAll:(id)sender {
    if( (_selectedCrashRows.count + _selectedCrashRows.count + _selectedPerformanceLogRows.count) < (_offlineLogFileArray.count + _crashLogFileArray.count + _performanceLogFileArray.count) ) {
        if( _selectedCrashRows.count < _crashLogFileArray.count ) {
            for( NSInteger i = 0; i < _crashLogFileArray.count; i++ ) {
                if( ![_crashLogFileArray containsObject:@(i)] ) {
                    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
                    [_selectedCrashRows addObject:@(i)];
                }
            }
        }
        if(   _selectedLogRows.count < _offlineLogFileArray.count ) {
            for( NSInteger i = 0; i < _offlineLogFileArray.count; i++ ) {
                if( ![_selectedLogRows containsObject:@(i)] ) {
                    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:1] animated:NO scrollPosition:UITableViewScrollPositionNone];
                    [_selectedLogRows addObject:@(i)];
                }
            }
        }
        if(   _selectedPerformanceLogRows.count < _performanceLogFileArray.count ) {
            for( NSInteger i = 0; i < _performanceLogFileArray.count; i++ ) {
                if( ![_selectedPerformanceLogRows containsObject:@(i)] ) {
                    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:2] animated:NO scrollPosition:UITableViewScrollPositionNone];
                    [_selectedPerformanceLogRows addObject:@(i)];
                }
            }
        }
    }else{
        for( NSInteger i = 0; i < _offlineLogFileArray.count; i++ ) {
            if( [_selectedCrashRows containsObject:@(i)] ) {
                [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:1] animated:NO];
                [_selectedCrashRows removeObject:@(i)];
            }
        }
        for( NSInteger i = 0; i < _crashLogFileArray.count; i++ ) {
            if( [_selectedCrashRows containsObject:@(i)] ) {
                [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO];
                [_selectedCrashRows removeObject:@(i)];
            }
        }
        for( NSInteger i = 0; i < _selectedPerformanceLogRows.count; i++ ) {
            if( [_selectedPerformanceLogRows containsObject:@(i)] ) {
                [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:2] animated:NO];
                [_selectedPerformanceLogRows removeObject:@(i)];
            }
        }
    }
    [self updateSelectBtn];
}


-(void)dropFile {
    NSMutableArray* tmpArray = [NSMutableArray new];
    for( NSNumber* num in _selectedCrashRows ) {
        NSString* filePath = [_crashLogFileArray objectAtIndex:num.integerValue];
        [tmpArray addObject:filePath];
    }
    for( NSNumber* num in _selectedLogRows ) {
        NSString* filePath = [_offlineLogFileArray objectAtIndex:num.integerValue];
        [tmpArray addObject:filePath];
    }
    for( NSNumber* num in _selectedPerformanceLogRows ) {
        NSString* filePath = [_performanceLogFileArray objectAtIndex:num.integerValue];
        [tmpArray addObject:filePath];
    }
    if( tmpArray.count == 0 ) {
        return;
    }
    [[SHLogManager sharedInstance] airDropFiles:tmpArray needPackCompress:YES viewController:self];
}


-(void)editBtnClick:(id)sender {
    BOOL isEdit = self.tableView.isEditing;
    [self setTableViewEdit:!isEdit];
}

-(void)setTableViewEdit:(BOOL)edit {
    [self.tableView setEditing:edit];
    [self.dropBtn setHidden:!edit];
    [self.selectAllBtn setHidden:!edit];
    [self.tableView reloadData];
}

@end
