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
import AVFoundation

// Used to log messages to destination like UI.
protocol WebRTCLogger{
    func logMessage(message: String)
}

// Used to provide AppRTC connection information.
protocol WebRTCConnectionManagerDelegate{
    func didReceiveLocalVideoTrack(manager: WebRTCConnectionManager, localVideoTrack: RTCVideoTrack)
    func didReceiveRemoteVideoTrack(manager: WebRTCConnectionManager, remoteVideoTrack: RTCVideoTrack)
    func connectionManagerDidReceiveHangup(manager: WebRTCConnectionManager)
    func didErrorWithMessage(manager: WebRTCConnectionManager, errorMessage: String)
}

// Abstracts the network connection aspect of AppRTC. The delegate will receive
// information about connection status as changes occur.
class WebRTCConnectionManager: NSObject, WebRTCClientDelegate, WebRTCMessageHandler, RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate, RTCStatsDelegate {
    var delegate: WebRTCConnectionManagerDelegate?
    var logger: WebRTCLogger?
    
    var client: WebRTCClient?
    var peerConnection: RTCPeerConnection?
    var peerConnectionFactory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()
    var videoSource: RTCVideoSource?
    var queuedRemoteCandidates: [RTCICECandidate]?
    var statsTimer: NSTimer = NSTimer()
    
    func initWithDelegate(delegate: WebRTCConnectionManagerDelegate, logger: WebRTCLogger)->WebRTCConnectionManager{
        self.delegate = delegate
        self.logger = logger
        self.peerConnectionFactory = RTCPeerConnectionFactory()
        
//        Uncomment for stat logs.
        let statsTimerSelector: Selector = Selector("didFireStatsTimer:")
        statsTimer = NSTimer(timeInterval: 10, target: self, selector: statsTimerSelector, userInfo: nil, repeats: true)
        
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
        delegate?.didErrorWithMessage(self, errorMessage: message)
    }
    
    func didReceiveICEServers(appClient: WebRTCClient, servers: [RTCICEServer]) {
        queuedRemoteCandidates = [RTCICECandidate]()
        let mandatoryConstraints: [RTCPair] = [RTCPair(key: "OfferToReceiveAudio", value: "true"), RTCPair(key: "OfferToReceiveVideo", value: "true")]
        let optionalConstraints: [RTCPair] = [RTCPair(key: "internalSctpDataChannels", value: "true"), RTCPair(key: "DtlsSrtpKeyAgreement", value: "true")]
        let constraints: RTCMediaConstraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: optionalConstraints)
        peerConnection = peerConnectionFactory.peerConnectionWithICEServers(servers, constraints: constraints, delegate: self)
        let lms: RTCMediaStream = peerConnectionFactory.mediaStreamWithLabel("ARDAMS")
        
//        The iOS simulator doesn't provide any sort of camera capture
//        support or emulation (http://goo.gl/rHAnC1) so don't bother
//        trying to open a local stream.
        let localVideoTrack: RTCVideoTrack?
        var cameraID: String? = nil
        let captureDevices: [AVCaptureDevice] = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        for captureDevice in captureDevices{
            if(captureDevice.position == AVCaptureDevicePosition.Front){
                cameraID = captureDevice.localizedName
                break
            }
        }
        if(cameraID != nil){
            let capturer: RTCVideoCapturer = RTCVideoCapturer(deviceName: cameraID)
            videoSource = peerConnectionFactory.videoSourceWithCapturer(capturer, constraints: client?.videoConstraints)
            localVideoTrack = peerConnectionFactory.videoTrackWithID("ARDAMSv0", source: videoSource)
            if(localVideoTrack != nil){
                lms.addVideoTrack(localVideoTrack)
                delegate?.didReceiveLocalVideoTrack(self, localVideoTrack: localVideoTrack!)
            }
        }
        lms.addAudioTrack(peerConnectionFactory.audioTrackWithID("ARDAMSa0"))
        peerConnection?.addStream(lms)
        logger?.logMessage("onICEServers - added local stream.")
    }
    
