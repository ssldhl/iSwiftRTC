//
//  WebRTCClient.swift
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

protocol WebRTCClientDelegate{
    func appClient(appClient: WebRTCClient, message: String)
    func appClient(appClient: WebRTCClient, servers: [RTCICEServer])
}

// Negotiates signaling for chatting with apprtc.appspot.com "rooms".
// Uses the client<->server specifics of the apprtc AppEngine webapp.
//
// To use: create an instance of this object (registering a message handler) and
// call connectToRoom().  apprtc.appspot.com will signal that is successful via
// onOpen through the browser channel.  Then you should call sendData() and wait
// for the registered handler to be called with received messages.
class WebRTCClient: NSObject{
    var initiator: Bool!
    var videoConstraints: RTCMediaConstraints?
    var delegate: WebRTCClientDelegate?
    var webRTCChannel: WebRTCChannelClient!
    var postMessageURL: NSURL?
    var verboseLogging: Bool = false
    var messageHandler: WebRTCMessageHandler!
    
    func initWithDelegate(delegate: WebRTCClientDelegate, messageHandler: WebRTCMessageHandler)->WebRTCClient{
        self.delegate = delegate
        self.messageHandler = messageHandler
        // Uncomment to see Request/Response logging.
        verboseLogging = true
        return self
    }
    
    func connectToRoom(url: NSURL){
        let urlString: String = url.absoluteString.stringByAppendingString("&t=json")
        let requestURL: NSURL = NSURL(string: urlString)!
        let request: NSURLRequest = NSURLRequest(URL: requestURL)
        sendURLRequest(request) { (error: NSError?, httpResponse: NSURLResponse?, responseData: NSData?) -> Void in
            if(error == nil){
                let response: NSHTTPURLResponse = httpResponse as! NSHTTPURLResponse
                let statusCode: Int = response.statusCode
                self.logVerbose("Response received: \(httpResponse?.URL), Status: \(statusCode), Headers: \(response.allHeaderFields)")
                if(statusCode == 200){
                    self.handleResponseData(responseData!, request: request)
                }
            }else{
                print("ERROR: \(error?.localizedDescription)")
            }
        }
    }
    
    func sendData(data: NSData){
        if(data.length > 0){
            let message: String = String(data: data, encoding: NSUTF8StringEncoding)!
            logVerbose("Send Message: \(message)")
            if(postMessageURL != nil){
                let request: NSMutableURLRequest = NSMutableURLRequest(URL: postMessageURL!)
                request.HTTPMethod = "POST"
                request.HTTPBody = data
                sendURLRequest(request, completionHandler: { (error: NSError?, httpResponse: NSURLResponse?, responseData: NSData?) -> Void in
                    if(error == nil){
                        let response: NSHTTPURLResponse = httpResponse as! NSHTTPURLResponse
                        let statusCode: Int = response.statusCode
                        var responseString: String = ""
                        if(responseData?.length > 0){
                            responseString = String(data: responseData!, encoding: NSUTF8StringEncoding)!
                        }
                        if(statusCode != 200){
                            self.logVerbose("Bad Response \(statusCode) to Message: \(message) \n\n \(responseString)")
                        }
                    }else{
                        print("ERROR: \(error?.localizedDescription)")
                    }
                    
                })
            }
        }
    }
    
    // Private Functions
    
    func logVerbose(message: String){
        if(verboseLogging){
            print(":LOG:")
            print(message)
            print(":END LOG:")
        }
    }
    
    func handleResponseData(responseData: NSData, request: NSURLRequest){
        let roomJSON: [NSObject: AnyObject] = parseJSONData(responseData)
        logVerbose("Room JSON: \(roomJSON)")
        if(!roomJSON.isEmpty){
            if(roomJSON["error"] != nil){
                let errorMessages: [String] = roomJSON["error_messages"] as! [String]
                var message: String = String()
                for errorMessage: String in errorMessages{
                    message = "\(message)\n\(errorMessage)"
                }
                self.delegate?.appClient(self, message: message)
            }else{
                let pcConfig: String = roomJSON["pc_config"] as! String
                let pcConfigData: NSData = pcConfig.dataUsingEncoding(NSUTF8StringEncoding)!
                let pcConfigJSON: [NSObject: AnyObject] = parseJSONData(pcConfigData)
                logVerbose("PCConfig JSON: \(pcConfigJSON)")
                if(!pcConfigJSON.isEmpty){
                    let iceServers: [RTCICEServer] = parseICEServersForPCConfigJSON(pcConfigJSON)
                    let TURNURL: String = roomJSON["turn_url"] as! String
                    requestTURNServerForICEServers(iceServers, turnServerURL: TURNURL)
                    initiator = roomJSON["initiator"]?.boolValue
                    logVerbose("Initiator: \(initiator)")
                    postMessageURL = parsePostMessageURLForRoomJSON(roomJSON, request: request)
                    logVerbose("POST Message URL: \(postMessageURL)")
                    videoConstraints = parseVideoConstraintsForRoomJSON(roomJSON)
                    logVerbose("Media Constraints: \(videoConstraints)")
                    let token: String = roomJSON["token"] as! String
                    logVerbose("About to open GAE with token: \(token)")
                    webRTCChannel = WebRTCChannelClient().initWithToken(token, delegate: messageHandler)
                }
            }
        }
    }
    
    func parseJSONData(data: NSData)->[NSObject: AnyObject]{
        var json: [NSObject: AnyObject] = [:]
        do{
            json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as! [NSObject : AnyObject]
        }catch let error as NSError{
            print("ERROR: \(error.localizedDescription)")
        }
        return json
    }
    
