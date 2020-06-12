//
//  TagStoreDefault.swift
//  itagone
//
//  Created by  Sergey Dolin on 08/08/2019.
//  Copyright © 2019  Sergey Dolin. All rights reserved.
//

import BLE
import CoreBluetooth
import Foundation
import Rasat

class TagStoreDefault: TagStoreInterface {
    static let shared = TagStoreDefault(factory: TagFactoryDefault.shared, ble: BLEDefault.shared)
    
    let ble: BLEInterface
    let channel = Channel<StoreOp>()
    let defaults = UserDefaults.standard
    let factory: TagFactoryInterface

    var ids = [String]()
    var idsforever = [String]()
    var tags = [String: TagInterface]()
    
    init(factory: TagFactoryInterface, ble: BLEInterface) {
        self.factory = factory
        self.ble = ble
 
        ids = defaults.array(forKey: "ids") as? [String] ?? []
        idsforever = defaults.array(forKey: "idsforever") as? [String] ?? []
        
        for id in idsforever {
            guard let dict = defaults.dictionary(forKey: "tag \(id)") else {continue}
            if ids.contains(id) {
                tags[id] = factory.tag(id: id, dict: dict)
            }
        }
        /*
 fake tag for testing purposes
        tags.removeAll()
        ids.removeAll()
        ids.append("test")
        tags["test"]=factory.tag(id: "test", name: "Test", color: .black, alert: true)
 */
    }
    
    func by(id: String) -> TagInterface? {
        return tags[id]
    }
    
    func everBy(id: String) -> TagInterface? {
        let active = by(id: id)
        if active != nil {
            return active
        }
        
        guard let dict = defaults.dictionary(forKey: "tag \(id)") else {return nil}
        return factory.tag(id: id, dict: dict)
    }
    
    func tagBy(pos: Int) -> TagInterface? {
        if pos >= ids.count {
            return nil
        }
        return by(id: ids[pos])
    }
    
    var count: Int {
        get {
            return ids.count
        }
    }
 
    var observable: Observable<StoreOp> {
        get{
            return channel.observable
        }
    }
    
    /*
    private func clearDefaults() {
        defaults.removeObject(forKey: "ids")
        for id in ids {
            defaults.removeObject(forKey: "tag \(id)")
        }
    }*/
    
    private func storeToDefaults() {
        defaults.set(ids, forKey: "ids")
        defaults.set(idsforever, forKey: "idsforever")

        for id in ids {
            guard let tag = tags[id] else { continue }
            defaults.set(tag.toDict(), forKey: "tag \(id)")
        }
    }
    
    func remember(tag: TagInterface) {
        if !ids.contains(tag.id) {
            ids.append(tag.id)
        }
        
        if !idsforever.contains(tag.id) {
            idsforever.append(tag.id)
        }
        
        if let existing = everBy(id: tag.id) {
            tag.copy(fromTag:existing)
        }

        tags[tag.id] = tag
        
        storeToDefaults()
        channel.broadcast(.remember(tag))
    }
    
    func forget(id: String) {
        if let i = ids.firstIndex(of: id) {
            ids.remove(at: i)
            storeToDefaults()
            if tags[id] != nil {
                channel.broadcast(.forget(tags[id]!))
            }
        }
    }
    
    func remembered(id: String) -> Bool {
        return ids.contains(id)
    }

    func set(alert: Bool, forTag: TagInterface) {
        // TODO: report if not found
        guard var tag = tags[forTag.id] else { return }
        tag.alert = alert
        storeToDefaults()
        channel.broadcast(.change(tag))
    }
    
    func set(color: TagColor, forTag: TagInterface) {
        // TODO: report if not found
        guard var tag = tags[forTag.id] else { return }
        tag.color = color
        storeToDefaults()
        channel.broadcast(.change(tag))
    }
    
    func set(name: String, forTag: TagInterface) {
        // TODO: report if not found
        guard var tag = tags[forTag.id] else { return }
        tag.name = name
        storeToDefaults()
        // important: broadacst even the same value
        // beacase alert state depends on connect state
        channel.broadcast(.change(tag))
    }

    func connectAll() {
        for (_, tag) in tags {
            if tag.alert {
                ble.connections.connect(id: tag.id) //,timeout: BLE_TIMEOUT)
            }
        }
    }
    
    func stopAlertAll() {
        for (_, tag) in tags {
            if ble.alert.isAlerting(id: tag.id) {
                DispatchQueue.global(qos: .background).async {
                    self.ble.alert.stopAlert(id: tag.id, timeout: BLE_TIMEOUT)
                }
            }
        }
    }
    
    func forgottenIds() -> [String] {
        return idsforever.filter({id in !ids.contains(id)})
    }
}
