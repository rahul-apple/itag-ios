//
//  TagStoreDefault.swift
//  itagone
//
//  Created by  Sergey Dolin on 08/08/2019.
//  Copyright © 2019  Sergey Dolin. All rights reserved.
//

import CoreBluetooth
import Foundation
import Rasat

class TagStoreDefault: TagStoreInterface {
    static let shared = TagStoreDefault(factory: TagFactoryDefault.shared)
    
    let channel = Channel<StoreOp>()
    let factory: TagFactoryInterface
    let defaults = UserDefaults.standard
    var tags = [String: TagInterface]()
    var ids = [String]()
    
    init(factory: TagFactoryInterface) {
        self.factory = factory
 
        ids = defaults.array(forKey: "ids") as? [String] ?? []
        print("tag ids <- store:", ids)
        
        for id in ids {
            guard let dict = defaults.dictionary(forKey: "tag \(id)") else {continue}
            tags[id] = factory.tag(id: id, dict: dict)
            print("tag <- store:", tags[id]?.toString() ?? "", dict)
        }
    }
    
    func by(id: String) -> TagInterface? {
        return tags[id]
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
        print("tag ids -> store:", ids)

        for id in ids {
            guard let tag = tags[id] else { continue }
            defaults.set(tag.toDict(), forKey: "tag \(id)")
            print("tag -> store:", tags[id]?.toString() ?? "",tag.toDict())
        }
    }
    
    func remember(tag: TagInterface) {
        if !ids.contains(tag.id) {
            ids.append(tag.id)
            tags[tag.id] = tag
            storeToDefaults()
            channel.broadcast(StoreOp.remember)
        }
    }
    
    func forget(id: String) {
        if let i = ids.firstIndex(of: id) {
            ids.remove(at: i)
            storeToDefaults()
            channel.broadcast(StoreOp.forget)
        }
    }
    
    func remembered(id: String) -> Bool {
        return ids.contains(id)
    }

    func set(alert: Bool, forTag: TagInterface) {
        // TODO: report if not found
        guard var tag0 = tags[forTag.id] else { return }
        tag0.alert = alert
        storeToDefaults()
        channel.broadcast(StoreOp.change)
    }
    
    func set(color: TagColor, forTag: TagInterface) {
        // TODO: report if not found
        guard var tag0 = tags[forTag.id] else { return }
        tag0.color = color
        storeToDefaults()
        channel.broadcast(StoreOp.change)
    }
    
    func set(name: String, forTag: TagInterface) {
        // TODO: report if not found
        guard var tag0 = tags[forTag.id] else { return }
        tag0.name = name
        storeToDefaults()
        channel.broadcast(StoreOp.change)
    }

}
