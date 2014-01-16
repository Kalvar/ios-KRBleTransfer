//
//  BTLEPeripheralViewController.m
//  BLEKit
//
//  Created by Kalvar, ilovekalvar@gmail.com on 2013/12/9.
//  Copyright (c) 2013 - 2014年 Kuo-Ming Lin. All rights reserved.
//

#import "BTLEPeripheralViewController.h"
#import "BLEPeripheralController.h"
#import "BLEPorts.h"

@interface BTLEPeripheralViewController ()

@property (nonatomic, strong) BLEPeripheralController *blePeripheralController;

@end

@implementation BTLEPeripheralViewController

@synthesize blePeripheralController;
@synthesize outPercentLabel;
@synthesize advertisingSwitch;

@synthesize outImageView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	blePeripheralController = [BLEPeripheralController shareInstance];
    __block BLEPeripheralController *_blockBlePeripheralController = blePeripheralController;
    
    [blePeripheralController setUpdateStateHandler:^(CBPeripheralManager *peripheralManager, CBPeripheralManagerState peripheralState, BOOL supportBLE)
    {
        if( supportBLE )
        {
            // We're in CBPeripheralManagerStatePoweredOn state...
            NSLog(@"self.peripheralManager powered on.");
            
            //建立 1 個服務碼 + 3 個特徵碼進行測試
            // Start with the CBMutableCharacteristic
            CBMutableCharacteristic *_notifyCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:NOTIFY_CHARACTERISTIC_UUID]
                                                                                                properties:CBCharacteristicPropertyNotify
                                                                                                     value:nil
                                                                                               permissions:CBAttributePermissionsReadable];
            
            CBMutableCharacteristic *_readwriteCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:WRITE_CHARACTERISTIC_UUID]
                                                                                                   properties:CBCharacteristicPropertyWrite | CBCharacteristicPropertyRead
                                                                                                        value:nil
                                                                                                  permissions:CBAttributePermissionsWriteable | CBAttributePermissionsReadable];
            //Central 模擬 SPP 傳資料給 Peripheral 的雙向回應通道
            CBMutableCharacteristic *_notifyPeripheralCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:NOTIFY_PERIPHERAL_CHARACTERISTIC_UUID]
                                                                                                properties:CBCharacteristicPropertyNotify
                                                                                                     value:nil
                                                                                               permissions:CBAttributePermissionsReadable];
            
            _blockBlePeripheralController.notifyCharacteristic    = _notifyCharacteristic;
            _blockBlePeripheralController.readwriteCharacteristic = _readwriteCharacteristic;
            
            // Then the service
            CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:BLE_CUSTOM_SERVICE_UUID]
                                                                               primary:YES];
            
            // Add the characteristic to the service
            transferService.characteristics = @[_notifyCharacteristic, _readwriteCharacteristic, _notifyPeripheralCharacteristic];
            
            // And add it to the peripheral manager ( 能增加多個 service，就像 NSMutableArray 一樣的概念 )
            [peripheralManager addService:transferService];
        }
    }];
    
    //收到 Central 要求讀取特徵碼值的指令
    [blePeripheralController setReadRequestHandler:^(CBPeripheralManager *peripheralManager, CBATTRequest *cbATTRequest)
    {
        NSLog(@"didReceiveReadRequest : %@", cbATTRequest);
    }];
    
    //收到來自 Central 傳輸的資料
    __block UIImageView *_weakOutImageView = outImageView;
    [blePeripheralController setWriteRequestHandler:^(CBPeripheralManager *peripheralManager, NSArray *cbAttRequests, NSMutableData *receivedData)
    {
        //NSLog(@"didReceiveWriteRequests : %@", cbAttRequests);
        
        for( CBATTRequest *_cbRequest in cbAttRequests )
        {
            //NSLog(@"特徵碼 Value ( NSData ) 1 : %@, Parsed : %@", _cbRequest.characteristic.value, [[NSString alloc] initWithData:_cbRequest.characteristic.value encoding:NSUTF8StringEncoding]);
            
            NSString *_parsedString = [[NSString alloc] initWithData:_cbRequest.value encoding:NSUTF8StringEncoding];
            //值在 CBATTRequest 裡，不在特徵碼裡
            NSLog(@"Parsed : %@", _parsedString);
            
            if( [_parsedString isEqualToString:@"EOM"] )
            {
                NSLog(@"receivedData length : %i", receivedData.length);
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [_weakOutImageView setImage:[[UIImage alloc] initWithData:receivedData]];
                });
            }
            else
            {
                //[_blockBlePeripheralController clearReceivedData];
                
                _blockBlePeripheralController.readwriteCharacteristic.value = _cbRequest.value;
                
                //#error 待補上 Central SPP Transfer XD
                //[_blockBlePeripheralController.receivedData appendData:_cbRequest.value];
                [receivedData appendData:_cbRequest.value];
                
                //#error 在這裡讓 Central 再送下一個封包
                //先通知 Central 已完成 Value
                //[peripheralManager respondToRequest:[cbAttRequests objectAtIndex:0] withResult:CBATTErrorSuccess];
                [peripheralManager respondToRequest:_cbRequest withResult:CBATTErrorSuccess];
                
                //#error 也可以在這裡回應 Central 特定訊息
                
                [_blockBlePeripheralController clearSendData];
                
                CBMutableCharacteristic *_notifyPeripheralCharacteristic = (CBMutableCharacteristic *)[BLEPorts findCharacteristicFromUUID:[CBUUID UUIDWithString:NOTIFY_PERIPHERAL_CHARACTERISTIC_UUID] service:_cbRequest.characteristic.service];
                
                //回應 Central 數據, 20 Words
                [peripheralManager updateValue:[@"Hello, Central, Next" dataUsingEncoding:NSUTF8StringEncoding]
                             forCharacteristic:_notifyPeripheralCharacteristic
                          onSubscribedCentrals:nil];
            }
            break;
        }
    }];
    
    //準備傳輸資料給 Central
    [blePeripheralController setReadyTranferHandler:^(CBPeripheralManager *peripheral, CBCentral *central, CBCharacteristic *characteristic)
    {
        if( [characteristic.UUID isEqual:[CBUUID UUIDWithString:NOTIFY_CHARACTERISTIC_UUID]] )
        {
            NSLog(@"\n\n\nWOW\n\n\n");
            NSData *_sendData = UIImagePNGRepresentation([UIImage imageNamed:@"test.png"]);
            _blockBlePeripheralController.sendDataIndex = 0;
            _blockBlePeripheralController.sendData      = _sendData;
            _blockBlePeripheralController.dataLength    = _sendData.length;
            _blockBlePeripheralController.eomEndHeader  = @"EOM";
            [_blockBlePeripheralController transferData];
        }
        return YES;
    }];
    
    //準備傳輸下一個封包資料給 Central 時
    [blePeripheralController setReadyTransferNextChunkHandler:^(CBPeripheralManager *peripheralManager, CGFloat progress)
    {
        //...
    }];
    
    //持續且已送出下一個封包資料給 Central 時
    __block UILabel *_weakOutPercentLabel = outPercentLabel;
    [blePeripheralController setSppTransferHandler:^(BOOL success, NSInteger chunkIndex, NSData *chunk, CGFloat progress)
    {
        NSLog(@"持續且已送出下一個封包資料給 Central 時");
        //傳送成功
        if( success )
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                _weakOutPercentLabel.text = [NSString stringWithFormat:@"%.2f%%", progress];
            });
            
            //NSLog(@"progress 1 : %.2f", progress);
        }
    }];
    
    //已傳輸完成
    [blePeripheralController setSppTransferCompletion:^(CBPeripheralManager *peripheralManager, CGFloat progress)
    {
        NSLog(@"已傳輸完成\n\n\n");
        dispatch_async(dispatch_get_main_queue(), ^{
            _weakOutPercentLabel.text = [NSString stringWithFormat:@"%.2f%%", progress];
        });
    }];
    
    
    //Central 取消訂閱時
    [blePeripheralController setCentralCancelSubscribeCompletion:^(CBPeripheralManager *peripheralManager, CBCentral *central, CBCharacteristic *characteristic)
    {
        NSLog(@"Central 取消訂閱時");
    }];
    
    
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.blePeripheralController stopAdvertising];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Switch Methods
/** Start advertising ( 是否進行廣播 )
 */
- (IBAction)switchChanged:(id)sender
{
    if (self.advertisingSwitch.on)
    {
        [self.blePeripheralController startAdvertisingAtServiceUUID:BLE_CUSTOM_SERVICE_UUID];
    }
    else
    {
        [self.blePeripheralController stopAdvertising];
    }
}

@end
