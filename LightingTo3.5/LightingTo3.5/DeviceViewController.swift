//
//  ViewController.swift
//  LightingTo3.5
//
//  Created by SPK_Antony on 28/11/2016.
//  Copyright © 2016 Spark Technology Inc. All rights reserved.
//

import UIKit

class DeviceViewController: UITableViewController {
    
    // MARK:- Properties
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
    
    // MARK:- Methods
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func updateFw(_ sender: UIButton) {
        
        let device = CLEADevice.shared()
        
        if device.fwRevision != device.loadedFWVersion {
            
            updateAlert.title = "New FW version" + device.loadedFWVersion + "is available"
            updateAlert.message = "This version fixes errors and improves stability"
            
            present(updateAlert, animated: true, completion: nil)
        }
        else {
            
            updateAlert.title = "FW version " + device.loadedFWVersion + " on device is up to date"
            updateAlert.message = " Do you still want to update it?"
            
            present(updateAlert, animated: true, completion: nil)
        }
    }
    
    
    // MARK:- 私有部分
    private func updateStatus() {
        let device = CLEADevice.shared()
        
        hwName.text             = device.name
        hwManufacturer.text     = device.manufacturer
        hwModel.text            = device.model
        hwSerialN.text          = device.serialNumber
        hwSerialImageView.image = device.SerialBarCodeImage
        hwRevision.text         = device.hwRevision
        fwVersion.text          = device.fwRevision
        loadedFWVersion.text    = device.loadedFWVersion
        
        let status = device.getStatus()
        switch status {
        case CLEADevice.STATUS_NOT_CONNECTED:
            fwStatus.text = "Status: Not connected"
            
        case CLEADevice.STATUS_NOT_RESPONDING:
            fwStatus.text = "Status: Not responding"
            
        case CLEADevice.STATUS_WAITING_RESPONSE:
            fwStatus.text = "Status: Requesting status..."
            
        case CLEADevice.STATUS_FW_IS_RUNNING:
            fwStatus.text = "Status: FW v\(device.fwVersion) is running"
            
        case CLEADevice.STATUS_WAITING_FW_DATA:
            let bnum = CLEADevice.shared().getFlashingBlkNum()
            fwStatus.text = "Status: " + (bnum < 0 ? "No FW, waiting for FW blocks to flash" : "Flashing FW block \(bnum)")
            
        case CLEADevice.STATUS_FAILED:
            let bnum = CLEADevice.shared().getFlashingBlkNum()
            fwStatus.text = "Status: " + (bnum < 0 ? "Failed" : "Flashing FW block \(bnum) failed")

        default:
            fwStatus.text = "Status: Device internal error \(status)"
            log(message: "**** Device internal error \(status)", obj: self)
        }
        
        // 升级按钮隐藏与否
        if status == CLEADevice.STATUS_NOT_CONNECTED || status == CLEADevice.STATUS_NOT_RESPONDING {
            updateFwBtn.isHidden = true
        }
        else {
            updateFwBtn.isHidden = false
        }
    }
}

