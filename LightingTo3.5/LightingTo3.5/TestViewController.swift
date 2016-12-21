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

        // Do any additional setup after loading the view.
        
        

        
        NotificationCenter.default.addObserver(self, selector: #selector(TestViewController.accessoryConnected(notification:)), name: NSNotification.Name(CLEADevice.DidConnectedDivice), object: nil)
    }

    @objc private func accessoryConnected(notification: NSNotification) {
        
        if let ea = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
            
            self.textView.text = ea.name;
            
        }
    
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