//    MARK: WebRTCMessageHandler methods
    func onOpen() {
        if(!client!.initiator){
            logger?.logMessage("Calle; waiting for remote offer")
        }else{
            logger?.logMessage("GAE onOpen - create offer.")
            let audio: RTCPair = RTCPair(key: "OfferToReceiveAudio", value: "true")
            let video: RTCPair = RTCPair(key: "OfferToReceiveVideo", value: "true")
            let mandatory: [RTCPair] = [audio, video]
            let constraints: RTCMediaConstraints = RTCMediaConstraints(mandatoryConstraints: mandatory, optionalConstraints: nil)
            peerConnection?.createOfferWithDelegate(self, constraints: constraints)
            logger?.logMessage("PC - createOffer.")
        }
    }
    
    func onMessage(data: [NSObject : AnyObject]) {
        let type: String? = data["type"] as? String
        if(type != nil){
            logger?.logMessage("GAE onMessage type - \(type!)")
            if(type == "candidate"){
                let mid: String = data["id"] as! String
                let sdpLineIndex: NSNumber = data["label"] as! NSNumber
                let sdp: String = data["candidate"] as! String
                let candidate: RTCICECandidate = RTCICECandidate(mid: mid, index: sdpLineIndex.integerValue, sdp: sdp)
                if(queuedRemoteCandidates != nil){
                    queuedRemoteCandidates?.insert(candidate, atIndex: 0)
                }else{
                    peerConnection?.addICECandidate(candidate)
                }
            }else if(type == "offer" || type == "answer"){
                let sdpString: String = data["sdp"] as! String
                let sdp: RTCSessionDescription = RTCSessionDescription(type: type, sdp: sdpString)
                peerConnection?.setRemoteDescriptionWithDelegate(self, sessionDescription: sdp)
                logger?.logMessage("PC - setRemoteDescription")
            }else if(type == "bye"){
                delegate?.connectionManagerDidReceiveHangup(self)
            }else{
                print("Invalid Message: \(data)")
            }
        }
    }
    
    func onClose() {
        logger?.logMessage("GAE onClose")
        delegate?.connectionManagerDidReceiveHangup(self)
    }
    
    func onError(code: Int32, description: String) {
        let message: String = String(format: "GAE onError: %d, %@", code, description)
        logger?.logMessage(message)
        delegate?.didErrorWithMessage(self, errorMessage: message)
    }
    
//    MARK: RTCPeerConnectionDelegate
    
//    TODO: func peerConnectionOnError(){
//      dispatch_async(dispatch_get_main_queue()) { () -> Void in
//          let message: String = "PeerConnection error"
//          print("\(message)")
//          print("PeerConnection Failed")
//          self.delegate?.didErrorWithMessage(self, errorMessage: message)
//    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, signalingStateChanged stateChanged: RTCSignalingState) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            print("PCO onSignalingStateChange: \(stateChanged)")
        }
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, addedStream stream: RTCMediaStream!) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            print("PCO onAddStream.")
            if(stream.audioTracks.count == 1 || stream.videoTracks.count == 1){
                print("Expected audio or video track")
            }
            if(stream.audioTracks.count <= 1){
                print("Expected at most 1 audio stream")
            }
            if(stream.videoTracks.count <= 1){
                print("Expected at most 1 video stream")
            }
            if(stream.videoTracks.count != 0){
                let remoteVideoTrack: RTCVideoTrack = stream.videoTracks[0] as! RTCVideoTrack
                self.delegate?.didReceiveRemoteVideoTrack(self, remoteVideoTrack: remoteVideoTrack)
            }
        }
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, removedStream stream: RTCMediaStream!) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            print("PCO onRemoveStream.")
        }
    }
    
    func peerConnectionOnRenegotiationNeeded(peerConnection: RTCPeerConnection!) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            print("PCO onRenegotiationNeeded - ignoring because AppRTC has a predefined negotiation strategy")
        }
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, gotICECandidate candidate: RTCICECandidate!) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            print("PCO onICECandidate. \n Mid[\(candidate.sdpMid)] Index[\(candidate.sdpMLineIndex)] Sdp[\(candidate.sdp)]")
            let json: [NSObject: AnyObject] = ["type": "candidate", "label": candidate.sdpMLineIndex, "id": candidate.sdpMid, "candidate": candidate.sdp]
            var data: NSData = NSData()
            do{
                data = try NSJSONSerialization.dataWithJSONObject(json, options: NSJSONWritingOptions.PrettyPrinted)
                self.client?.sendData(data)
            }catch let error as NSError{
                print("Unable to serialize JSON object with error: \(error.localizedDescription)")
            }
        }
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, iceGatheringChanged newState: RTCICEGatheringState) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            print("PCO onIceGatheringChange. \(newState)")
        }
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, iceConnectionChanged newState: RTCICEConnectionState) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            print("PCO onIceConnectionChange. \(newState)")
            if(newState == RTCICEConnectionConnected){
                self.logger?.logMessage("ICE Connection Connected.")
            }else if(newState == RTCICEConnectionFailed){
                print("ICE Connection failed!")
            }
        }
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, didOpenDataChannel dataChannel: RTCDataChannel!) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            print("WebRTC doesn't use DataChannels")
        }
    }
    
