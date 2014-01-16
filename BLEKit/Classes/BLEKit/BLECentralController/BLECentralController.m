//
//  BLECentralController.m
//  BLEKit
//
//  Created by Kalvar, ilovekalvar@gmail.com on 2013/12/9.
//  Copyright (c) 2013 - 2014年 Kuo-Ming Lin. All rights reserved.
//

#import "BLECentralController.h"
#import "BLEPorts.h"

static NSInteger _kRssiRejectsDefaultHighRange = -15;
static NSInteger _kRssiRejectsDefaultLowRange  = -35;

@interface BLECentralController ()
{
    
}

@end

@implementation BLECentralController (fixPrivate)

-(void)_initWithVars
{
    //NSLog(@"central _initWithVars");
    
    //另外為 Central 開一條 Thread
    //看能否避免 CoreBluetooth[WARNING] <CBCentralManager: 0x16d94770> is disabling duplicate filtering, but is using the default queue (main thread) for delegate events
    //http://stackoverflow.com/questions/18970247/cbcentralmanager-changes-for-ios-7
    dispatch_queue_t _centralQueue = dispatch_queue_create("com.central.blekit", DISPATCH_QUEUE_SERIAL);// or however you want to create your dispatch_queue_t
    
    self.updateStateHandler              = nil;
    self.writeCompletion                 = nil;
    self.receiveCompletion               = nil;
    self.notifyChangedCompletion         = nil;
    self.errorCompletion                 = nil;
    self.foundPeripheralHandler          = nil;
    self.foundServiceHandler             = nil;
    self.foundCharacteristicHandler      = nil;
    self.enumerateCharacteristicsHandler = nil;
    self.disconnectHandler               = nil;
    
    self.delegate              = nil;
    //self.centralManager        = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    self.centralManager        = [[CBCentralManager alloc] initWithDelegate:self queue:_centralQueue];
    self.discoveredPeripheral  = nil;
    self.combinedData          = [[NSMutableData alloc] init];
    
    self.discoveredServices    = [[NSMutableDictionary alloc] initWithCapacity:0];
    self.supportServicesCBUUID = [[NSMutableArray alloc] init];
    self.rssiRejectsHighRange  = _kRssiRejectsDefaultHighRange;
    self.rssiRejectsLowRange   = _kRssiRejectsDefaultLowRange;
    self.rssi                  = 0;
    self.advertisementInfo     = nil;
    self.peripheralName        = @"";
    
    self.isDisconnected        = YES;
    self.isConnecting          = NO;
    self.isConnected           = NO;
    
    self.isOpenLimitConnection = YES;
    self.autoReconnect         = NO;
    
}

@end

@implementation BLECentralController

@synthesize updateStateHandler              = _updateStateHandler;
@synthesize writeCompletion                 = _writeCompletion;
@synthesize receiveCompletion               = _receiveCompletion;
@synthesize notifyChangedCompletion         = _notifyChangedCompletion;
@synthesize errorCompletion                 = _errorCompletion;
@synthesize foundPeripheralHandler          = _foundPeripheralHandler;
@synthesize foundServiceHandler             = _foundServiceHandler;
@synthesize foundCharacteristicHandler      = _foundCharacteristicHandler;
@synthesize enumerateCharacteristicsHandler = _enumerateCharacteristicsHandler;
@synthesize disconnectHandler               = _disconnectHandler;

@synthesize delegate             = _delegate;
@synthesize centralManager       = _centralManager;
@synthesize discoveredPeripheral = _discoveredPeripheral;
@synthesize combinedData         = _combinedData;

@synthesize discoveredServices;
@synthesize supportServicesCBUUID;
@synthesize rssiRejectsHighRange;
@synthesize rssiRejectsLowRange;
@synthesize rssi;
@synthesize advertisementInfo;
@synthesize peripheralName;
@synthesize isDisconnected;
@synthesize isConnecting;
@synthesize isConnected;

@synthesize isOpenLimitConnection;
@synthesize autoReconnect;


