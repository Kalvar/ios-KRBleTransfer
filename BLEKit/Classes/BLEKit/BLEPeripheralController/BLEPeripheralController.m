//
//  BLEPeripheralController.m
//  BLEKit
//
//  Created by Kalvar, ilovekalvar@gmail.com on 2013/12/9.
//  Copyright (c) 2013 - 2014年 Kuo-Ming Lin. All rights reserved.
//

#import "BLEPeripheralController.h"
#import "BLEPorts.h"

//BLE allows Max 24 Chars ( 字節 )，但實測後，iOS 卻只允許 20 Bytes
#define NOTIFY_MTU      20

@interface BLEPeripheralController ()

@property (nonatomic, assign) NSTimer *_timer;
@property (nonatomic, assign) NSInteger _times;

@property (nonatomic, assign) BOOL _finishedTransfer;

@end

@implementation BLEPeripheralController (fixPrivate)

-(void)_initWithVars
{
    NSLog(@"peripheral _initWithVars");
    
    self.readRequestHandler       = nil;
    self.writeRequestHandler      = nil;
    
    self.updateStateHandler       = nil;
    self.readyTranferHandler      = nil;
    self.sppTransferCompletion    = nil;
    self.sppTransferHandler       = nil;
    self.readyTransferNextChunkHandler = nil;
    
    self.errorCompletion = nil;
    
    self.centralCancelSubscribeCompletion = nil;
    
    self.delegate          = nil;
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    self.receivedData      = [NSMutableData new];
    self.progress          = 0.0f;
    self.dataLength        = 0;
    
    self.eomEndHeader      = nil; //@"BOM";
    
    self._timer = nil;
    self._times = 0;
    
    self._finishedTransfer = NO;
}


-(void)_countTimes
{
    if( self._times < 1 )
    {
        self._times = 0;
    }
    ++self._times;
    //NSLog(@"%i sec.", self._times);
}

@end

@implementation BLEPeripheralController

@synthesize readRequestHandler       = _readRequestHandler;
@synthesize writeRequestHandler      = _writeRequestHandler;

@synthesize updateStateHandler       = _updateStateHandler;
@synthesize readyTranferHandler      = _readyTranferHandler;
@synthesize sppTransferHandler       = _sppTransferHandler;
@synthesize sppTransferCompletion    = _sppTransferCompletion;
@synthesize readyTransferNextChunkHandler = _readyTransferNextChunkHandler;

@synthesize errorCompletion          = _errorCompletion;

@synthesize centralCancelSubscribeCompletion = _centralCancelSubscribeCompletion;

@synthesize delegate = _delegate;
@synthesize peripheralManager = _peripheralManager;
@synthesize receivedData = _receivedData;
@synthesize progress;
@synthesize dataLength;

@synthesize eomEndHeader = _eomEndHeader;

@synthesize _timer;
@synthesize _times;
@synthesize _finishedTransfer;


+(BLEPeripheralController *)shareInstance
{
    static dispatch_once_t pred;
    static BLEPeripheralController *_sharedInstance = nil;
    dispatch_once(&pred, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

-(id)init
{
    self = [super init];
    if( self )
    {
        [self _initWithVars];
    }
    return self;
}

-(BLEPeripheralController *)initWithDelegate:(id<BLEPeripheralControllerDelegate>)_bleDelegate
{
    self = [super init];
    if( self )
    {
        [self _initWithVars];
        _delegate = _bleDelegate;
    }
    return self;
}

#pragma --mark Peripheral Methods
-(BOOL)supportBLE
{
    NSString * state = @"";
    BOOL _isSupport  = NO;
    switch ([self.peripheralManager state])
    {
        case CBPeripheralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBPeripheralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBPeripheralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBPeripheralManagerStatePoweredOn:
            state = @"The device supports BLE.";
            _isSupport = YES;
            break;
        case CBPeripheralManagerStateUnknown:
            state = @"The device has unknown problem.";
        default: break;
    }
    NSLog(@"Peripheral manager state: %@", state);
    return _isSupport;
}

-(void)startAdvertisingAtServiceUUID:(NSString *)_serviceUUID
{
    if( self.peripheralManager )
    {
        [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:_serviceUUID]] }];
    }
}

