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

