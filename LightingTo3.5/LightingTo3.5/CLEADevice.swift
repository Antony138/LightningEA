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
    
    // MARK:- 属性
    static let HwStateChangedNotification = "HwStateChanged"
    static let BusyTimeout = 10
    
    static let PAGE_COUNT         = 256
    static let DEV_FLASH_ADDRESS  = 0x8000
    static let FW_VERSION_ADDRESS = 0x9FC0
    static let FW_SIZE            = 8 * 1024
    // 每个数据包的大小?
    static let FW_BLOCK_SIZE      = 64
    
    // 硬件状态
    static let STATUS_NOT_CONNECTED: UInt8    = 0
    static let STATUS_FW_IS_RUNNING: UInt8    = 1
    static let STATUS_WAITING_FW_DATA: UInt8  = 2
    static let STATUS_FAILED: UInt8           = 3
    static let STATUS_WAITING_RESPONSE: UInt8 = 4
    static let STATUS_NOT_RESPONDING: UInt8   = 5
    
    // 失败原因
    static let FAILED_FLASH: UInt8    = 1
    static let FAILED_CHECKSUM: UInt8 = 2
    static let FAILED_LENGTH: UInt8   = 3
    static let FAILED_REQUEST: UInt8  = 4
    static let FAILED_TIMEOUT: UInt8  = 5
    
    static let PollingTimeInterval = 2.0
    
    static private var sharedInstance: CLEADevice?
    
    
}
