//
//  CLEADevice.swift
//  LightingTo3.5
//
//  Created by SPK_Antony on 01/12/2016.
//  Copyright © 2016 Spark Technology Inc. All rights reserved.
//

import UIKit

// 协议(是CLEAProtocol用到的,用于回调什么?)
protocol Device {
    func setRegister(register: UInt8, value: UInt8, page: UInt8)
    func setStatus(status: [UInt8], count: Int)
}

class CLEADevice: NSObject {

}
