//
//  PeerKit.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/5/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import Foundation
import MultipeerConnectivity

// MARK: Type Aliases

@available(OSXApplicationExtension 10.10, *)
public typealias PeerBlock = ((myPeerID: MCPeerID, peerID: MCPeerID) -> Void)
@available(OSXApplicationExtension 10.10, *)
public typealias EventBlock = ((peerID: MCPeerID, event: String, object: AnyObject?) -> Void)
@available(OSXApplicationExtension 10.10, *)
public typealias ObjectBlock = ((peerID: MCPeerID, object: AnyObject?) -> Void)
@available(OSXApplicationExtension 10.10, *)
public typealias ResourceBlock = ((myPeerID: MCPeerID, resourceName: String, peer: MCPeerID, localURL: NSURL) -> Void)

// MARK: Event Blocks

@available(OSXApplicationExtension 10.10, *)
public var onConnecting: PeerBlock?
@available(OSXApplicationExtension 10.10, *)
public var onConnect: PeerBlock?
@available(OSXApplicationExtension 10.10, *)
public var onDisconnect: PeerBlock?
@available(OSXApplicationExtension 10.10, *)
public var onEvent: EventBlock?
@available(OSXApplicationExtension 10.10, *)
public var onEventObject: ObjectBlock?
@available(OSXApplicationExtension 10.10, *)
public var onFinishReceivingResource: ResourceBlock?
@available(OSXApplicationExtension 10.10, *)
public var eventBlocks = [String: ObjectBlock]()

// MARK: PeerKit Globals

#if os(iOS)
import UIKit
public let myName = UIDevice.currentDevice().name
#else
public let myName = NSHost.currentHost().localizedName ?? ""
#endif

@available(OSXApplicationExtension 10.10, *)
public var transceiver = Transceiver(displayName: myName)
@available(OSXApplicationExtension 10.10, *)
public var session: MCSession?

// MARK: Event Handling

@available(OSXApplicationExtension 10.10, *)
func didConnecting(myPeerID: MCPeerID, peer: MCPeerID) {
    if let onConnecting = onConnecting {
        dispatch_async(dispatch_get_main_queue()) {
            onConnecting(myPeerID: myPeerID, peerID: peer)
        }
    }
}

@available(OSXApplicationExtension 10.10, *)
func didConnect(myPeerID: MCPeerID, peer: MCPeerID) {
    if session == nil {
        session = transceiver.session.mcSession
    }
    if let onConnect = onConnect {
        dispatch_async(dispatch_get_main_queue()) {
            onConnect(myPeerID: myPeerID, peerID: peer)
        }
    }
}

@available(OSXApplicationExtension 10.10, *)
func didDisconnect(myPeerID: MCPeerID, peer: MCPeerID) {
    if let onDisconnect = onDisconnect {
        dispatch_async(dispatch_get_main_queue()) {
            onDisconnect(myPeerID: myPeerID, peerID: peer)
        }
    }
}

@available(OSXApplicationExtension 10.10, *)
func didReceiveData(data: NSData, fromPeer peer: MCPeerID) {
    if let dict = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? [String: AnyObject],
        let event = dict["event"] as? String,
        let object: AnyObject? = dict["object"] {
            dispatch_async(dispatch_get_main_queue()) {
                if let onEvent = onEvent {
                    onEvent(peerID: peer, event: event, object: object)
                }
                if let eventBlock = eventBlocks[event] {
                    eventBlock(peerID: peer, object: object)
                }
            }
    }
}

@available(OSXApplicationExtension 10.10, *)
func didFinishReceivingResource(myPeerID: MCPeerID, resourceName: String, fromPeer peer: MCPeerID, atURL localURL: NSURL) {
    if let onFinishReceivingResource = onFinishReceivingResource {
        dispatch_async(dispatch_get_main_queue()) {
            onFinishReceivingResource(myPeerID: myPeerID, resourceName: resourceName, peer: peer, localURL: localURL)
        }
    }
}

// MARK: Advertise/Browse

@available(OSXApplicationExtension 10.10, *)
public func transceive(serviceType: String, discoveryInfo: [String: String]? = nil) {
    transceiver.startTransceiving(serviceType: serviceType, discoveryInfo: discoveryInfo)
}

@available(OSXApplicationExtension 10.10, *)
public func advertise(serviceType: String, discoveryInfo: [String: String]? = nil) {
    transceiver.startAdvertising(serviceType: serviceType, discoveryInfo: discoveryInfo)
}

@available(OSXApplicationExtension 10.10, *)
public func browse(serviceType: String) {
    transceiver.startBrowsing(serviceType: serviceType)
}

@available(OSXApplicationExtension 10.10, *)
public func stopTransceiving() {
    transceiver.stopTransceiving()
    session = nil
}

// MARK: Events

@available(OSXApplicationExtension 10.10, *)
public func sendEvent(event: String, object: AnyObject? = nil, toPeers peers: [MCPeerID]? = session?.connectedPeers as [MCPeerID]?) {
    if peers == nil || (peers!.count == 0) {
        return
    }
    var rootObject: [String: AnyObject] = ["event": event]
    if let object: AnyObject = object {
        rootObject["object"] = object
    }
    let data = NSKeyedArchiver.archivedDataWithRootObject(rootObject)

    if let peers = peers {
        do {
            try session?.sendData(data, toPeers: peers, withMode: .Reliable)
        } catch _ {
        }
    }
}

@available(OSXApplicationExtension 10.10, *)
public func sendResourceAtURL(resourceURL: NSURL!,
                   withName resourceName: String!,
  toPeers peers: [MCPeerID]? = session?.connectedPeers as [MCPeerID]?,
  withCompletionHandler completionHandler: ((NSError!) -> Void)!) -> [NSProgress?]! {

    if let session = session, peers = peers {
        return peers.map { peerID in
            return session.sendResourceAtURL(resourceURL, withName: resourceName, toPeer: peerID, withCompletionHandler: completionHandler)
        }
    }
    return nil
}
