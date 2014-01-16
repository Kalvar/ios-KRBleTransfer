//
//  BTLECentralViewController.h
//  BLEKit
//
//  Created by Kalvar, ilovekalvar@gmail.com on 2013/12/9.
//  Copyright (c) 2013 - 2014年 Kuo-Ming Lin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BTLECentralViewController : UIViewController
{
    
}

@property (nonatomic, weak) IBOutlet UIImageView *outImageView;
@property (nonatomic, weak) IBOutlet UILabel *outPercentLabel;

@property (nonatomic, strong) NSData *sendData;
@property (nonatomic, assign) NSInteger sendDataIndex;
@property (nonatomic, assign) NSInteger dataLength;
@property (nonatomic, assign) CGFloat progress;

@end
