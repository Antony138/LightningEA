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
    
    let colseAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: {
        (act: UIAlertAction)in
        // do nothing
    })
    
    let updteAction = UIAlertAction.init(title: "Update", style: UIAlertActionStyle.default, handler: {
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
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