+(BLECentralController *)shareInstance
{
    static dispatch_once_t pred;
    static BLECentralController *_sharedInstance = nil;
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

-(BLECentralController *)initWithDelegate:(id<BLECentralControllerDelegate>)_bleDelegate
{
    self = [super init];
    if( self )
    {
        [self _initWithVars];
        _delegate = _bleDelegate;
    }
    return self;
}

#pragma --mark Scanning Methods
/*
 * @ 是否支援 BLE
 */
-(BOOL)supportBLE
{
    NSString * state = @"";
    BOOL _isSupport  = NO;
    switch ([self.centralManager state])
    {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            state      = @"The device supports BLE.";
            _isSupport = YES;
            break;
        case CBCentralManagerStateUnknown:
            state = @"The device has unknown problem.";
        default: break;
    }
    NSLog(@"Central manager state: %@", state);
    return _isSupport;
}

/*
 * @ Central 開始掃描 Peripherals
 */
-(void)startScanPeripherals
{
    if( self.centralManager )
    {
        if( self.supportServicesCBUUID && [self.supportServicesCBUUID count] > 0 )
        {
            //搜尋特定服務 UUID
            //@[[CBUUID UUIDWithString:BLE_CUSTOM_SERVICE_UUID]]
            //@YES ( 為何不是 NO ? )
            [self.centralManager scanForPeripheralsWithServices:self.supportServicesCBUUID
                                                        options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
        }
        else
        {
            //搜尋全部服務 UUID
            [self.centralManager scanForPeripheralsWithServices:nil
                                                        options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
        }
    }
}

/*
 * @ Central 停止掃描 Peripherals
 */
-(void)stopScanPeripherals
{
    if( self.centralManager )
    {
        [self.centralManager stopScan];
    }
}

/*
 * @ BLE 會在停止交互作用後的 6 秒鐘自動斷線，此時會進入 didDisconnectPeripheral 的委派裡
 */
/*
 * @ Central 停止掃描與中斷連結
 */
-(void)stopScanAndCancelConnect
{
    [self stopScanPeripherals];
    [self cleanAllConnections];
    //[self cancelConnecting];
}

/*
 * @ 新增服務碼與其擁有的特徵碼
 *   - _characteristics : 裡面的值都必須為 CBUUID 格式
 */
-(void)addCharacteristicsCBUUID:(NSArray *)_characteristicsCBUUID forService:(NSString *)_serviceUUID
{
    [self.discoveredServices setValue:_characteristicsCBUUID forKey:_serviceUUID];
}

/*
 * @ 刷新支援的服務碼項目
 */
-(void)refreshSupportServices
{
    if( self.discoveredServices )
    {
        if( [self.discoveredServices count] > 0 )
        {
            if( [self.supportServicesCBUUID count] > 0 )
            {
                [self.supportServicesCBUUID removeAllObjects];
            }
            [[self.discoveredServices allKeys] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
            {
                if( ![obj isKindOfClass:[CBUUID class]] )
                {
                    [self.supportServicesCBUUID addObject:[CBUUID UUIDWithString:(NSString *)obj]];
                }
                else
                {
                    [self.supportServicesCBUUID addObject:(CBUUID *)obj];
                }
            }];
        }
    }
}

/*
 * @ 設定特徵碼為可接收通知的狀態
 *   - 只有特徵碼屬性為 CBCharacteristicPropertyNotify 和 CBAttributePermissionsReadable 才行。
 */
-(void)setCharacteristicBeNotifyValues:(NSArray *)_characteristics
{
    [_characteristics enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
    {
        //設定特徵碼通知
        CBCharacteristic *_notifyCharacteristic = (CBCharacteristic *)obj;
        //這裡完成後會觸發這裡實作的 Peripheral 委派 : - (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
        [self.discoveredPeripheral setNotifyValue:YES forCharacteristic:_notifyCharacteristic];
    }];
}

/** Call this when things either go wrong, or you're done with the connection.
 *  This cancels any subscriptions if there are any, or straight disconnects if not.
 *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
 */
-(void)cleanAllConnections
{
    // Don't do anything if we're not connected
    if ( !self.isConnected )
    {
        return;
    }
    
    //NSLog(@"self.discoveredPeripheral.services : %@", self.discoveredPeripheral.services);
    
    // See if we are subscribed to a characteristic on the peripheral
    if (self.discoveredPeripheral.services != nil)
    {
        for (CBService *service in self.discoveredPeripheral.services)
        {
            if (service.characteristics != nil)
            {
                for (CBCharacteristic *characteristic in service.characteristics)
                {
                    //[characteristic.UUID isEqual:[CBUUID UUIDWithString:NOTIFY_CHARACTERISTIC_UUID]]
                    if( characteristic.properties == CBCharacteristicPropertyNotify )
                    {
                        if (characteristic.isNotifying)
                        {
                            // It is notifying, so unsubscribe
                            [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            // And we're done.
                            //return;
                        }
                    }
                }
            }
        }
    }
    
    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}

/*
 * @ 取消與 Peripheral 的連結
 */
-(void)cancelConnecting
{
    if( self.centralManager && self.discoveredPeripheral )
    {
        [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
    }
}

/*
 * @ 取消該特徵碼的通知動作
 */
-(void)cancelNotifyWithCharacteristic:(CBCharacteristic *)_characteristic completion:(BLECentralNotifyChangedCompletion)_completion
{
    if( self.discoveredPeripheral && _characteristic )
    {
        self.notifyChangedCompletion = _completion;
        [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:_characteristic];
    }
}

/*
 * @ 重新搜尋服務
 */
-(void)refreshDiscoverServices:(NSArray *)_services foundServiceCompletion:(BLECentralFoundServiceHandler)_serviceCompletion enumerateCharacteristicHandler:(BLECentralEnumerateCharacteristicsHandler)_characteristicHandler
{
    if( self.discoveredPeripheral )
    {
        if( _serviceCompletion )
        {
            _foundServiceHandler = _serviceCompletion;
        }
        
        if( _characteristicHandler )
        {
            _enumerateCharacteristicsHandler = _characteristicHandler;
        }
        
        [self.discoveredPeripheral discoverServices:_services];
    }
}

#pragma --mark Read / Write with Peripheral
-(void)writeValueForPeripheralWithCharacteristic:(CBCharacteristic *)_characteristic data:(NSData *)_data completion:(BLECentralWriteCompletion)_completion
{
    if( self.discoveredPeripheral && _data )
    {
        self.writeCompletion = _completion;
        [_discoveredPeripheral writeValue:_data forCharacteristic:_characteristic type:CBCharacteristicWriteWithResponse];
    }
}

-(void)readValueFromPeripheralWithCharacteristic:(CBCharacteristic *)_characteristic completion:(BLECentralReceiveCompletion)_completion
{
    if( self.discoveredPeripheral )
    {
        self.receiveCompletion = _completion;
        [_discoveredPeripheral readValueForCharacteristic:_characteristic];
    }
}

#pragma --mark Getters
-(NSInteger)rssi
{
    return [[_discoveredPeripheral RSSI] integerValue];
}

-(BOOL)isDisconnected
{
    return ( [_discoveredPeripheral state] == CBPeripheralStateDisconnected );
}

-(BOOL)isConnecting
{
    return ( [_discoveredPeripheral state] == CBPeripheralStateConnecting );
}

-(BOOL)isConnected
{
    return ( [_discoveredPeripheral state] == CBPeripheralStateConnected );
}

#pragma --mark Setter Blocks
-(void)setUpdateStateHandler:(BLECentralUpdateStateHandler)_centralUpdateStateHandler
{
    _updateStateHandler = _centralUpdateStateHandler;
}

-(void)setWriteCompletion:(BLECentralWriteCompletion)_centralWriteCompletion
{
    _writeCompletion = _centralWriteCompletion;
}

-(void)setReceiveCompletion:(BLECentralReceiveCompletion)_centralReceiveCompletion
{
    _receiveCompletion = _centralReceiveCompletion;
}

-(void)setNotifyChangedCompletion:(BLECentralNotifyChangedCompletion)_centralNotifyChangedCompletion
{
    _notifyChangedCompletion = _centralNotifyChangedCompletion;
}

-(void)setErrorCompletion:(BLECentralError)_centralErrorCompletion
{
    _errorCompletion = _centralErrorCompletion;
}

-(void)setFoundPeripheralHandler:(BLECentralFoundPeripheralHandler)_centralFoundPeripheralHandler
{
    _foundPeripheralHandler = _centralFoundPeripheralHandler;
}

-(void)setFoundServiceHandler:(BLECentralFoundServiceHandler)_centralFoundServiceHandler
{
    _foundServiceHandler = _centralFoundServiceHandler;
}

-(void)setFoundCharacteristicHandler:(BLECentralFoundCharacteristicsHandler)_centralFoundCharacteristicHandler
{
    _foundCharacteristicHandler = _centralFoundCharacteristicHandler;
}

-(void)setEnumerateCharacteristicsHandler:(BLECentralEnumerateCharacteristicsHandler)_centralEnumerateCharacteristicsHandler
{
    _enumerateCharacteristicsHandler = _centralEnumerateCharacteristicsHandler;
}

-(void)setDisconnectHandler:(BLECentralDisconnectHandler)_bleDisconnectHandler
{
    _disconnectHandler = _bleDisconnectHandler;
}

#pragma --mark CentralManagerDelegate
/*
 * @ Once the disconnection happens, we need to clean up our local copy of the peripheral
 *   與外設斷線時觸發。
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral Disconnected");
    self.discoveredPeripheral = nil;
    
    if( self.delegate )
    {
        if( [_delegate respondsToSelector:@selector(bleCentralDidDisconnectPeripheral:error:)] )
        {
            [_delegate bleCentralDidDisconnectPeripheral:peripheral error:error];
        }
    }
    
    if( self.disconnectHandler )
    {
        _disconnectHandler(peripheral);
    }
    
    if( self.autoReconnect )
    {
        // We're disconnected, so start scanning again
        [self startScanPeripherals];
    }
}

/*
 * @ Invoked whenever a connection is succesfully created with the peripheral.
 *   Discover available services on the peripheral
 *   開始尋找外設支援的服務
 *
 * @ Central Device 的目前支援狀態
 *   - 第 1 次連結時，都會自動被系統帶入觸發這裡。
 */
-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if( self.updateStateHandler )
    {
        _updateStateHandler(central, [self supportBLE]);
    }
    else
    {
        if ( ![self supportBLE] )
        {
            return;
        }
        [self startScanPeripherals];
    }
}

/*
 * @ Invoked whenever an existing connection with the peripheral is torn down.
 *   Reset local variables
 *   與外設斷線時觸發。
 *
 * @ Central 發現 Peripheral
 *   - central           : 中央設備
 *   - advertisementData : 取得 Peripheral 所發出的廣播資訊，包含 " Device Name ", " Device Identifier ",  " Device Characteristic " 等
 *   - RSSI              : 訊號強度
 */
-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    /*
     * @ 這裡是所有的 Peripheral 所廣播帶來的 Device Infomation include in : 
     *   - " Device Name "
     *   - " Device Identifier "
     *   - " Device Characteristic " 等。
     */
    //NSLog(@"advertisementData : %@", advertisementData);
    
    if( self.isOpenLimitConnection )
    {
        // Reject any where the value is above reasonable range
        // -15
        if (RSSI.integerValue > self.rssiRejectsHighRange)
        {
            return;
        }
        
        // Reject if the signal strength is too low to be close enough (Close is around -22dB)
        // -35
        if (RSSI.integerValue < self.rssiRejectsLowRange)
        {
            return;
        }
    }
    
    self.advertisementInfo = advertisementData;
    self.rssi              = [RSSI integerValue];
    self.peripheralName    = peripheral.name;
    
    //NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
    // Ok, it's in range - have we already seen it?
    if (self.discoveredPeripheral != peripheral)
    {
        // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
        self.discoveredPeripheral = peripheral;
        if( self.foundPeripheralHandler )
        {
            _foundPeripheralHandler(self.centralManager, peripheral, advertisementData, [RSSI integerValue]);
        }
        else
        {
            // And connect
            NSLog(@"Connecting to peripheral %@", peripheral);
            [self.centralManager connectPeripheral:peripheral options:nil];
            
        }
    }
}

/*
 * @ Invoked whenever the central manager fails to create a connection with the peripheral.
 *   無法建立與外設的連線時觸發。
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    [self cleanAllConnections];
}

/*
 * @ Invoked whenever a connection is succesfully created with the peripheral.
 *   Discover available services on the peripheral
 *   已連接外設，並開始尋找外設的服務
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    // Stop scanning
    [self.centralManager stopScan];
    
    //NSLog(@"Peripheral Connected : %@", peripheral);
    NSLog(@"Scanning stopped");
    
    // Clear the data that we may already have
    [self.combinedData setLength:0];
    
    // Make sure we get the discovery callbacks
    peripheral.delegate = self;
    
    // Search only for services that match our UUID
    // @[[CBUUID UUIDWithString:BLE_CUSTOM_SERVICE_UUID]]
    [peripheral discoverServices:self.supportServicesCBUUID];
}

#pragma --mark PeripheralDelegate
/*
 * @ Invoked upon completion of a -[discoverServices:] request.
 *   當 -[discoverServices:] 請求完成後調用。
 *   即發現服務時，會調用這裡。
 *
 * @ 可在這裡限定當下要連結的「指定特徵碼」為何，以便於在 didDiscoverCharacteristicsForService 的函式裡，可以單純的連接要作動的特徵碼。
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    //這一個 Delegate 只是寫來備用，原則上是用不到的
    //有實作本 Delegate 的話，一切的主控權就會改至該 Delegate 方法裡執行，而不再向下運作
    //這裡推薦使用 Blocks 來作流程控制
    if( self.delegate )
    {
        if( [_delegate respondsToSelector:@selector(bleCentralDidDiscoverServices:error:)] )
        {
            [_delegate bleCentralDidDiscoverServices:peripheral error:error];
            return;
        }
    }
    
    if ( error )
    {
        //NSLog(@"Error discovering services: %@", [error localizedDescription]);
        [self cleanAllConnections];
        return;
    }
    
    //NSLog(@"peripheral.services : %@", peripheral.services);
    
    //比對支援與允許的服務
    [self.supportServicesCBUUID enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
    {
        //NSString *_supportServiceUUID = (NSString *)obj;
        //將 Peripheral 的服務都取出來
        for (CBService *service in peripheral.services)
        {
            //如果發現的 Peripheral 服務等於限定支援的服務
            //[CBUUID UUIDWithString:_supportServiceUUID]
            if ([service.UUID isEqual:obj])
            {
                NSLog(@"Service found with UUID : %@", service.UUID);
                //有 Block 就把主控權轉交至 Block 裡
                if( self.foundServiceHandler )
                {
                    _foundServiceHandler(peripheral, self.discoveredServices, service);
                    continue;
                }
                else
                {
                    //找尋特徵碼 ( 即服務類別裡的子服務 )
                    //當這裡的方法被執行後，會觸發下方的委派 - (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
                    //直接將 CBUUID 強轉成 NSString
                    [peripheral discoverCharacteristics:[self.discoveredServices objectForKey:(NSString *)[service.UUID description]]
                                             forService:service];
                }
            }
        }
    }];
}


/*
 * @ Invoked upon completion of a -[discoverCharacteristics:forService:] request.
 *   當 - [discoverCharacteristics：forService：] 請求完成後調用。
 *   即找到服務裡的特徵碼 ( 例如，心跳帶裡的「人身部位偵測服務」底下的「腰部位置」 )
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if( self.delegate )
    {
        if( [_delegate respondsToSelector:@selector(bleCentralDidDiscoverCharacteristicsForService:withPeripheral:error:)] )
        {
            [_delegate bleCentralDidDiscoverCharacteristicsForService:service withPeripheral:peripheral error:error];
        }
    }
    
    if( self.foundCharacteristicHandler )
    {
        _foundCharacteristicHandler(peripheral, service, error);
    }
    
    // Deal with errors (if any)
    if (error)
    {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self cleanAllConnections];
        return;
    }
    
    //列舉並找出該服務裡所有的特徵碼
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if( self.enumerateCharacteristicsHandler )
        {
            _enumerateCharacteristicsHandler(peripheral, characteristic);
        }
        
        /*
        //是通知用的特徵碼
        //if( characteristic.properties == CBCharacteristicPropertyNotify )
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:NOTIFY_CHARACTERISTIC_UUID]])
        {
            NSLog(@"central here 1");
            //特徵碼必須為 Notify 屬性，It will need to subscribe to it ( Notify 屬性必須訂閱並註冊特徵碼，這裡才會真的完全連線 )
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        
        NSLog(@"UUID : %@", (NSString *)characteristic.UUID);
        //NSLog(@"characteristic.properties : %x", characteristic.properties);
        //NSLog(@"permissions : %x", characteristic.permissions);
        //NSLog(@"\n\n\n");
        
        //是讀寫值的特徵碼
        if( [characteristic.UUID isEqual:[CBUUID UUIDWithString:WRITE_CHARACTERISTIC_UUID]] )
        {
            
            NSLog(@"Central 連接 Write Characteristic.");
            //該特徵碼必須擁有「寫」的屬性權限才可作用此函式
            //NSData *_transferData   = [@"Hello World 12345678" dataUsingEncoding:NSUTF8StringEncoding];
            //[peripheral writeValue:_transferData forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            
            //該特徵碼必須擁有「讀」的屬性權限才可作用此函式
            //[peripheral readValueForCharacteristic:characteristic];
        }
        */
        
        /*
        //if( characteristic.properties == CBCharacteristicPropertyWrite )
        {
            NSLog(@"寫入的屬性 : %x", CBCharacteristicPropertyWrite);
        }
        
        //if( characteristic.properties == CBCharacteristicPropertyExtendedProperties )
        {
            NSLog(@"擴展的屬性 : %x", CBCharacteristicPropertyExtendedProperties);
        }
        
        //if( characteristic.properties == CBCharacteristicPropertyBroadcast )
        {
            NSLog(@"廣播的屬性 : %x", CBCharacteristicPropertyBroadcast);
        }
        
        //if( characteristic.properties == CBCharacteristicPropertyRead )
        {
            NSLog(@"讀取的屬性 : %x", CBCharacteristicPropertyRead);
        }
        
        //if( characteristic.properties == CBCharacteristicPropertyIndicate )
        {
            NSLog(@"提示的屬性 : %x", CBCharacteristicPropertyIndicate);
        }
        
        //if( characteristic.properties == CBCharacteristicPropertyAuthenticatedSignedWrites )
        {
            NSLog(@"認證簽名寫入的屬性 : %x", CBCharacteristicPropertyAuthenticatedSignedWrites);
        }
        
        //if( characteristic.properties == CBCharacteristicPropertyNotifyEncryptionRequired )
        {
            NSLog(@"通知加密需求的屬性 : %x", CBCharacteristicPropertyNotifyEncryptionRequired);
        }
        
        //if( characteristic.properties == CBCharacteristicPropertyIndicateEncryptionRequired )
        {
            NSLog(@"提示加密需求的屬性 : %x", CBCharacteristicPropertyIndicateEncryptionRequired);
        }
        */
        
    }
}

/*
 * @ Central 寫資料給 Peripheral 後，會觸發這裡
 */
-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if( self.delegate )
    {
        if( [_delegate respondsToSelector:@selector(bleCentralDidWriteValueForPeripheral:withCharacteristic:error:)] )
        {
            [_delegate bleCentralDidWriteValueForPeripheral:peripheral withCharacteristic:characteristic error:error];
        }
    }
    
    if( self.writeCompletion )
    {
        _writeCompletion(peripheral, characteristic, error);
    }
}