//    MARK: RTCSessionDescriptionDelegate
    
    func peerConnection(peerConnection: RTCPeerConnection!, didCreateSessionDescription sdp: RTCSessionDescription!, error: NSError!) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            if(error != nil){
                self.logger?.logMessage("SDP onFailure.")
                print(error.localizedDescription)
            }else{
                self.logger?.logMessage("SDP onSuccess(SDP) - set local description.")
                let Sdp: RTCSessionDescription = RTCSessionDescription(type: sdp.type, sdp: self.preferISAC(sdp.description))
                peerConnection.setLocalDescriptionWithDelegate(self, sessionDescription: Sdp)
                self.logger?.logMessage("PC setLocalDescription")
                let json: [NSObject: AnyObject] = ["type": Sdp.type, "sdp": Sdp.description]
                var data: NSData = NSData()
                do{
                    data = try NSJSONSerialization.dataWithJSONObject(json, options: NSJSONWritingOptions.PrettyPrinted)
                    self.client?.sendData(data)
                }catch let error as NSError{
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!, didSetSessionDescriptionWithError error: NSError!) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            if(error != nil){
                self.logger?.logMessage("SDP onFailure")
                print(error.localizedDescription)
            }else{
                self.logger?.logMessage("SDP onSuccess() - possibly drain candidates")
                if(!self.client!.initiator){
                    if(self.peerConnection?.remoteDescription != nil && self.peerConnection?.localDescription != nil){
                        self.logger?.logMessage("Callee, setRemoteDescription succeeded")
                        let audio: RTCPair = RTCPair(key: "OfferToReceiveAudio", value: "true")
                        let video: RTCPair = RTCPair(key: "OfferToReceiveVideo", value: "true")
                        let mandatory: [RTCPair] = [audio, video]
                        let constraints: RTCMediaConstraints = RTCMediaConstraints(mandatoryConstraints: mandatory, optionalConstraints: nil)
                        self.peerConnection?.createAnswerWithDelegate(self, constraints: constraints)
                        self.logger?.logMessage("PC - createAnswer.")
                    }else{
                        self.logger?.logMessage("SDP onSuccess - drain candidates")
                        self.drainRemoteCandidates()
                    }
                }else{
                    if(self.peerConnection?.remoteDescription != nil){
                        self.logger?.logMessage("SDP onSuccess - drain candidates")
                        self.drainRemoteCandidates()
                    }
                }
            }
        }
    }
    
//    MARK: RTCStatsDelegate
    
    func peerConnection(peerConnection: RTCPeerConnection!, didGetStats stats: [AnyObject]!) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            let message: String = String(format: "Stats: \n %", stats)
            self.logger?.logMessage(message)
        }
    }
    
//    Private
    
//    Match |pattern| to |value| and return the first group of the first
//    match, or nil if no match was found.
    func firstMatch(pattern: NSRegularExpression, value: String)-> String?{
        var returnValue: String? = nil
        let result: NSTextCheckingResult? = pattern.firstMatchInString(value, options: NSMatchingOptions.Anchored, range: NSMakeRange(0, value.characters.count))
        if(result != nil){
            let nsValue: NSString = value as NSString
            returnValue = nsValue.substringWithRange(result!.rangeAtIndex(1))
        }
        return returnValue
    }
    
//    Mangle |origSDP| to prefer the ISAC/16k audio codec.
    func preferISAC(origSDP: String)-> String?{
        var returnValue: String = origSDP
        var mLineIndex: Int = -1
        var isac16kRtpMap: String? = nil
        let lines: [String] = origSDP.componentsSeparatedByString("\n")
        var isac16kRegex: NSRegularExpression?
        do{
            isac16kRegex = try NSRegularExpression(pattern: "^a=rtpmap:(\\d+) ISAC/16000[\r]?$", options: NSRegularExpressionOptions.CaseInsensitive)
        }catch let error as NSError{
            print("ERROR: \(error.localizedDescription)")
        }
        if(isac16kRegex != nil){
            for var i: Int = 0; (i < lines.count) && (mLineIndex == -1 || isac16kRtpMap == nil); ++i{
                let line: String = lines[i]
                if(line.hasPrefix("m=audio")){
                    mLineIndex = i
                    continue
                }
                isac16kRtpMap = self.firstMatch(isac16kRegex!, value: line)
            }
        }
        if(mLineIndex == -1){
            print("No m=audio line, so can't prefer iSAC")
        }else{
            if(isac16kRtpMap == nil){
                print("No ISAC/16000 line, so can't prefer iSAC")
            }else{
                let origMlineParts: [String] = lines[mLineIndex].componentsSeparatedByString(" ")
                var newMLine: [String] = []
                var origPartIndex: Int = 0
                newMLine.append(origMlineParts[origPartIndex++])
                newMLine.append(origMlineParts[origPartIndex++])
                newMLine.append(origMlineParts[origPartIndex++])
                newMLine.append(isac16kRtpMap!)
                for ;origPartIndex < origMlineParts.count; ++origPartIndex{
                    if(isac16kRtpMap != origMlineParts[origPartIndex]){
                        newMLine.append(origMlineParts[origPartIndex])
                    }
                }
                var newLines: [String] = []
                newLines.appendContentsOf(lines)
                newLines[mLineIndex] = newMLine.joinWithSeparator(" ")
                returnValue = newLines.joinWithSeparator("\n")
            }
        }
        
        return returnValue
    }
    
    func drainRemoteCandidates(){
        for queuedRemoteCandidate in queuedRemoteCandidates!{
            peerConnection?.addICECandidate(queuedRemoteCandidate)
        }
        queuedRemoteCandidates = nil
    }
    
    func didFireStatsTimer(timer: NSTimer){
        if(peerConnection != nil){
            peerConnection?.getStatsWithDelegate(self, mediaStreamTrack: nil, statsOutputLevel: RTCStatsOutputLevelDebug)
        }
    }
}