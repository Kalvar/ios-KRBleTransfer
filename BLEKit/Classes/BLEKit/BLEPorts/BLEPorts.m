//
//  BLEPorts.m
//  BLEKit
//
//  Created by Kalvar, ilovekalvar@gmail.com on 2013/12/5.
//  Copyright (c) 2013 - 2014年 Kuo-Ming Lin. All rights reserved.
//

#import "BLEPorts.h"

@implementation BLEPorts

+(UInt16)swap:(UInt16)_swap
{
    UInt16 temp = _swap << 8;
    temp |= (_swap >> 8);
    return temp;
}

+(BOOL)compareUUID1:(CBUUID *)_UUID1 UUID2:(CBUUID *)_UUID2
{
    char b1[16];
    char b2[16];
    [_UUID1.data getBytes:b1];
    [_UUID2.data getBytes:b2];
    return (memcmp(b1, b2, _UUID1.data.length) == 0);
}

+(CBCharacteristic *)findCharacteristicFromUUID:(CBUUID *)_UUID service:(CBService*)_service
{
    for( CBCharacteristic *_char in _service.characteristics )
    {
        if ([self compareUUID1:_char.UUID UUID2:_UUID])
        {
            return _char;
        }
    }
    return nil;
}

+(CBService *)findServiceFromUUID:(CBUUID *)_UUID peripheral:(CBPeripheral *)_peripheral
{
    for( CBService *_service in _peripheral.services )
    {
        if ([self compareUUID1:_service.UUID UUID2:_UUID])
        {
            return _service;
        }
    }
    return nil;
}
@end