/*
 * @ Invoked upon completion of a -[readValueForCharacteristic:] request or on the reception of a notification/indication.
 *   當 - [readValueForCharacteristic：請求完成後調用或接收通知/指示。
 *   Central 在這裡接收 Peripheral 傳遞的資料。
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        //NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }
    
    //還原資料
    //NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    //NSLog(@"Received: %@", stringFromData);
    //[self.combinedData appendData:characteristic.value];
    
    if( self.delegate )
    {
        if( [_delegate respondsToSelector:@selector(bleCentralDidReadValueFromPeripheral:withCharacteristic:error:)] )
        {
            [_delegate bleCentralDidReadValueFromPeripheral:peripheral withCharacteristic:characteristic error:error];
        }
    }
    
    if( self.receiveCompletion )
    {
        _receiveCompletion(peripheral, characteristic, error, self.combinedData);
    }
}

/*
 * @ Invoked upon completion of a -[setNotifyValue:forCharacteristic:] request.
 *   當 -[setNotifyValue:forCharacteristic:] 的請求完成後調用。
 *   Central 已更新 Peripheral 的 Notify 狀態。
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    //非通知屬性，一律不執行
    if( characteristic.properties != CBCharacteristicPropertyNotify )
    {
        return;
    }
    
    if( self.delegate )
    {
        if( [_delegate respondsToSelector:@selector(bleCentralManager:didUpdateNotificationForPeripheral:withCharacteristic:error:)] )
        {
            [_delegate bleCentralManager:self.centralManager didUpdateNotificationForPeripheral:peripheral withCharacteristic:characteristic error:error];
        }
    }
    
    if( self.notifyChangedCompletion )
    {
        _notifyChangedCompletion(self.centralManager, peripheral, characteristic, error);
    }
    
    /*
    if( self.delegate || self.notifyChangedCompletion )
    {

    }
    else
    {
        if (error)
        {
            NSLog(@"Error changing notification state: %@", error.localizedDescription);
        }
        // Exit if it's not the transfer characteristic
        if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:NOTIFY_CHARACTERISTIC_UUID]])
        {
            return;
        }
        // Notification has started
        if (characteristic.isNotifying)
        {
            NSLog(@"Notification began on %@", characteristic);
            //[peripheral readValueForCharacteristic:characteristic];
        }
        else
        {
            // Notification has stopped
            // so disconnect from the peripheral
            NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
            [self.centralManager cancelPeripheralConnection:peripheral];
        }
    }
     */
    
}

@end