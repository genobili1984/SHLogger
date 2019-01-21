//
//  SHFilterLogConditionViewController.h
//  SmartVillage
//
//  Created by genobili on 5/25/18.
//  Copyright © 2018 administrator. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SHFilterLogConditionViewController : UIViewController

@property (nonatomic, strong) NSArray* dataList;
@property (nonatomic, strong) NSString* selectedValue;

@property (nonatomic, copy)  void(^handler)(NSString*);

@end
