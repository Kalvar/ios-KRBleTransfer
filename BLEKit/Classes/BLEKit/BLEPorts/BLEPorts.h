//
//  BLEPorts.h
//  BLEKit
//
//  Created by Kalvar, ilovekalvar@gmail.com on 2013/12/5.
//  Copyright (c) 2013 - 2014年 Kuo-Ming Lin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#ifndef LE_NOTIFY_TransferService_h
#define LE_NOTIFY_TransferService_h


#define BLE_CUSTOM_SERVICE_UUID               @"E20A39F4-73F5-4BC4-A12F-17D1AD07A961"

//傳檔案給 Central 用的 Notify
#define NOTIFY_CHARACTERISTIC_UUID            @"08590F7E-DB05-467E-8757-72F6FAEB13D4"

//傳檔案給 Peripheral 後，Peripheral 回應 Central 的 Notify ( 要求 Central 繼續傳封包 )
#define NOTIFY_PERIPHERAL_CHARACTERISTIC_UUID @"7293FDAC-CF86-4E18-9C8A-719B8BF53439"

#define WRITE_CHARACTERISTIC_UUID             @"2EDD8344-3466-4866-94A6-E02EA32E8FCA"


#endif

@interface BLEPorts : NSObject

+(UInt16)swap:(UInt16)_swap;
+(BOOL)compareUUID1:(CBUUID *)_UUID1 UUID2:(CBUUID *)_UUID2;
+(CBCharacteristic *)findCharacteristicFromUUID:(CBUUID *)_UUID service:(CBService*)_service;
+(CBService *)findServiceFromUUID:(CBUUID *)_UUID peripheral:(CBPeripheral *)_peripheral;

@end