    func parseICEServersForPCConfigJSON(pcConfigJSON: [NSObject: AnyObject])->[RTCICEServer]{
        var result:[RTCICEServer] = []
        let iceServers:[[NSObject: AnyObject]] = pcConfigJSON["iceServers"] as! [[NSObject: AnyObject]]
        for iceServer in iceServers{
            let URL: String = iceServer["urls"] as! String
            var userName: String? = pcConfigJSON["username"] as? String
            var credential: String? = iceServer["credential"] as? String
            if(userName == nil){
                userName = ""
            }
            if(credential == nil){
                credential = ""
            }
            logVerbose("URL: \(URL) - crdential: \(credential)")
            let iceServerURL: NSURL = NSURL(string: URL)!
            let server: RTCICEServer = RTCICEServer(URI: iceServerURL, username: userName, password: credential)
            result.append(server)
        }
        return result
    }
    
    func parsePostMessageURLForRoomJSON(roomJSON: [NSObject: AnyObject], request: NSURLRequest)->NSURL?{
        var postMessageURL: NSURL? = nil
        let requestURL: String = request.URL!.absoluteString
        let queryRange: Range = requestURL.rangeOfString("?")!
        let baseURL: String = requestURL.substringToIndex(queryRange.startIndex)
        let roomKey: String = roomJSON["room_key"] as! String
        if(!roomKey.isEmpty){
            let me: String = roomJSON["me"] as! String
            if(!me.isEmpty){
                let postMessage: String = String(format: "%/message?r=%&u=%", baseURL, roomKey, me)
                postMessageURL = NSURL(string: postMessage)!
            }
        }
        return postMessageURL
    }
    
    func parseVideoConstraintsForRoomJSON(roomJSON: [NSObject: AnyObject])->RTCMediaConstraints?{
        let mediaConstraints: String = roomJSON["media_constraints"] as! String
        var constraints: RTCMediaConstraints? = nil
        if(!mediaConstraints.isEmpty){
            let constraintsData: NSData = mediaConstraints.dataUsingEncoding(NSUTF8StringEncoding)!
            let constraintsJSON: [NSObject: AnyObject] = parseJSONData(constraintsData)
            if(!constraintsJSON.isEmpty){
                if let video = constraintsJSON["video"] as? [NSObject: AnyObject]{
                    let mandatory: [NSObject: AnyObject] = video["mandatory"] as! [NSObject: AnyObject]
                    var mandatoryConstraints: [RTCPair] = []
                    
                    for (key, value) in mandatory{
                        let mandatoryKey : String = key as! String
                        let mandatoryValue: String = value as! String
                        mandatoryConstraints.append(RTCPair(key: mandatoryKey, value: mandatoryValue))
                    }
                    
                    constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)
                }else{
                    if let video = constraintsJSON["video"] as? NSNumber{
                        if video.boolValue{
                            constraints = RTCMediaConstraints()
                        }
                    }
                }
            }
        }
        return constraints
    }
    
    func requestTURNServerWithURL(turnServerURL: String, completionHandler: (turnServer: RTCICEServer? , error: NSError?)->Void){
        let turnServerURL: NSURL = NSURL(string: turnServerURL)!
        let request: NSMutableURLRequest = NSMutableURLRequest(URL: turnServerURL)
        request.addValue("Mozilla/5.0", forHTTPHeaderField: "user-agent")
        request.addValue("https://apprtc.appspot.com", forHTTPHeaderField: "origin")
        sendURLRequest(request) { (error: NSError?, httpResponse: NSURLResponse?, responseData: NSData?) -> Void in
            if(error == nil){
                let json: [NSObject: AnyObject] = self.parseJSONData(responseData!)
                let userName: String = json["username"] as! String
                let password: String = json["password"] as! String
                let URIs: [NSURL] = json["uris"] as! [NSURL]
                let turnServer: RTCICEServer = RTCICEServer(URI: URIs[0], username: userName, password: password)
                completionHandler(turnServer: turnServer, error: nil)
            }else{
                completionHandler(turnServer: nil, error: NSError(domain: "Unable to get TURN Server", code: 0, userInfo: nil))
            }
        }
    }
    
    func requestTURNServerForICEServers(iceServers: [RTCICEServer], turnServerURL: String){
        var isTurnPresent: Bool = false
        for iceServer in iceServers{
            if(iceServer.URI.scheme == "turn"){
                isTurnPresent = true
                break
            }
        }
        if(!isTurnPresent){
            requestTURNServerWithURL(turnServerURL, completionHandler: { (turnServer: RTCICEServer?, error: NSError?) -> Void in
                if(error == nil){
                    var servers: [RTCICEServer] = iceServers
                    servers.append(turnServer!)
                    print("ICE Servers: \(servers)")
                    self.delegate?.appClient(self, servers: servers)
                }else{
                    print("ERROR: \(error!.localizedDescription)")
                }
            })
        }else{
            print("ICE Servers: \(iceServers)")
            delegate?.appClient(self, servers: iceServers)
        }
    }
    
    func sendURLRequest(request: NSURLRequest, completionHandler: (error: NSError?, httpResponse: NSURLResponse?, responseData: NSData?)->Void){
        let requestTask: NSURLSessionDataTask = NSURLSession().dataTaskWithRequest(request) { (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completionHandler(error: error, httpResponse: response, responseData: data)
            })
        }
        requestTask.resume()
    }
}