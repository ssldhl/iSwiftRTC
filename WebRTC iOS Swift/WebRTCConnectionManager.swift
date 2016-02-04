//
//  WebRTCConnectionManager.swift
//  WebRTC iOS Swift
//
//  Created by Sushil Dahal on 2/2/16.
//  Copyright © 2016 Sushil Dahal.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

// Used to log messages to destination like UI.
protocol WebRTCLogger{
    func logMessage(message: String)
}

// Used to provide AppRTC connection information.
protocol WebRTCConnectionManagerDelegate{
    func didReceiveLocalVideoTrack()
    func didReceiveRemoteVideoTrack()
    func connectionManagerDidReceiveHangup()
    func didErrorWithMessage()
}

// Abstracts the network connection aspect of AppRTC. The delegate will receive
// information about connection status as changes occur.
class WebRTCConnectionManager: NSObject, WebRTCClientDelegate, WebRTCMessageHandler, RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate, RTCStatsDelegate {
    var delegate: WebRTCConnectionManagerDelegate?
    var logger: WebRTCLogger?
    
    var client: WebRTCClient?
    var peerConnection: RTCPeerConnection?
    var peerConnectionFactory: RTCPeerConnectionFactory?
    var videoSource: RTCVideoSource?
    var queuedRemoteCandidates: [String]?
    var statsTimer: NSTimer = NSTimer()
    
    func initWithDelegate(delegate: WebRTCConnectionManagerDelegate, logger: WebRTCLogger)->WebRTCConnectionManager{
        self.delegate = delegate
        self.logger = logger
        self.peerConnectionFactory = RTCPeerConnectionFactory()
        return self
    }
    
//    TODO: func dealloc()
    
    func connectToRoomWithURL(URL: NSURL)->Bool{
        var connectToRoom: Bool = false
        if(client == nil){
            client = WebRTCClient().initWithDelegate(self, messageHandler: self)
            client?.connectToRoom(URL)
            connectToRoom = true
        }
        return connectToRoom
    }
    
    func disconnect(){
        if(client != nil){
            let dataString: String = "{\"type\": \"bye\"}"
            let data: NSData = dataString.dataUsingEncoding(NSUTF8StringEncoding)!
            client?.sendData(data)
            peerConnection?.close()
            peerConnection = nil
            client = nil
            videoSource = nil
            queuedRemoteCandidates = nil
        }
    }
    
//    MARK: WebRTCClientDelegate
    func didErrorWithMessage(appClient: WebRTCClient, message: String) {
        
    }
    
    func didReceiveICEServers(appClient: WebRTCClient, servers: [RTCICEServer]) {
        
    }
    
//    MARK: WebRTCMessageHandler methods
    func onOpen() {
        
    }
    
    func onMessage(data: [NSObject : AnyObject]) {
        
    }
    
    func onClose() {
        
    }
    
    func onError(code: Int32, description: String) {
        
    }
    
//    MARK: RTCPeerConnectionDelegate
    
//    TODO: func peerConnectionOnError()
    
    func peerConnection(peerConnection: RTCPeerConnection!, signalingStateChanged stateChanged: RTCSignalingState) {
        
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, addedStream stream: RTCMediaStream!) {
        
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, removedStream stream: RTCMediaStream!) {
        
    }
    
    func peerConnectionOnRenegotiationNeeded(peerConnection: RTCPeerConnection!) {
        
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, gotICECandidate candidate: RTCICECandidate!) {
        
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, iceGatheringChanged newState: RTCICEGatheringState) {
        
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, iceConnectionChanged newState: RTCICEConnectionState) {
        
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, didOpenDataChannel dataChannel: RTCDataChannel!) {
        
    }
    
//    MARK: RTCSessionDescriptionDelegate
    
    func peerConnection(peerConnection: RTCPeerConnection!, didCreateSessionDescription sdp: RTCSessionDescription!, error: NSError!) {
        
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, didSetSessionDescriptionWithError error: NSError!) {
        
    }
    
//    MARK: RTCStatsDelegate
    
    func peerConnection(peerConnection: RTCPeerConnection!, didGetStats stats: [AnyObject]!) {
        
    }
    
//    Private
    
//    Match |pattern| to |value| and return the first group of the first
//    match, or nil if no match was found.
    func firstMatch(pattern: NSRegularExpression, value: String)-> String?{
        return nil
    }
    
//    Mangle |origSDP| to prefer the ISAC/16k audio codec.
    func preferISAC(origSDP: String)-> String?{
        return nil
    }
    
    func drainRemoteCandidates(){
        
    }
    
    func didFireStatsTimer(timer: NSTimer){
        
    }
}