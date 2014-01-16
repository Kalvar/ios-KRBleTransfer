//
//  BTLECentralViewController.m
//  BLEKit
//
//  Created by Kalvar, ilovekalvar@gmail.com on 2013/12/9.
//  Copyright (c) 2013 - 2014年 Kuo-Ming Lin. All rights reserved.
//

#import "BTLECentralViewController.h"
#import "BLECentralController.h"
#import "BLEPorts.h"

@interface BTLECentralViewController ()

@property (nonatomic, strong) BLECentralController *bleCentralController;
@property (nonatomic, strong) NSMutableData *receivedData;


@end

@implementation BTLECentralViewController

@synthesize outImageView;
@synthesize outPercentLabel;

@synthesize bleCentralController;
@synthesize receivedData = _receivedData;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma --mark Central Transfering Data to Peripheral.
/*
 * @ 傳輸檔案
 */
-(void)transferDataForCharacteristic:(CBCharacteristic *)_characteristic
{
    if( self.dataLength <= 0 )
    {
        self.dataLength = [self.sendData length];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progress = [[NSString stringWithFormat:@"%.2f",
                          ( (float)(self.sendDataIndex) / self.dataLength ) * 100.0f] floatValue];
        [self.outPercentLabel setText:[NSString stringWithFormat:@"%.2f%%", self.progress]];
    });
    
    //已傳出最後一筆封包
    if (self.sendDataIndex >= self.dataLength)
    {
        //傳出結束符號
        NSData *_eomData = [@"EOM" dataUsingEncoding:NSUTF8StringEncoding];
        [self.bleCentralController writeValueForPeripheralWithCharacteristic:_characteristic data:_eomData completion:nil];
        [self.bleCentralController cancelNotifyWithCharacteristic:_characteristic completion:nil];
        return;
    }
    
    NSInteger amountToSend = self.sendData.length - self.sendDataIndex;
    if (amountToSend > 20)
    {
        amountToSend = 20;
    }
    // Copy out the data we want
    NSData *chunk = [NSData dataWithBytes:self.sendData.bytes+self.sendDataIndex length:amountToSend];
    
    //NSLog(@"chunk : %@", chunk);
    
    self.sendDataIndex += amountToSend;
    
    //NSLog(@"Sent chunk: %@", chunk);
    //NSLog(@"sendDataIndex : %i", self.sendDataIndex);
    
    [self.bleCentralController writeValueForPeripheralWithCharacteristic:_characteristic data:chunk completion:^(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error)
    {
        if( !error )
        {
            [self transferDataForCharacteristic:characteristic];
        }
    }];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _receivedData = [NSMutableData new];
    
    self.sendDataIndex = 0;
    self.sendData      = UIImagePNGRepresentation([UIImage imageNamed:@"test.png"]);;
    self.dataLength    = self.sendData.length;
    
    bleCentralController = [BLECentralController shareInstance];
    __block BLECentralController *_blockBleCentralController = bleCentralController;
    [self.bleCentralController addCharacteristicsCBUUID:@[[CBUUID UUIDWithString:NOTIFY_CHARACTERISTIC_UUID],
                                                          [CBUUID UUIDWithString:NOTIFY_PERIPHERAL_CHARACTERISTIC_UUID],
                                                          [CBUUID UUIDWithString:WRITE_CHARACTERISTIC_UUID]]
                                             forService:BLE_CUSTOM_SERVICE_UUID];
    [self.bleCentralController refreshSupportServices];
    
    //Central Device 狀態更新時
    [bleCentralController setUpdateStateHandler:^(CBCentralManager *central, BOOL supportBLE)
    {
        NSLog(@"Central viewDidLoad : %i", supportBLE);
        if( supportBLE )
        {
            [_blockBleCentralController startScanPeripherals];
        }
    }];
    
    //斷線時做什麼事
    self.bleCentralController.autoReconnect = NO;
    [bleCentralController setDisconnectHandler:^(CBPeripheral *peripheral)
    {
        NSLog(@"斷線時做什麼事");
        //嚐試搜描回連
        //[_blockBleCentralController startScanPeripherals];
    }];
    
    //找到 Peripheral 時
    [bleCentralController setFoundPeripheralHandler:^(CBCentralManager *centralManager, CBPeripheral *peripheral, NSDictionary *advertisementData, NSInteger rssi)
    {
        //在這裡控制是否連線
        [centralManager connectPeripheral:peripheral options:nil];
    }];
    
    /*
     * @ 設計流程
     *   - 1. 第一次連線，是採取先連通知屬性 ( Notify ) 的動作，其餘屬性特徵碼不連
     *   - 2. 之後再手動使用 [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:WRITE_CHARACTERISTIC_UUID]] forService:_foundService];
     *        來控制管控特徵碼的連結。
     *
     *   也就是先保持連線，其餘特徵碼再手動控制，這樣流程控制才會順。
     *
     */
    //找到服務時
    [bleCentralController setFoundServiceHandler:^(CBPeripheral *peripheral, NSDictionary *discoveredServices, CBService *foundSerivce)
    {
        NSLog(@"找到服務時");
        //僅先連線接收通知，不一開始就接收該服務底下所有的特徵碼。因為要先讓 Central 接收 Peripheral 傳來的圖片 XD
        //之後都能手動控制找服務與連線 ( 覆寫 Block 就行了 )
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:NOTIFY_CHARACTERISTIC_UUID]]
                                 forService:foundSerivce];
        
        //[peripheral discoverCharacteristics:[discoveredServices objectForKey:(NSString *)[foundSerivce.UUID description]]
        //                         forService:foundSerivce];
    }];
    
    /*
    //找到特徵碼時
    [bleCentralController setFoundCharacteristicHandler:^(CBPeripheral *peripheral, CBService *service, NSError *error)
    {
        NSLog(@"找到特徵碼時");
    }];
    */
    
    //列舉找到的特徵碼
    __block BTLECentralViewController *_weakSelf = self;
    [bleCentralController setEnumerateCharacteristicsHandler:^(CBPeripheral *peripheral, CBCharacteristic *characteristic)
    {
        NSLog(@"UUID : %@", (NSString *)characteristic.UUID);
        
        //是通知用的特徵碼
        //if( characteristic.properties == CBCharacteristicPropertyNotify )
        if ( [characteristic.UUID isEqual:[CBUUID UUIDWithString:NOTIFY_CHARACTERISTIC_UUID]] )
        {
            NSLog(@"通知的屬性 1");
            //特徵碼必須為 Notify 屬性，It will need to subscribe to it ( Notify 屬性必須訂閱並註冊特徵碼，這裡才會真的完全連線 )
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        
        //是 Peripheral 要求 Central 再傳送下一筆資料的通知
        if ( [characteristic.UUID isEqual:[CBUUID UUIDWithString:NOTIFY_PERIPHERAL_CHARACTERISTIC_UUID]] )
        {
            NSLog(@"通知的屬性 2");
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        
        //是讀寫值的特徵碼 ( 這裡的實驗是由 Central 傳輸檔案給 Peripheral )
        if( [characteristic.UUID isEqual:[CBUUID UUIDWithString:WRITE_CHARACTERISTIC_UUID]] )
        {
            NSLog(@"讀寫的屬性");
            
            [_weakSelf transferDataForCharacteristic:characteristic];
            
            //以下 OK
            //該特徵碼必須擁有「寫」的屬性權限才可作用此函式
            //NSData *_transferData = [@"Hi, Peripheral." dataUsingEncoding:NSUTF8StringEncoding];
            //[peripheral writeValue:_transferData forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            
            //該特徵碼必須擁有「讀」的屬性權限才可作用此函式
            //[peripheral readValueForCharacteristic:characteristic];
        }
        
    }];
    
    /*
    //Central 寫資料給 Peripheral 完成後，會觸發這裡
    [bleCentralController setWriteCompletion:^(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error)
    {
        if( !error )
        {
            //再傳下一個封包
            
        }
        
        //NSLog(@"寫資料給 Peripheral services : %@", peripheral.services);
        //NSLog(@"寫資料給 Peripheral characteristic value : %@", [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding]);
        //NSLog(@"寫資料給 Peripheral error : %@", error);
    }];
    */
    
    //Central 收到 Peripheral 送來的資料時
    __block UIImageView *_weakOutImageView   = outImageView;
    //__block NSMutableData *_weakReceivedData = _receivedData;
    [bleCentralController setReceiveCompletion:^(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error, NSMutableData *combinedData)
    {
        NSString *string = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"data length : %i", combinedData.length);
        
        //只有 NOTIFY_CHARACTERISTIC_UUID 傳來的資料才需要組合
        if( [characteristic.UUID isEqual:[CBUUID UUIDWithString:NOTIFY_CHARACTERISTIC_UUID]] )
        {
            //if( [combinedData length] >= 152200 )
            if ([string isEqualToString:@"EOM"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    NSLog(@"received combinedData length : %i", combinedData.length);
                    //NSLog(@"received _weakReceivedData length : %i", _weakReceivedData.length);
                    
                    [_weakOutImageView setImage:[[UIImage alloc] initWithData:combinedData]];
                    
                    // Cancel our subscription to the characteristic
                    //[peripheral setNotifyValue:NO forCharacteristic:characteristic];
                    
                    //因為要回送資料，所以先不斷線
                    //[_blockBleCentralController cancelConnecting];
                    //[self.centralManager cancelPeripheralConnection:peripheral];
                    
                    [_blockBleCentralController cancelNotifyWithCharacteristic:characteristic completion:nil];
                    
                    //反發送圖片回去 Peripheral
                    //先找到讀寫的那一個特徵碼
                    CBService *_foundService = [BLEPorts findServiceFromUUID:[CBUUID UUIDWithString:BLE_CUSTOM_SERVICE_UUID] peripheral:peripheral];
                    //CBCharacteristic *_writeCharacteristic = [BLEPorts findCharacteristicFromUUID:[CBUUID UUIDWithString:WRITE_CHARACTERISTIC_UUID] service:_foundService];
                    
                    //[peripheral discoverServices:peripheral.services];
                    
                    [_blockBleCentralController refreshDiscoverServices:_blockBleCentralController.supportServicesCBUUID foundServiceCompletion:^(CBPeripheral *peripheral, NSDictionary *discoveredServices, CBService *foundSerivce) {
                        NSLog(@"只找指定的特徵碼");
                        //只找指定的特徵碼
                        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:NOTIFY_PERIPHERAL_CHARACTERISTIC_UUID],
                                                              [CBUUID UUIDWithString:WRITE_CHARACTERISTIC_UUID]]
                                                 forService:_foundService];
                    } enumerateCharacteristicHandler:^(CBPeripheral *peripheral, CBCharacteristic *characteristic) {
                        NSLog(@"UUID x : %@", (NSString *)characteristic.UUID);
                        
                        //是通知用的特徵碼
                        //if( characteristic.properties == CBCharacteristicPropertyNotify )
                        if ( [characteristic.UUID isEqual:[CBUUID UUIDWithString:NOTIFY_CHARACTERISTIC_UUID]] )
                        {
                            NSLog(@"通知的屬性 1");
                            //特徵碼必須為 Notify 屬性，It will need to subscribe to it ( Notify 屬性必須訂閱並註冊特徵碼，這裡才會真的完全連線 )
                            //[peripheral setNotifyValue:YES forCharacteristic:characteristic];
                        }
                        
                        //是 Peripheral 要求 Central 再傳送下一筆資料的通知
                        if ( [characteristic.UUID isEqual:[CBUUID UUIDWithString:NOTIFY_PERIPHERAL_CHARACTERISTIC_UUID]] )
                        {
                            NSLog(@"通知的屬性 2");
                            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                        }
                        
                        //是讀寫值的特徵碼 ( 這裡的實驗是由 Central 傳輸檔案給 Peripheral )
                        if( [characteristic.UUID isEqual:[CBUUID UUIDWithString:WRITE_CHARACTERISTIC_UUID]] )
                        {
                            NSLog(@"讀寫的屬性");
                            
                            [_weakSelf transferDataForCharacteristic:characteristic];
                            
                            //以下 OK
                            //該特徵碼必須擁有「寫」的屬性權限才可作用此函式
                            //NSData *_transferData = [@"Hi, Peripheral." dataUsingEncoding:NSUTF8StringEncoding];
                            //[peripheral writeValue:_transferData forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                            
                            //該特徵碼必須擁有「讀」的屬性權限才可作用此函式
                            //[peripheral readValueForCharacteristic:characteristic];
                        }
                    }];
                });
                
            }
            else
            {
                //自行組合資料
                [combinedData appendData:characteristic.value];
            }

        }
        
        NSLog(@"Received from peripheral string: %@\n\n", string);
        
    }];
    
    //Central 已更新 Peripheral 的 Notify 狀態
    [bleCentralController setNotifyChangedCompletion:^(CBCentralManager *centralManager, CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error)
    {
        NSLog(@"Central 已更新 Peripheral 的 Notify 狀態");
        
        //非通知屬性，一律不執行
        if( characteristic.properties != CBCharacteristicPropertyNotify )
        {
            return;
        }
        
        // Notification has started
        if (characteristic.isNotifying)
        {
            NSLog(@"Notification began on 1 %@", characteristic);
            //[peripheral readValueForCharacteristic:characteristic];
        }
        else
        {
            // Notification has stopped
            // so disconnect from the peripheral
            NSLog(@"Notification stopped disconnecting with %@", characteristic);
            //[centralManager cancelPeripheralConnection:peripheral];
        }
    }];
    
    //[self.bleCentralController startScanPeripherals];
}

-(void)viewDidAppear:(BOOL)animated
{
    /*
    if( self.bleCentralController.isDisconnected )
    {
        [self.bleCentralController startScanPeripherals];
    }
     */
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.bleCentralController stopScanAndCancelConnect];
    [super viewWillDisappear:animated];
}


@end