-(void)startAdvertising
{
    //使用 BLE_CUSTOM_SERVICE_UUID 進行廣播的動作
    [self startAdvertisingAtServiceUUID:BLE_CUSTOM_SERVICE_UUID];
}

-(void)stopAdvertising
{
    if( self.peripheralManager )
    {
        [self.peripheralManager stopAdvertising];
    }
}

/*
 * @ 清除 Peripheral 從 Central 接收到的資料
 */
-(void)clearReceivedData
{
    if( self.receivedData )
    {
        self.receivedData = nil;
        _receivedData     = [NSMutableData new];
        [_receivedData setLength:0];
    }
}

/*
 * @ 清除要傳輸的資料
 */
-(void)clearSendData
{
    if( self.sendData )
    {
        self.sendData = nil;
    }
    
    if( self.sendDataIndex != 0 )
    {
        self.sendDataIndex = 0;
    }
    
    if( self.dataLength != 0 )
    {
        self.dataLength = 0;
    }
}

/*
 * @ 模擬 SPP 傳輸檔案
 */
-(void)transferData
{
    if( !self.sendData )
    {
        return;
    }
    
    if( self.dataLength <= 0 )
    {
        self.dataLength = [self.sendData length];
    }
    self.progress = [[NSString stringWithFormat:@"%.2f",
                              ( (float)(self.sendDataIndex) / self.dataLength ) * 100.0f] floatValue];
    
    if (self._finishedTransfer)
    {
        if( self.eomEndHeader && [_eomEndHeader isKindOfClass:[NSString class]] )
        {
            if( [_eomEndHeader length] > 0 )
            {
                BOOL didSend = [self.peripheralManager updateValue:[self.eomEndHeader dataUsingEncoding:NSUTF8StringEncoding]
                                                 forCharacteristic:self.notifyCharacteristic onSubscribedCentrals:nil];
                
                if (didSend)
                {
                    self._finishedTransfer = NO;
                    [self.peripheralManager stopAdvertising];
                    if( self.sppTransferCompletion )
                    {
                        _sppTransferCompletion(self.peripheralManager, self.progress);
                    }
                    NSLog(@"Sent 1: EOM");
                }
            }
        }
        return;
    }
    
    if (self.sendDataIndex >= self.dataLength)
    {
        return;
    }
    
    BOOL didSend = YES;
    
    while (didSend)
    {
        //NSLog(@"x3");
        NSInteger amountToSend = self.dataLength - self.sendDataIndex;
        
        //NSLog(@"%i = %i - %i", amountToSend, self.sendData.length, self.sendDataIndex);
        
        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU)
        {
            amountToSend = NOTIFY_MTU;
        }
        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytes:self.sendData.bytes+self.sendDataIndex length:amountToSend];
        
        //NSLog(@"chunk : %@", chunk);
        
        /*
         * @ 送封包給 Central
         *   - 會觸發 - (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral 送下一個封包，
         *     如果發送失敗，就會再進到這裡再跑一次遞迴重傳封包，直到本次封包傳輸成功為止。
         */
        didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.notifyCharacteristic onSubscribedCentrals:nil];
        
        // If it didn't work, drop out and wait for the callback
        if (!didSend)
        {
            //NSLog(@"x4 : %@", self.notifyCharacteristic);
            /*
            if( self.sppTransferHandler )
            {
                _sppTransferHandler(NO, self.sendDataIndex, chunk, self.progress);
            }
             */
            return;
        }
        
        // It did send, so update our index
        self.sendDataIndex += amountToSend;
        
        NSLog(@"Sent chunk: %@", chunk);
        NSLog(@"sendDataIndex : %i", self.sendDataIndex);
        
        if( self.sppTransferHandler )
        {
            _sppTransferHandler(YES, self.sendDataIndex, chunk, self.progress);
        }
        
        //是最後一筆封包
        if (self.sendDataIndex >= self.dataLength)
        {
            self._finishedTransfer = YES;
            //停止廣播，同時停止其使用 Notify 屬性的特徵碼繼續傳送資料給 Central
            //[self.peripheralManager stopAdvertising];
            
            /*
             * @ 2013.12.11 PM 13:45
             * @ 一個奇怪的問題，待解，但目前運作正常 XD
             *   - 這裡在使用 updateValue 送封包時，第 1 次都會送不出去，第 2 次才會送成功，這跟使用 updateValue 方法的原意不對，
             *     所以這裡送資料的流程才會實際上結尾的封包是在上面的 " Sent 1: EOM " 裡發送成功。
             *
             *     猜測，會否是 Central 還來不及解析完成，就送出了第 2 包，所以被 Central 拒收，直到線程可以收資料時，才接收 Peripheral 傳輸的封包 ?
             */
            if( self.eomEndHeader && [_eomEndHeader isKindOfClass:[NSString class]] )
            {
                if( [_eomEndHeader length] > 0 )
                {
                    BOOL eomSent = [self.peripheralManager updateValue:[self.eomEndHeader dataUsingEncoding:NSUTF8StringEncoding]
                                                     forCharacteristic:self.notifyCharacteristic
                                                  onSubscribedCentrals:nil];
                    
                    if (eomSent)
                    {
                        self._finishedTransfer = NO;
                        NSLog(@"Sent 2 : EOM");
                    }
                }
            }
            
            /*
            if( self.delegate )
            {
                if( [_delegate respondsToSelector:@selector(blePeripheralManagerDidFinishedTransferForCentral:)] )
                {
                    [_delegate blePeripheralManagerDidFinishedTransferForCentral:self.peripheralManager];
                }
            }
            
            self._finishedTransfer = NO;
            if( self.sppTransferCompletion )
            {
                _sppTransferCompletion(self.peripheralManager, self.progress);
            }
             */
            
            return;
        }
    }
}

