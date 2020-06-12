//
//  BLEConnectionsInterface.swift
//  BLE
//
//  Created by  Sergey Dolin on 11/08/2019.
//  Copyright © 2019  Sergey Dolin. All rights reserved.
//

import Foundation
import Rasat

public enum BLEConnectionState {
    case disconnected
    case connecting
    case disconnecting
    case discovering
    case discoveringServices
    case discoveringCharacteristics
    case connected
    case writting
    case reading
}

public protocol BLEConnectionStateArray {
    subscript(id: String) -> BLEConnectionState { get }
}

public protocol BLEConnectionsInterface {
    var stateObservable: Observable<(id: String, fromState: BLEConnectionState, toState: BLEConnectionState)> { get }
    var state: BLEConnectionStateArray { get }
    func connect(id: String)
    func startListen(id: String, timeout: Int)
    func disconnect(id: String)
}


protocol BLEConnectionsControlInterface {
    func setState(id: String, state: BLEConnectionState)
}
