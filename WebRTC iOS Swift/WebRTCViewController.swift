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
import AVFoundation

// The view controller that is displayed when WebRTC iOS Swift is loaded.
class WebRTCViewController: UIViewController, UITextFieldDelegate, WebRTCConnectionManagerDelegate, WebRTCLogger, RTCEAGLVideoViewDelegate {
    @IBOutlet weak var roomInput: UITextField!
    @IBOutlet weak var instructionsView: UITextView!
    @IBOutlet weak var blackView: UIView!
    @IBOutlet weak var logView: UITextView!
    
    var statusBarOrientation: UIInterfaceOrientation?
    var localVideoView: RTCEAGLVideoView?
    var remoteVideoView: RTCEAGLVideoView?
    var connectionManager: WebRTCConnectionManager?
    var localVideoSize: CGSize = CGSizeZero
    var remoteVideoSize: CGSize = CGSizeZero
    
    static let kLocalViewPadding: CGFloat = 20

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        connectionManager = WebRTCConnectionManager().initWithDelegate(self, logger: self)
        statusBarOrientation = UIApplication.sharedApplication().statusBarOrientation
        roomInput.becomeFirstResponder()
        let notificationCenter: NSNotificationCenter = NSNotificationCenter.defaultCenter()
        let notificationSelector: Selector = Selector("appMovedToBackground")
        notificationCenter.addObserver(self, selector: notificationSelector, name: UIApplicationWillResignActiveNotification, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        if(statusBarOrientation != UIApplication.sharedApplication().statusBarOrientation){
            statusBarOrientation = UIApplication.sharedApplication().statusBarOrientation
            NSNotificationCenter.defaultCenter().postNotificationName("StatusBarOrientationDidChange", object: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func appMovedToBackground(){
        logMessage("Application lost focus, connection broken.")
        self.disconnect()
    }
    
//    MARK: WebRTCConnectionManagerDelegate
    func didReceiveLocalVideoTrack(manager: WebRTCConnectionManager, localVideoTrack: RTCVideoTrack) {
        localVideoView?.hidden = false
        localVideoTrack.addRenderer(localVideoView)
    }
    
    func didReceiveRemoteVideoTrack(manager: WebRTCConnectionManager, remoteVideoTrack: RTCVideoTrack) {
        remoteVideoTrack.addRenderer(remoteVideoView)
    }
    
    func connectionManagerDidReceiveHangup(manager: WebRTCConnectionManager) {
        showAlertWithMessage("Remote hung up.")
        disconnect()
    }
    
    func didErrorWithMessage(manager: WebRTCConnectionManager, errorMessage: String) {
        showAlertWithMessage(errorMessage)
        disconnect()
    }
    
//    MARK: WebRTCLogger
    func logMessage(message: String) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            let output: String = String(format: "%\n%", self.logView.text, message)
            self.logView.text = output
            self.logView.scrollRangeToVisible(NSMakeRange(self.logView.text.characters.count, 0))
        }
    }
    
//    MARK: RTCEAGLVideoDelegate
    
    func videoView(videoView: RTCEAGLVideoView!, didChangeVideoSize size: CGSize) {
        if(videoView == localVideoView){
            localVideoSize = size
        }else if(videoView == remoteVideoView){
            remoteVideoSize = size
        }else{
            print("ERROR: video view error")
        }
        updateVideoViewLayout()
    }
    
//    MARK: UITextFieldDelegate
    
    func textFieldDidEndEditing(textField: UITextField) {
        let room: String = textField.text!
        if(room.characters.count > 0){
            textField.hidden = true
            instructionsView.hidden = true
            logView.hidden = false
            let url: String = "https://apprtc.appspot.com/?r=\(room)"
            connectionManager?.connectToRoomWithURL(NSURL(string: url)!)
            setupCaptureSession()
        }
    }
    
//    There is no other control that can take focus, so manually resign focus
//    when return (Join) is pressed to trigger |textFieldDidEndEditing|.
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
//    MARK: Private
    
    func disconnect(){
        resetUI()
        connectionManager?.disconnect()
    }
    
    func showAlertWithMessage(message: String){
        let alertView: UIAlertController = UIAlertController(title: nil, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        let alertAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil)
        alertView.addAction(alertAction)
        self.presentViewController(alertView, animated: true, completion: nil)
    }
    
    func resetUI(){
        roomInput.resignFirstResponder()
        roomInput.text = nil
        roomInput.hidden = false
        instructionsView.hidden = false
        logView.hidden = false
        logView.text = nil
        blackView.hidden = true
        remoteVideoView?.removeFromSuperview()
        remoteVideoView = nil
        localVideoView?.removeFromSuperview()
        localVideoView = nil
    }
    
    func setupCaptureSession(){
        blackView.hidden = false
        remoteVideoView = RTCEAGLVideoView.init(frame: blackView.bounds)
        remoteVideoView?.delegate = self
        remoteVideoView?.transform = CGAffineTransformMakeScale(-1, 1)
        blackView.addSubview(remoteVideoView!)
        
        localVideoView = RTCEAGLVideoView.init(frame: blackView.bounds)
        localVideoView?.delegate = self
        blackView.addSubview(localVideoView!)
        updateVideoViewLayout()
    }
    
    func updateVideoViewLayout(){
        let defaultAspectRatio: CGSize = CGSizeMake(4, 3)
        let localAspectRatio: CGSize = CGSizeEqualToSize(localVideoSize, CGSizeZero) ? defaultAspectRatio : localVideoSize
        let remoteAspectRatio: CGSize = CGSizeEqualToSize(remoteVideoSize, CGSizeZero) ? defaultAspectRatio : remoteVideoSize
        let remoteVideoFrame: CGRect = AVMakeRectWithAspectRatioInsideRect(remoteAspectRatio, blackView.bounds)
        remoteVideoView?.frame = remoteVideoFrame
        var localVideoFrame: CGRect = AVMakeRectWithAspectRatioInsideRect(localAspectRatio, blackView.bounds)
        localVideoFrame.size.width = localVideoFrame.size.width / 3
        localVideoFrame.size.height = localVideoFrame.size.height / 3
        localVideoFrame.origin.x = CGRectGetMaxX(blackView.bounds) - localVideoFrame.size.width - WebRTCViewController.kLocalViewPadding
        localVideoFrame.origin.y = CGRectGetMaxY(blackView.bounds) - localVideoFrame.size.height - WebRTCViewController.kLocalViewPadding
    }
}