#pragma --mark Setting Blocks
-(void)setReadRequestHandler:(BLEPeripheralReceivedReadRequestHandler)_peripheralReadRequestHandler
{
    _readRequestHandler = _peripheralReadRequestHandler;
}

-(void)setWriteRequestHandler:(BLEPeripheralReceivedWriteRequestHandler)_peripheralWriteRequestHandler
{
    _writeRequestHandler = _peripheralWriteRequestHandler;
}

-(void)setUpdateStateHandler:(BLEPeripheralUpdateStateHandler)_peripheralUpdateStateHandler
{
    _updateStateHandler = _peripheralUpdateStateHandler;
}

-(void)setReadyTranferHandler:(BLEPeripheralReadyTransferHandler)_peripheralReadyTranferHandler
{
    _readyTranferHandler = _peripheralReadyTranferHandler;
}

-(void)setSppTransferHandler:(BLEPeripheralSppTransferHandler)_peripheralSppTransferHandler
{
    _sppTransferHandler = _peripheralSppTransferHandler;
}

-(void)setSppTransferCompletion:(BLEPeripheralSppTransferCompletion)_peripheralSppTransferCompletion
{
    _sppTransferCompletion = _peripheralSppTransferCompletion;
}

-(void)setReadyTransferNextChunkHandler:(BLEPeripheralReadyTransferNextChunkHandler)_peripheralReadyTransferNextChunkHandler
{
    _readyTransferNextChunkHandler = _peripheralReadyTransferNextChunkHandler;
}

-(void)setErrorCompletion:(BLEPeripheralError)_peripheralErrorCompletion
{
    _errorCompletion = _peripheralErrorCompletion;
}

-(void)setCentralCancelSubscribeCompletion:(BLEPeripheralCentralCancelSubscribeCompletion)_peripheralCentralCancelSubscribeCompletion
{
    _centralCancelSubscribeCompletion = _peripheralCentralCancelSubscribeCompletion;
}

#pragma --mark Central Interacts Peripheral Read / Write Response Methods
/*
 * @ Peripheral 收到 Central 的讀取特徵碼資料的指令
 *   - //該特徵碼必須擁有「讀」的屬性權限才可作用此函式
 *     [peripheral readValueForCharacteristic:characteristic];
 *
 */
