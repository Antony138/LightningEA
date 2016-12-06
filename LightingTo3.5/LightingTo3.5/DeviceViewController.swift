//
//  ViewController.swift
//  LightingTo3.5
//
//  Created by SPK_Antony on 28/11/2016.
//  Copyright © 2016 Spark Technology Inc. All rights reserved.
//

import UIKit

class DeviceViewController: UITableViewController {
    
    let notFoundAlert = UIAlertController(title: nil, message: nil, preferredStyle:UIAlertControllerStyle.alert)
    
    let updateAlert = UIAlertController(title: nil, message: nil, preferredStyle:UIAlertControllerStyle.alert)
    
    let closeAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: {
        (act: UIAlertAction)in
        // do nothing
    })
    
    let updateAction = UIAlertAction.init(title: "Update", style: UIAlertActionStyle.default, handler: {
        // 这个就是Swift中的闭包?
        (act: UIAlertAction)in
        CLEADevice.shared().updateFw()
    })
    
    
    @IBOutlet weak var hwName: UILabel!
    
    @IBOutlet weak var hwManufacturer: UILabel!
    
    @IBOutlet weak var hwModel: UILabel!
    
    @IBOutlet weak var hwSerialN: UILabel!
    
    @IBOutlet weak var hwSerialImageView: UIImageView!
    
    @IBOutlet weak var hwRevision: UILabel!
    
    @IBOutlet weak var fwVersion: UILabel!
    
    @IBOutlet weak var loadedFWVersion: UILabel!

    @IBOutlet weak var fwStatus: UILabel!
    
    @IBOutlet weak var updateFwBtn: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // 通告中的闭包?(OC中的Block?)
        NotificationCenter.default.addObserver(forName: NSNotification.Name.EAAccessoryDidConnect, object: nil, queue: nil, using: {
            (notification: Notification)in
            log(message: "EAAccessoryDidConnect", obj: self)
        })
        
        self.tableView.contentInset = UIEdgeInsetsMake(20.0, 0.0, 44.0, 0.0)
        self.tableView.showsVerticalScrollIndicator = false
        
        notFoundAlert.addAction(closeAction)
        updateAlert.addAction(updateAction)
        updateAlert.addAction(closeAction)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        log(message: " Device view!", obj: self)
        
        // 更新硬件的状态
        let device = CLEADevice.shared()
        
        if !device.busy() {
            device.updateDeviceStatus()
        }
        
        // 更新UI
        updateStatus()
        
        // 注册通告, 收到HwStateChangedNotification、退到后台通告后, 更新UI
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: CLEADevice.HwStateChangedNotification), object: nil, queue: nil, using: {(notification: Notification)in
            log(message: "CL EADevice status changed!", obj: self)
            self.updateStatus()
        })
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: nil, using: {(notification: Notification)in
            self.updateStatus()
        })
    }
    
    // MARK:- 私有部分
    private func updateStatus() {
    
    
    
    }
}

