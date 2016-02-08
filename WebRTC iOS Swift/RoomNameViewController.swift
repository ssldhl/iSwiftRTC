//
//  RoomNameViewController.swift
//  WebRTC iOS Swift
//
//  Created by Sushil Dahal on 2/8/16.
//  Copyright © 2016 Sushil Dahal. All rights reserved.
//

import UIKit

class RoomNameViewController: UIViewController {
    @IBOutlet weak var roomName: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func connectButton(sender: UIButton) {
        if let roomNameValue: String = roomName.text!{
            if !roomNameValue.isEmpty{
                self.performSegueWithIdentifier("connectToRoom", sender: roomNameValue)
            }else{
                showAlertWithMessage("Room name cannot be left blank")
            }
        }else{
            showAlertWithMessage("Enter the room name")
        }
    }
    
    func showAlertWithMessage(message: String){
        let alertView: UIAlertController = UIAlertController(title: nil, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        let alertAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil)
        alertView.addAction(alertAction)
        self.presentViewController(alertView, animated: true, completion: nil)
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if(segue.identifier == "connectToRoom"){
            let webRTCVC: WebRTCViewController = segue.destinationViewController as! WebRTCViewController
            let data: String = sender as! String
            webRTCVC.roomName = data
        }
    }

}