-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    if( self.delegate )
    {
        if( [_delegate respondsToSelector:@selector(blePeripheralManager:didReceiveReadRequest:)] )
        {
            [_delegate blePeripheralManager:peripheral didReceiveReadRequest:request];
        }
    }
    
    if( self.readRequestHandler )
    {
        _readRequestHandler(peripheral, request);
    }
}

/*
 * @ Peripheral 收到 Central 寫過來的數據
 *   - //該特徵碼必須擁有「寫」的屬性權限才可作用此函式
 *     NSData *_transferData   = [@"Hello World 123456789012345" dataUsingEncoding:NSUTF8StringEncoding];
 *     [peripheral writeValue:_transferData forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
 *
 */
-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    if( self.delegate )
    {
        if( [_delegate respondsToSelector:@selector(blePeripheralManager:didReceiveWriteRequests:)] )
        {
            [_delegate blePeripheralManager:peripheral didReceiveWriteRequests:requests];
        }
    }
    
    if( self.writeRequestHandler )
    {
        _writeRequestHandler(peripheral, requests, self.receivedData);
    }
}

#pragma --mark PeripheralManagerDelegate
/*
 * @ 已經開始廣播
 */
-(void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    // ... 待補
}

/*
 * @ 當 Peripheral 準備好時，就會觸發這裡的狀態更新
 */
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if( self.delegate )
    {
        if( [_delegate respondsToSelector:@selector(blePeripheralManagerDidUpdateState:supportBLE:)] )
        {
            [_delegate blePeripheralManagerDidUpdateState:peripheral supportBLE:[self supportBLE]];
        }
    }
    
    if( self.updateStateHandler )
    {
        //peripheral = PeripheralManager
        _updateStateHandler(peripheral, peripheral.state, [self supportBLE]);
    }
}

/*
 * @ Catch when someone subscribes to our characteristic, then start sending them data.
 *   取得 Central 訂閱我們的特徵碼時觸發，之後開始傳送資料給 Central
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central subscribed to characteristic");
    
    /*
    if( !self._timer )
    {
        //self._timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(_countTimes) userInfo:nil repeats:YES];
    }
    self.sendData = UIImagePNGRepresentation([UIImage imageNamed:@"test.png"]);
     */
    
    if( self.delegate )
    {
        if( [_delegate respondsToSelector:@selector(blePeripheralManager:central:didSubscribeToCharacteristic:)] )
        {
            [_delegate blePeripheralManager:peripheral central:central didSubscribeToCharacteristic:characteristic];
        }
    }
    
    if( self.readyTranferHandler )
    {
        _readyTranferHandler(peripheral, central, characteristic);
    }
    
    //self._dataLength = [self.sendData length];
    // Reset the index
    //self.sendDataIndex = 0;
    // Start sending
    //[self transferData];
}

/*
 * @ 當 Central 取消訂閱時觸發
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    if( self.delegate )
    {
        if([_delegate respondsToSelector:@selector(blePeripheralManager:central:didCancelSubscribeFromCharacteristic:)] )
        {
            [_delegate blePeripheralManager:peripheral central:central didCancelSubscribeFromCharacteristic:characteristic];
        }
    }
    
    if( self.centralCancelSubscribeCompletion )
    {
        _centralCancelSubscribeCompletion(peripheral, central, characteristic);
    }
}

/*
 *  @ This callback comes in when the PeripheralManager is ready to send the next chunk of data.
 *    This is to ensure that packets will arrive in the order they are sent.
 *    當 Peripheral 使用 updateValue 方法後，就會觸發這裡再傳送下一個封包。
 */
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    //NSLog(@"\n\n peripheralManagerIsReadyToUpdateSubscribers \n\n");
    if( self.delegate )
    {
        if( [_delegate respondsToSelector:@selector(blePeripheralManagerIsReadyToSendNextChunk:)] )
        {
            [_delegate blePeripheralManagerIsReadyToSendNextChunk:peripheral];
        }
    }
    
    if( self.readyTransferNextChunkHandler )
    {
        _readyTransferNextChunkHandler(peripheral, self.progress);
    }
    
    [self transferData];
}

@end