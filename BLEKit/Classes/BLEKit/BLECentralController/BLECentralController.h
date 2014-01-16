//
//  BLECentralController.h
//  BLEKit
//
//  Created by Kalvar, ilovekalvar@gmail.com on 2013/12/9.
//  Copyright (c) 2013 - 2014年 Kuo-Ming Lin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

//Central 已準備進行連結，狀態更新時
typedef void(^BLECentralUpdateStateHandler)(CBCentralManager *centralManager, BOOL supportBLE);

//Central 寫資料給 Peripheral 完成時
typedef void(^BLECentralWriteCompletion)(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error);

//Central 收到 Peripheral 傳來的資料時 ( Update Value )
typedef void(^BLECentralReceiveCompletion)(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error, NSMutableData *combinedData);

//Central 變更 Peripheral 通知狀態時 ( Peripheral 的 setNotify 函式被觸發時 )
typedef void(^BLECentralNotifyChangedCompletion)(CBCentralManager *centralManager, CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error);

//Central 發生 Exceptions 時
typedef void(^BLECentralError)(NSError *error);

//Central 找到 Peripheral 時 ( 在這裡指定是否連線 )
typedef void(^BLECentralFoundPeripheralHandler)(CBCentralManager *centralManager, CBPeripheral *peripheral, NSDictionary *advertisementData, NSInteger rssi);

//Central 找到指定的服務碼時
typedef void(^BLECentralFoundServiceHandler)(CBPeripheral *peripheral, NSDictionary *discoveredServices, CBService *foundSerivce);

//Central 找到 Peripheral 指定的特徵碼時
typedef void(^BLECentralFoundCharacteristicsHandler)(CBPeripheral *peripheral, CBService *service, NSError *error);

//Central 找到 Peripheral 指定的特徵碼時，進行列舉出每一個特徵碼的動作
typedef void(^BLECentralEnumerateCharacteristicsHandler)(CBPeripheral *peripheral, CBCharacteristic *characteristic);

//Central 與 Peripheral 斷線時
typedef void(^BLECentralDisconnectHandler)(CBPeripheral *peripheral);




@protocol BLECentralControllerDelegate;

@interface BLECentralController : NSObject<CBCentralManagerDelegate, CBPeripheralDelegate>
{
    id<BLECentralControllerDelegate> delegate;
}

@property (nonatomic, copy) BLECentralUpdateStateHandler updateStateHandler;
@property (nonatomic, copy) BLECentralWriteCompletion writeCompletion;
@property (nonatomic, copy) BLECentralReceiveCompletion receiveCompletion;
@property (nonatomic, copy) BLECentralNotifyChangedCompletion notifyChangedCompletion;
@property (nonatomic, copy) BLECentralError errorCompletion;
@property (nonatomic, copy) BLECentralFoundPeripheralHandler foundPeripheralHandler;
@property (nonatomic, copy) BLECentralFoundServiceHandler foundServiceHandler;
@property (nonatomic, copy) BLECentralFoundCharacteristicsHandler foundCharacteristicHandler;
@property (nonatomic, copy) BLECentralEnumerateCharacteristicsHandler enumerateCharacteristicsHandler;
@property (nonatomic, copy) BLECentralDisconnectHandler disconnectHandler;

//Use Strong, Not Weak, 'Coz the BT need to long connecting.
@property (nonatomic, strong) id<BLECentralControllerDelegate> delegate;

//Central Manager
@property (strong, nonatomic) CBCentralManager *centralManager;
//目前正在作用的 Peripheral
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;
//Peripheral 傳來的資料
@property (strong, nonatomic) NSMutableData *combinedData;

//已發現的服務與特徵碼資訊
@property (nonatomic, strong) NSMutableDictionary *discoveredServices;
//Peripheral 支援的服務 ( CBUUID 格式，指定允許掃描的服務 )
@property (nonatomic, strong) NSMutableArray *supportServicesCBUUID;
//要拒絕連線的 RSSI 訊號強度範圍
@property (nonatomic, assign) NSInteger rssiRejectsHighRange;
@property (nonatomic, assign) NSInteger rssiRejectsLowRange;
//目前的 RSSI 強度
@property (nonatomic, assign) NSInteger rssi;
//接收到 Peripheral 的廣播資料
@property (nonatomic, strong) NSDictionary *advertisementInfo;
//Peripheral 設備名稱
@property (nonatomic, strong) NSString *peripheralName;

