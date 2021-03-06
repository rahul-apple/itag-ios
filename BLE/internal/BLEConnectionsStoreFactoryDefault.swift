//
//  BLEConnectionsStoreFactoryDefault.swift
//  BLE
//
//  Created by  Sergey Dolin on 11/08/2019.
//  Copyright © 2019  Sergey Dolin. All rights reserved.
//

import CoreBluetooth
import Foundation

class BLEConnectionsStoreFactoryDefault: BLEConnectionsStoreFactoryInterface {
    func store(connectionFactory: BLEConnectionFactoryInterface, findMeControl: BLEFindMeControlInterface, manager: CBCentralManager, peripheralObservablesFactory: BLEPeripheralObservablesFactoryInterface) -> BLEConnectionsStoreInterface {
        return BLEConnectionsStoreDefault(connectionFactory: connectionFactory, findMeControl: findMeControl, manager: manager, peripheralObservablesFactory: peripheralObservablesFactory)
    }
}
