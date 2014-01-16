//
//  BLEPeripheralController.h
//  BLEKit
//
//  Created by Kalvar, ilovekalvar@gmail.com on 2013/12/9.
//  Copyright (c) 2013 - 2014年 Kuo-Ming Lin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

//Peripheral 收到 Central 的讀取請求時
typedef void(^BLEPeripheralReceivedReadRequestHandler)(CBPeripheralManager *peripheralManager, CBATTRequest *cbATTRequest);

//Peripheral 收到 Central 送來的資料時
typedef void(^BLEPeripheralReceivedWriteRequestHandler)(CBPeripheralManager *peripheralManager, NSArray *cbAttRequests, NSMutableData *receivedData);

//Peripheral 準備好要連結時 ( 狀態更新時 )
typedef void(^BLEPeripheralUpdateStateHandler)(CBPeripheralManager *peripheralManager, CBPeripheralManagerState peripheralState, BOOL supportBLE);

//Peripheral 準備開始送資料給 Central 時
typedef BOOL(^BLEPeripheralReadyTransferHandler)(CBPeripheralManager *peripheral, CBCentral *central, CBCharacteristic *characteristic);

//Peripheral 持續送出資料給 Central 時
typedef void(^BLEPeripheralSppTransferHandler)(BOOL success, NSInteger chunkIndex, NSData *chunk, CGFloat progress);

//Peripheral 送出資料給 Central 完成時
//-(BOOL)updateValue:(NSData *)value forCharacteristic:(CBMutableCharacteristic *)characteristic onSubscribedCentrals:(NSArray *)centrals;
typedef void(^BLEPeripheralSppTransferCompletion)(CBPeripheralManager *peripheralManager, CGFloat progress);

//Peripheral 準備送出下一個封包時觸發
typedef void(^BLEPeripheralReadyTransferNextChunkHandler)(CBPeripheralManager *peripheralManager, CGFloat progress);

//Peripheral 發生 Exceptions 時
typedef void(^BLEPeripheralError)(NSError *error);

//Central 取消訂閱時觸發
typedef void(^BLEPeripheralCentralCancelSubscribeCompletion)(CBPeripheralManager *peripheralManager, CBCentral *central, CBCharacteristic *characteristic);


@protocol BLEPeripheralControllerDelegate;


@interface BLEPeripheralController : NSObject<CBPeripheralManagerDelegate>
{
    
}


@property (nonatomic, copy) BLEPeripheralReceivedReadRequestHandler readRequestHandler;
@property (nonatomic, copy) BLEPeripheralReceivedWriteRequestHandler writeRequestHandler;
@property (nonatomic, copy) BLEPeripheralUpdateStateHandler updateStateHandler;
@property (nonatomic, copy) BLEPeripheralReadyTransferHandler readyTranferHandler;
@property (nonatomic, copy) BLEPeripheralSppTransferHandler sppTransferHandler;
@property (nonatomic, copy) BLEPeripheralSppTransferCompletion sppTransferCompletion;
@property (nonatomic, copy) BLEPeripheralReadyTransferNextChunkHandler readyTransferNextChunkHandler;
@property (nonatomic, copy) BLEPeripheralError errorCompletion;
@property (nonatomic, copy) BLEPeripheralCentralCancelSubscribeCompletion centralCancelSubscribeCompletion;


@property (nonatomic, strong) id<BLEPeripheralControllerDelegate> delegate;
@property (nonatomic, strong) CBPeripheralManager       *peripheralManager;

@property (nonatomic, strong) NSMutableData *receivedData;

//通知用的特徵碼 ( 待修 )
@property (nonatomic, strong) CBMutableCharacteristic   *notifyCharacteristic;
//讀寫用的特徵碼 ( 待修 )
@property (nonatomic, strong) CBMutableCharacteristic   *readwriteCharacteristic;

@property (nonatomic, strong) NSData                    *sendData;
@property (nonatomic, readwrite) NSInteger              sendDataIndex;
@property (nonatomic, assign) NSInteger                 dataLength;

@property (nonatomic, assign) CGFloat                   progress;
//SPP 傳輸資料結束時的最後一筆 BOM 結尾 ( 通知結束 )
@property (nonatomic, strong) NSString                  *eomEndHeader;



+(BLEPeripheralController *)shareInstance;
-(BLEPeripheralController *)initWithDelegate:(id<BLEPeripheralControllerDelegate>)_bleDelegate;

#pragma --mark Peripheral Methods
-(BOOL)supportBLE;
-(void)startAdvertisingAtServiceUUID:(NSString *)_serviceUUID;
-(void)startAdvertising;
-(void)stopAdvertising;
-(void)clearReceivedData;
-(void)clearSendData;
-(void)transferData;

#pragma --mark Setting Blocks
-(void)setReadRequestHandler:(BLEPeripheralReceivedReadRequestHandler)_peripheralReadRequestHandler;
-(void)setWriteRequestHandler:(BLEPeripheralReceivedWriteRequestHandler)_peripheralWriteRequestHandler;
-(void)setUpdateStateHandler:(BLEPeripheralUpdateStateHandler)_peripheralUpdateStateHandler;
-(void)setReadyTranferHandler:(BLEPeripheralReadyTransferHandler)_peripheralReadyTranferHandler;
-(void)setSppTransferHandler:(BLEPeripheralSppTransferHandler)_peripheralSppTransferHandler;
-(void)setSppTransferCompletion:(BLEPeripheralSppTransferCompletion)_peripheralSppTransferCompletion;
-(void)setReadyTransferNextChunkHandler:(BLEPeripheralReadyTransferNextChunkHandler)_peripheralReadyTransferNextChunkHandler;
-(void)setErrorCompletion:(BLEPeripheralError)_peripheralErrorCompletion;
-(void)setCentralCancelSubscribeCompletion:(BLEPeripheralCentralCancelSubscribeCompletion)_peripheralCentralCancelSubscribeCompletion;

@end

@protocol BLEPeripheralControllerDelegate <NSObject>

@required

//...

@optional

//Peripheral 收到 Central 的讀取請求時
-(void)blePeripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)cbATTRequest;
//Peripheral 收到 Central 送來的資料時
-(void)blePeripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)cbAttRequests;
//Peripheral 送出資料給 Central 完成時
-(void)blePeripheralManagerDidFinishedTransferForCentral:(CBPeripheralManager *)peripheral;
//Peripheral 狀態更新時
-(void)blePeripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral supportBLE:(BOOL)_supportBLE;
//Peripheral 取得 Central 訂閱特徵碼時觸發 ( 同時在這裡開始傳送資料給 Central )
-(BOOL)blePeripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic;
//Central 取消訂閱時觸發 ( setNotify 為 NO 時 )
- (void)blePeripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didCancelSubscribeFromCharacteristic:(CBCharacteristic *)characteristic;
//當 Peripheral 使用 updateValue 方法後，就會觸發這裡再傳送下一個封包。
-(void)blePeripheralManagerIsReadyToSendNextChunk:(CBPeripheralManager *)peripheral;


@end