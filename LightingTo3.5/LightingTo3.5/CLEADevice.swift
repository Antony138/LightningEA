//
//  CLEADevice.swift
//  LightingTo3.5
//
//  Created by SPK_Antony on 01/12/2016.
//  Copyright © 2016 Spark Technology Inc. All rights reserved.
//

import UIKit
import ExternalAccessory

// 协议(是CLEAProtocol用到的,用于回调什么?)
protocol Device {
    func setRegister(register: UInt8, value: UInt8, page: UInt8)
    func setStatus(status: [UInt8], count: Int)
}

class CLEADevice: NSObject, EAAccessoryDelegate {
    
    // MARK:- 属性
    static let HwStateChangedNotification = "HwStateChanged"
    static let BusyTimeout = 10
    static let NA = "N/A"
    
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
    
    // MARK: 单例
    static private var sharedInstance: CLEADevice?
    
    class func shared() -> CLEADevice {
        if sharedInstance == nil {
            sharedInstance = CLEADevice()
        }
        return sharedInstance!
    }
    
    // MARK: 判断硬件是否是连接状态(并不是接口方法,可否放私有部分?)
    // 是否可以弄成method? 一定要弄成property吗?
    var eaDevConnected: Bool {
        if let ea = getEA() {
            return ea.isConnected
        }
        return false
    }
    
