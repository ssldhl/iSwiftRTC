//
//  WebRTCViewController.swift
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

import UIKit

// The view controller that is displayed when WebRTC iOS Swift is loaded.
class WebRTCViewController: UIViewController, ARDAppClientDelegate, RTCEAGLVideoViewDelegate {
    @IBOutlet weak var remoteView: RTCEAGLVideoView!
    @IBOutlet weak var localView: RTCEAGLVideoView!
    
    var roomName: String!
    var client: ARDAppClient?
    var localVideoTrack: RTCVideoTrack?
    var remoteVideoTrack: RTCVideoTrack?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        initialize()
        connectToChatRoom()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disconnect()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func endButton(_ sender: UIButton) {
        disconnect()
        _ = self.navigationController?.popToRootViewController(animated: true)
    }
    
//    MARK: RTCEAGLVideoViewDelegate
    func appClient(_ client: ARDAppClient!, didChange state: ARDAppClientState) {
        switch state{
        case ARDAppClientState.connected:
            print("Client Connected")
            break
        case ARDAppClientState.connecting:
            print("Client Connecting")
            break
        case ARDAppClientState.disconnected:
            print("Client Disconnected")
            remoteDisconnected()
        }
    }
    
    func appClient(_ client: ARDAppClient!, didReceiveLocalVideoTrack localVideoTrack: RTCVideoTrack!) {
        self.localVideoTrack = localVideoTrack
        self.localVideoTrack?.add(localView)
    }
    
    func appClient(_ client: ARDAppClient!, didReceiveRemoteVideoTrack remoteVideoTrack: RTCVideoTrack!) {
        self.remoteVideoTrack = remoteVideoTrack
        self.remoteVideoTrack?.add(remoteView)
    }
    
    func appClient(_ client: ARDAppClient!, didError error: Error!) {
//        Handle the error
        showAlertWithMessage(error.localizedDescription)
        disconnect()
    }
    
//    MARK: RTCEAGLVideoViewDelegate
    
    func videoView(_ videoView: RTCEAGLVideoView!, didChangeVideoSize size: CGSize) {
//        Resize localView or remoteView based on the size returned
    }
    
//    MARK: Private
    
    func initialize(){
        disconnect()
//        Initializes the ARDAppClient with the delegate assignment
        client = ARDAppClient.init(delegate: self)
        
//        RTCEAGLVideoViewDelegate provides notifications on video frame dimensions
        remoteView.delegate = self
        localView.delegate = self
    }
    
    func connectToChatRoom(){
        client?.serverHostUrl = "https://apprtc.appspot.com"
        client?.connectToRoom(withId: roomName, options: nil)
    }
    
    func remoteDisconnected(){
        if(remoteVideoTrack != nil){
            remoteVideoTrack?.remove(remoteView)
        }
        remoteVideoTrack = nil
    }
    
    func disconnect(){
        if(client != nil){
            if(localVideoTrack != nil){
                localVideoTrack?.remove(localView)
            }
            if(remoteVideoTrack != nil){
                remoteVideoTrack?.remove(remoteView)
            }
            localVideoTrack = nil
            remoteVideoTrack = nil
            client?.disconnect()
        }
    }
    
    func showAlertWithMessage(_ message: String){
        let alertView: UIAlertController = UIAlertController(title: nil, message: message, preferredStyle: UIAlertControllerStyle.alert)
        let alertAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil)
        alertView.addAction(alertAction)
        self.present(alertView, animated: true, completion: nil)
    }
}

