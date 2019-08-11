//
//  BLEConnnectionDefault.swift
//  itagone
//
//  Created by  Sergey Dolin on 10/08/2019.
//  Copyright © 2019  Sergey Dolin. All rights reserved.
//

import CoreBluetooth
import Foundation
import Rasat

let IMMEDIATE_ALERT_SERVICE = CBUUID(string: "00001802-0000-1000-8000-00805f9b34fb")
let ALERT_LEVEL_CHARACTERISTIC = CBUUID(string: "00002a06-0000-1000-8000-00805f9b34fb")

class PeripheralDelegate: NSObject, CBPeripheralDelegate {
    
}

class BLEConnectionDefault: BLEConnectionInterface {
    let id: String
    let manager: CBCentralManager
    let managerObserver: BLEManagerObserverInterface
    let peripheralObserver: BLEPeripheralObserverInterface
    
    var peripheral: CBPeripheral?
    
    var characteristicImmediateAlert: CBCharacteristic?
    var serviceImmediateAlert: CBService?
    
    init(manager: CBCentralManager, peripheralObserverFactory: BLEPeripheralObserverFactoryInterface, id: String) {
        self.id = id
        self.manager = manager
        self.peripheralObserver = peripheralObserverFactory.observer()
        // NOTE: manager.delegate must be BLEManagerObserverInterface
        self.managerObserver = manager.delegate as! BLEManagerObserverInterface
    }
    
    var isConnected: Bool {
        get{
            return peripheral != nil && peripheral?.state == .connected
        }
    }
    
    private func waitForConnect(timeout: DispatchTime) -> BLEError? {
        guard let peripheral = peripheral else {return .noPeripheral}
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let disposable = DisposeBag()
        var errorConnect: Error? = nil
        
        disposable.add(managerObserver.didConnectPeripheral.subscribe(handler: { connected in
            if connected.identifier == peripheral.identifier {
                print("connect ok")
                semaphore.signal()
            }
        }))
        
        disposable.add(managerObserver.didFailToConnectPeripheral.subscribe(handler: { tuple in
            if tuple.peripheral.identifier == peripheral.identifier {
                print("connect error", tuple)
                errorConnect = tuple.error
                semaphore.signal()
                self.manager.cancelPeripheralConnection(tuple.peripheral)
            }
        }))
        defer {
            print("connect dispose")
            disposable.dispose()
        }
        print("connect start")
        manager.connect(peripheral, options: [:])
        if semaphore.wait(timeout: timeout) == .timedOut {
            print("connect timeout")
            self.manager.cancelPeripheralConnection(peripheral)
            return .timeout
        }
        
        print("connect exit", errorConnect)
        if errorConnect != nil { return .other(errorConnect!)}
        return nil
    }
    
    private func waitForDiscover(timeout: DispatchTime) -> BLEError? {
        let semaphore = DispatchSemaphore(value: 0)
        let disposable = DisposeBag()
        
        disposable.add(managerObserver.didDiscoverPeripheral.subscribe(handler: {tuple in
            if tuple.peripheral.identifier.uuidString == self.id {
                print("discover ok")
                self.peripheral = tuple.peripheral
                semaphore.signal()
            }
        }))
        defer {
            print("discover dispose")
            disposable.dispose()
        }
        print("discover start")
        manager.scanForPeripherals(withServices: [IMMEDIATE_ALERT_SERVICE])
        if semaphore.wait(timeout: timeout) == .timedOut {
            print("discover timeout")
            return .timeout
        }
        print("discover exit")
        return nil
    }
    
    private func waitForDiscoverServices(timeout: DispatchTime) -> BLEError?  {
        guard let peripheral = peripheral else { return .noPeripheral}
        
        let semaphore = DispatchSemaphore(value: 0)
        let disposable = DisposeBag()
        
        let observer = peripheral.delegate as! BLEPeripheralObserverInterface
        disposable.add(observer.didDiscoverServices.subscribe(handler: {discovered in
            if discovered.identifier == peripheral.identifier {
                semaphore.signal()
            }
        }))
        defer {
            disposable.dispose()
        }
        
        peripheral.discoverServices([IMMEDIATE_ALERT_SERVICE])
        if semaphore.wait(timeout: timeout) == .timedOut {
            return .timeout
        }
        return nil
    }
    
    
    private func waitForDiscoverCharacteristics(forService: CBService, timeout: DispatchTime) -> BLEError?  {
        guard let peripheral = peripheral else { return .noPeripheral}
        
        let semaphore = DispatchSemaphore(value: 0)
        let disposable = DisposeBag()
        
        var discoverError: Error? = nil
        
        let observer = peripheral.delegate as! BLEPeripheralObserverInterface
        disposable.add(observer.didDiscoverCharacteristicsForService.subscribe(handler: {tuple in
            if tuple.peripheral.identifier == peripheral.identifier && tuple.service.uuid == forService.uuid {
                discoverError = tuple.error
                semaphore.signal()
            }
        }))
        defer {
            disposable.dispose()
        }
        
        peripheral.discoverCharacteristics([], for: forService)
        if semaphore.wait(timeout: timeout) == .timedOut {
            return .timeout
        }
        return nil
    }
    