//與 Peripheral 斷線
@property (nonatomic, assign) BOOL isDisconnected;
//與 Peripheral 正在嚐試連線
@property (nonatomic, assign) BOOL isConnecting;
//與 Peripheral 已連線
@property (nonatomic, assign) BOOL isConnected;

//是否開啟與 Peripheral 的 RSSI Connection 限定範圍
@property (nonatomic, assign) BOOL isOpenLimitConnection;
//是否在斷線時，自動連線
@property (nonatomic, assign) BOOL autoReconnect;


+(BLECentralController *)shareInstance;
-(id)init;
-(BLECentralController *)initWithDelegate:(id<BLECentralControllerDelegate>)_bleDelegate;

#pragma --mark Scanning Methods
-(BOOL)supportBLE;
-(void)startScanPeripherals;
-(void)stopScanPeripherals;
-(void)stopScanAndCancelConnect;
-(void)addCharacteristicsCBUUID:(NSArray *)_characteristicsCBUUID forService:(NSString *)_serviceUUID;
-(void)refreshSupportServices;
-(void)setCharacteristicBeNotifyValues:(NSArray *)_characteristics;
-(void)cleanAllConnections;
-(void)cancelConnecting;
-(void)cancelNotifyWithCharacteristic:(CBCharacteristic *)_characteristic completion:(BLECentralNotifyChangedCompletion)_completion;
-(void)refreshDiscoverServices:(NSArray *)_services foundServiceCompletion:(BLECentralFoundServiceHandler)_serviceCompletion enumerateCharacteristicHandler:(BLECentralEnumerateCharacteristicsHandler)_characteristicHandler;

#pragma --mark Read / Write with Peripheral
-(void)writeValueForPeripheralWithCharacteristic:(CBCharacteristic *)_characteristic data:(NSData *)_data completion:(BLECentralWriteCompletion)_completion;
-(void)readValueFromPeripheralWithCharacteristic:(CBCharacteristic *)_characteristic completion:(BLECentralReceiveCompletion)_completion;

#pragma --mark Setting Blocks
-(void)setUpdateStateHandler:(BLECentralUpdateStateHandler)_centralUpdateStateHandler;
-(void)setWriteCompletion:(BLECentralWriteCompletion)_centralWriteCompletion;
-(void)setReceiveCompletion:(BLECentralReceiveCompletion)_centralReceiveCompletion;
-(void)setNotifyChangedCompletion:(BLECentralNotifyChangedCompletion)_centralNotifyChangedCompletion;
-(void)setErrorCompletion:(BLECentralError)_centralErrorCompletion;
-(void)setFoundPeripheralHandler:(BLECentralFoundPeripheralHandler)_centralFoundPeripheralHandler;
-(void)setFoundServiceHandler:(BLECentralFoundServiceHandler)_centralFoundServiceHandler;
-(void)setFoundCharacteristicHandler:(BLECentralFoundCharacteristicsHandler)_centralFoundCharacteristicHandler;
-(void)setEnumerateCharacteristicsHandler:(BLECentralEnumerateCharacteristicsHandler)_centralEnumerateCharacteristicsHandler;
-(void)setDisconnectHandler:(BLECentralDisconnectHandler)_bleDisconnectHandler;

@end

@protocol BLECentralControllerDelegate <NSObject>

@required

//...

@optional

//Central 成功找到指定的服務碼
-(void)bleCentralDidDiscoverServices:(CBPeripheral *)peripheral error:(NSError *)error;

//Central 成功找到指定服務碼裡的特徵碼
-(void)bleCentralDidDiscoverCharacteristicsForService:(CBService *)service withPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;

//Central 成功寫資料給 Peripheral 時
-(void)bleCentralDidWriteValueForPeripheral:(CBPeripheral *)peripheral withCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error;

//Central 讀取到 Peripheral 回應的資料時
-(void)bleCentralDidReadValueFromPeripheral:(CBPeripheral *)peripheral withCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error;

//Central 成功接收到 Peripheral Notify 通知的資料時
-(void)bleCentralManager:(CBCentralManager *)centralManager didUpdateNotificationForPeripheral:(CBPeripheral *)peripheral withCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error;

//Central 與 Peripheral 斷線時
-(void)bleCentralDidDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;


@end