    // MARK:- 接口方法
    // MARK: (监测)连接硬件
    func connect() {
        log(message: "*** START EA connection monitoring ***", obj: self)
        
        // 监听硬件连接
        
        // 不能用类似OC的block回调?
//        let mainQueue = OperationQueue.main
//        NotificationCenter.default.addObserver(forName: NSNotification.Name.EAAccessoryDidConnect, object: nil, queue: mainQueue) { (note) in
//        }
        NotificationCenter.default.addObserver(self, selector: #selector(CLEADevice.accessoryConnected(notification:)), name: NSNotification.Name.EAAccessoryDidConnect, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(CLEADevice.accessoryDisconnected(notification:)), name: NSNotification.Name.EAAccessoryDidDisconnect, object: nil)
        
        EAAccessoryManager.shared().registerForLocalNotifications()
        
        if eaDevConnected {
            openConnection()
        }
    }
    
    // MARK: 断开硬件连接
    func disconnect() {
        log(message: "*** STOP EA connection monitoring ***", obj: self)
        
        // 取消监听通告
        EAAccessoryManager.shared().unregisterForLocalNotifications()
        
        NotificationCenter.default.removeObserver(self)
        
        closeConnection()
        
        connectedAccessory = nil
        
        quirkAccessory = nil
    }
    
    // MARK:- 其他属性
    var name: String {
        if let ea = getEA() {
            if ea.isConnected {
                return ea.name
            }
        }
        return CLEADevice.NA
    }
    
    var manufacturer: String {
        if let ea = getEA() {
            if ea.isConnected {
                return ea.manufacturer
            }
        }
        return CLEADevice.NA
    }
    
    var model: String {
        if let ea = getEA() {
            if ea.isConnected {
                if let qea = getQuirkEA() {
                    // 有QuirkEA就拿QuirkEA的,为什么不直接拿getEA的?
                    return qea.modelNumber
                }
                else {
                    return ea.modelNumber
                }
            }
        }
        return CLEADevice.NA
    }
    
    var serialNumber: String {
        if let ea = getEA() {
            if ea.isConnected {
                return ea.serialNumber
            }
        }
        return CLEADevice.NA
    }
    
    var hwRevision: String {
        if let ea = getEA() {
            if ea.isConnected {
                return ea.hardwareRevision
            }
        }
        return CLEADevice.NA
    }
    
    var fwRevision: String {
        if let ea = getEA() {
            if ea.isConnected {
                if let qea = getQuirkEA() {
                    return qea.firmwareRevision
                }
                else {
                    return ea.firmwareRevision
                }
            }
        }
        return CLEADevice.NA
    }
    
    var fwVersion: String {
        // 判断有值了, 就可以直接用感叹号解包
        return (fwVer == nil) ? CLEADevice.NA : fwVer!
    }
    
    var loadedFWVersion: String {
        // 获取位置/地址?（什么位置/地址）
        let fwLoc = CLEADevice.FW_VERSION_ADDRESS - CLEADevice.DEV_FLASH_ADDRESS
        
        return "\(fwData[fwLoc]).\(fwData[fwLoc + 1]).\(fwData[fwLoc + 2])"
    }
    
    // 这两个属性表示？
    var hwStateRegsPage: UInt8?
    var hwStateRegsCnt: UInt8?
    
    
    // MARK:- 私有部分
    private var connectedAccessory: EAAccessory?
    
    private var quirkAccessory: EAAccessory?
    
    // 这个表示固件的什么?(好像不是版本,因为是running才赋值的)
    private var fwVer: String?
    
    // 固件数据(等式后面的表示容量和初始化值？)
    private var fwData = [UInt8](repeating: 0, count: FW_SIZE)
    
    // MARK: 获取设备
    private func getEA() -> EAAccessory? {
        if connectedAccessory == nil {
            let eam = EAAccessoryManager.shared()
            for ea in eam.connectedAccessories {
                if eaSupportsCLProtocol(ea: ea) {
                    ea.delegate = self
                    connectedAccessory = ea
                }
            }
        }
        return connectedAccessory
    }
    
    private func getQuirkEA() -> EAAccessory? {
    
    }
    
    // MARK: 判断是否支持协议(调用CLEAProtocol的接口方法)
    private func eaSupportsCLProtocol(ea: EAAccessory) -> Bool {
        for proto in ea.protocolStrings {
            if CLEAProtocol.shared().supportsProtocol(protocolName: proto) {
                return true
            }
        }
        return false
    }
    
    // MARK: 监测到有Lighting硬件连接后的回调方法
    @objc private func accessoryConnected(notification: NSNotification) {
        
        // Get EA object
        if let ea = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
            log(message: "\(ea)", obj: self)
            
            if eaSupportsCLProtocol(ea: ea) {
                if connectedAccessory != nil {
                    // 如果有新硬件连接,但是connectedAccessory是有值的(表示有旧硬件), 要先将旧硬件的传输通道先关闭?
                    log(message: "*** New EA connected but \(connectedAccessory!.name) was not disconnected?!", obj: self)
                    
                    closeConnection()
                }
                
                // 有我们的硬件连接了
                log(message: "CL EA connected", obj: self)
                ea.delegate = self
                
                connectedAccessory = ea
                
                openConnection()
            }
            else {
                // 不遵守协议的硬件(不是我们的硬件)
                log(message: "Connected EA does not support CL protocol", obj: self)
                
                // 这里究竟是做一种什么防呆?
                if let ca = connectedAccessory {
                    if ca.name == ea.name || ca.manufacturer == ea.manufacturer {
                        log(message: "*** Quirk EA is used to update invalid info", obj: self)
                        
                        ea.delegate = self
                        quirkAccessory = ea
                        
//                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: CLEADevice.HwStateChangedNotification), object: self)
                        // 确认: 是否一定要上面的rawValue:
                        NotificationCenter.default.post(name: NSNotification.Name(CLEADevice.HwStateChangedNotification), object: self)
                    }
                }
            
            }
        }
        else {
            log(message: "**** Non-EA notification", obj: self)
        }
    }
    
    // MARK: 监测到有Lighting硬件断开后的回调方法
    @objc private func accessoryDisconnected(notification: NSNotification) {
        
        // Get EA object
        if let ea = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
            log(message: "\(ea)", obj: self)
            
            if eaSupportsCLProtocol(ea: ea) {
                log(message: "CL EA disconnected!", obj: self)
                
                // 关闭传输通道, 置空对象
                closeConnection()
                connectedAccessory = nil
            }
            else {
                log(message: "**** Disconnected EA does not support CL protocol", obj: self)
                
                if quirkAccessory?.connectionID == ea.connectionID {
                    log(message: "**** Quirk EA disconnected", obj: self)
                    quirkAccessory = nil
                }
            }
        }
        else {
            log(message: "**** Non-EA notification?!", obj: self)
        }
    }
    
    // MARK: 打开传输通道
    private func openConnection() {
    
    }
    
    // MARK: 关闭传输通道
    private func closeConnection() {
    
    }
    
}
