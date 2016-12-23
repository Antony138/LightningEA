//
//  TestViewController.swift
//  LightingTo3.5
//
//  Created by SPK_Antony on 21/12/2016.
//  Copyright © 2016 Spark Technology Inc. All rights reserved.
//

import UIKit
import ExternalAccessory

class TestViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        // 注册通告, 收到"HwStateChangedNotification"、"即将进入前台"通告后, 更新UI
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: CLEADevice.HwStateChangedNotification), object: nil, queue: nil, using: {(notification: Notification)in
            log(message: "CL EADevice status changed!", obj: self)
            self.updateStatus()
        })
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: nil, using: {(notification: Notification)in
            self.updateStatus()
        })
        
        
        self.updateStatus()

    }
    
    // MARK:- 私有部分
    private func updateStatus() {
        let device = CLEADevice.shared()
        
        
        if device.protocolsString.isEmpty {
            // 空的，表示拿到"假硬件"
        }
        else {
            textView.text = device.protocolsString
        }
    }

}
