//
//  SHFilterLogConditionViewController.m
//  SmartVillage
//
//  Created by genobili on 5/25/18.
//  Copyright © 2018 administrator. All rights reserved.
//

#import "SHFilterLogConditionViewController.h"

@interface SHFilterLogConditionViewController ()

@property (weak, nonatomic) IBOutlet UITableView *tableView;


@end

@implementation SHFilterLogConditionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



#pragma mark -- UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

#pragma mark -- UITableViewDataSource
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataList.count;
}

#pragma mark -- UITableViewDataSource
-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = indexPath.row;
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"FilterLogConditionViewCell"];
    if( !cell ) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FilterLogConditionViewCell"];
    }
    NSString* str = [self.dataList objectAtIndex:row];
    cell.textLabel.text = str;
    if( self.selectedValue.length > 0  && [str isEqualToString:self.selectedValue] ) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }else{
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}


-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = indexPath.row;
    NSString* str = [self.dataList objectAtIndex:row];
    if( self.handler ) {
        self.handler(str);
    }
    [self.navigationController popViewControllerAnimated:YES];
}




@end