    func makeAvailabe(timeout: Int) -> BLEError? {
        print("peripheral make available")

        if peripheral == nil {
            guard let uuid = UUID(uuidString: id) else { return .badUUID }
            let known = manager.retrievePeripherals(withIdentifiers: [uuid])
            if known.count > 0 {
                peripheral = known[0]
                print("peripheral known", peripheral)
                if waitForConnect(timeout: timeout.dispatchTime) != nil {
                    peripheral = nil
                }
            } else {
                peripheral = manager.retrieveConnectedPeripherals(withServices: []).first(where: {connected in connected.identifier == uuid})
                print("peripheral connected", peripheral)
                if peripheral != nil {
                    if waitForConnect(timeout: timeout.dispatchTime) != nil {
                        peripheral = nil
                    }
                }
            }
        }

        let maxTimeout = timeout.dispatchTime
        if peripheral == nil {
            characteristicImmediateAlert = nil
            serviceImmediateAlert = nil
            let scanError = waitForDiscover(timeout: maxTimeout)
            print("peripheral discover", scanError)
            if scanError != nil { return .other(scanError!)}
            let connectError = waitForConnect(timeout: maxTimeout)
            if connectError != nil { return .other(connectError!)}

        }
        
        guard let peripheral = peripheral else {return .noPeripheral}
        if peripheral.delegate == nil {
            peripheral.delegate = peripheralObserver
        }

        if characteristicImmediateAlert == nil {
            if serviceImmediateAlert == nil {
                let discoverServiceError = waitForDiscoverServices(timeout: maxTimeout)
                print("peripheral discover services", peripheral.services, discoverServiceError)
                if discoverServiceError != nil { return .other(discoverServiceError!)}

                for service in peripheral.services ?? [] {
                    if service.uuid == IMMEDIATE_ALERT_SERVICE {
                        serviceImmediateAlert = service
                    }
                }
            }
            guard let serviceImmediateAlert = serviceImmediateAlert else { return .noImmediateAletService }

            let discoverCharacteristicsError = waitForDiscoverCharacteristics(forService: serviceImmediateAlert, timeout: maxTimeout)
            print("peripheral discover characteristics", serviceImmediateAlert.characteristics, discoverCharacteristicsError)
            if discoverCharacteristicsError != nil { return .other(discoverCharacteristicsError!)}
            for characteristic in serviceImmediateAlert.characteristics ?? [] {
                if characteristic.uuid == ALERT_LEVEL_CHARACTERISTIC {
                    characteristicImmediateAlert = characteristic
                }
            }
        }
        
        if characteristicImmediateAlert == nil { return .noImmediateAletCharacteristic }

        print("peripheral ok")
        return nil
    }
    
    func disconnect(timeout: Int) -> BLEError? {
        guard let peripheral = peripheral else { return .noPeripheral}
        let semaphore = DispatchSemaphore(value: 0)
        let disposable = DisposeBag()
        
        var disconnectError: Error? = nil
        
        let observer = manager.delegate as! BLEManagerObserverInterface
        disposable.add(observer.didDisconnectPeripheral.subscribe(handler: {tuple in
            if tuple.peripheral.identifier == peripheral.identifier {
                disconnectError = tuple.error
                semaphore.signal()
            }
        }))
        defer {
            disposable.dispose()
        }
        
        manager.cancelPeripheralConnection(peripheral)

        if semaphore.wait(timeout: timeout.dispatchTime) == .timedOut {
            return .timeout
        }
        
        if disconnectError != nil {
            return .other(disconnectError!)
        }
        
        return nil
    }
    
    private func write(data: Data, characteristic: CBCharacteristic, timeout: DispatchTime?) -> BLEError? {
        guard let peripheral = peripheral else { return .noPeripheral}
        
        if timeout == nil {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        } else {
            let semaphore = DispatchSemaphore(value: 0)
            let disposable = DisposeBag()
            
            var writeError: Error? = nil
            
            let observer = peripheral.delegate as! BLEPeripheralObserverInterface
            disposable.add(observer.didWriteValueForCharacteristic.subscribe(handler: {tuple in
                if tuple.peripheral.identifier == peripheral.identifier && tuple.characteristic.uuid == characteristic.uuid {
                    writeError = tuple.error
                    semaphore.signal()
                }
            }))
            defer {
                disposable.dispose()
            }
            
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            
            if semaphore.wait(timeout: timeout!) == .timedOut {
                return .timeout
            }
            
            if writeError != nil {
                return .other(writeError!)
            }
        }
        return nil
    }
    
    func writeImmediateAlert(volume: AlertVolume, timeout: Int)  -> BLEError? {
        if characteristicImmediateAlert == nil { return .noImmediateAletCharacteristic}
        return write(data: volume.data, characteristic: characteristicImmediateAlert!, timeout: timeout == 0 ? nil : timeout.dispatchTime)
    }
    
    func writeImmediateAlert(volume: AlertVolume) -> BLEError? {
        return writeImmediateAlert(volume: volume, timeout: 0)
    }
}
