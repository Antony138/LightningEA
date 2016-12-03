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
    
    // MARK: 获取硬件状态
    func getStatus() -> UInt8 {
        objc_sync_enter(self)
        // 初始化值为STATUS_NOT_CONNECTED
        let currStatus = devStatus
        objc_sync_exit(self)
        
        return currStatus
    }
    
    // MARK: 获取烧录进度
    func getFlashingBlkNum() -> Int {
        return fwBlkToFlash
    }
    
    // MARK: 加载(load)固件
    func loadFw() throws {
        // stm8l10x_fw是固件名, 后缀名s19
        let fwPath = Bundle.main.path(forResource: "stm8l10x_fw", ofType: "s19")
        
        // 返回NSData对象吗？
        let s19Data = try String(contentsOfFile: fwPath!, encoding: String.Encoding.utf8)
        
        let s19Lines = s19Data.components(separatedBy: "\n")
        
        for s in s19Lines {
            parseS19Line(s: s)
        }
    }
    
    func updateFw() {
        fwUpdateEnabled = true
        fwBlkToFlash = -1
        failCnt = 0
        // 发送指令, 请求升级
        CLEAProtocol.shared().requestFwUpdate()
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
    
    // MARK:- 这部分不是接口方法,也不是私有方法?
    // MARK: 读取硬件状态?(发送了指令)
    func readHwStatusPage(page: UInt8, count: UInt8) {
        hwStateRegsPage = page
        hwStateRegsCnt = count
        
        // 发送指令requestRegistersRead
        updateHwStateRegsCache()
    }

    // MARK: 重置各种状态(调用了CLEAProtocol的reset()方法)
    func reset() {
        objc_sync_enter(self)
        // repeating,repeatElement都可以?
        regCache = [[Int : UInt8]](repeatElement([:], count: CLEADevice.PAGE_COUNT))
        fwBlkToFlash = -1
        fwUpdateEnabled = false
        objc_sync_exit(self)
        
        CLEAProtocol.shared().reset()
        
        log(message: "RESET", obj: self)
    }
    
    // MARK: 判断,是否繁忙/是否有正在发送的数据
    func busy() -> Bool {
        return CLEAProtocol.shared().waitingForResponse()
    }
    
    // MARK: getRegister(有什么用?)
    func getRegister(register: UInt8, page: UInt8) -> UInt8 {
        
        assert(Int(page) < regCache.count, "Invalid register page \(page) - must be less than \(regCache.count)")
        
        objc_sync_enter(self)
        // 这是一个数组, 还是字典?
        let val = regCache[Int(page)][Int(register)]
        objc_sync_exit(self)
        
        return val!
    }
    
    // MARK: 更新状态
    func updateDeviceStatus() {
        if eaDevConnected {
            // 如果时连接状态
            setStatus(status: [0, CLEADevice.STATUS_WAITING_RESPONSE], count: 2)
            
            // 发送指令, 查询硬件状态?
            CLEAProtocol.shared().requestStatusUpdate()
        }
        else {
            // 处于没有连接的状态
            setStatus(status: [0, CLEADevice.STATUS_NOT_CONNECTED], count: 2)
        }
    }
    
    // MARK:- protocol方法的实现?
    // 实现Device协议的方法setRegister
    // 可以将参数page直接赋值?(那调用方法时传参,不会直接覆盖掉这个0吗?那这里赋值还有什么意义?)
    func setRegister(register: UInt8, value: UInt8, page: UInt8 = 0) {
        objc_sync_enter(self)
        regCache[Int(page)][Int(register)] = value
        objc_sync_exit(self)
    }
    
    // 实现Device协议的方法setStatus
    func setStatus(status: [UInt8], count: Int) {
        
        var sts = status[1]
        
        log(message: " status \(sts) cnt \(count)", obj: self)
        
        switch sts {
        case CLEADevice.STATUS_WAITING_FW_DATA:
            if fwUpdateEnabled {
                if fwBlkToFlash < 0 {
                    // 未烧录状态?
                    fwBlkToFlash = fwBlock.count
                }
                
                fwBlkToFlash -= 1
                
                // TODO: 确认这种for循环是否可用
                var j: Int?
                for i in stride(from: fwBlkToFlash, through: 0, by: -1) {
                    j = i
                    if fwBlock[i] {
                        break
                    }
                }
                fwBlkToFlash = j!
                
                if fwBlkToFlash < 0 {
                    // FW has been flashed, booting(准备要升级了?要进入boot状态?)
                    fwUpdateEnabled = false
                    
                    sts = CLEADevice.STATUS_WAITING_RESPONSE
                    
                    // 发送指令, 重启进bootloader?
                    CLEAProtocol.shared().requestFwBoot()
                    
                    Timer.scheduledTimer(timeInterval: CLEADevice.PollingTimeInterval,
                                         target: self,
                                         selector: #selector(CLEADevice.refreshHwState),
                                         userInfo: nil,
                                         repeats: false)
                }
                else {
                    NotificationCenter.default.post(name: NSNotification.Name(CLEADevice.HwStateChangedNotification), object: self)
                    
                    // 发送指令烧录固件
                    CLEAProtocol.shared().requestFwBlockFlash(blkNum: UInt8(fwBlkToFlash), fwData: fwData)
                }
            }
            
        case CLEADevice.STATUS_FAILED:
            
            if fwUpdateEnabled && fwBlkToFlash > 0  {
                log(message: "**** failed to flash FW block!", obj: self)
                
                failCnt += 1
                
                if failCnt > 3 {
                    // 失败次数大于3次
                    fwUpdateEnabled = false
                    
                    fwBlkToFlash = -1
                    
                    // 发送指令取消升级
                    CLEAProtocol.shared().requestFwUpdateCancel()
                    
                    Timer.scheduledTimer(timeInterval: CLEADevice.PollingTimeInterval,
                                         target: self,
                                         selector: #selector(CLEADevice.refreshHwState),
                                         userInfo: nil,
                                         repeats: false)
                }
                else {
                    fwBlkToFlash += 1
                    
                    // 查询硬件状态
                    CLEAProtocol.shared().requestStatusUpdate()
                }
            }
            else {
                log(message: "**** invalid request?!", obj: self)
            }
            
        case CLEADevice.STATUS_FW_IS_RUNNING:
            if count >= 5 {
                fwVer = "\(status[2]).\(status[3]).\(status[4])"
            }
            
        case CLEADevice.STATUS_NOT_RESPONDING:
            // 发送指令, 重置(rest)
            CLEAProtocol.shared().reset()
            
        default:
            break
        }
        
        objc_sync_enter(self)
        devStatus = sts
        objc_sync_exit(self)
    }
    
    
    
    // MARK:- 私有部分
    private var connectedAccessory: EAAccessory?
    
    private var quirkAccessory: EAAccessory?
    
    // 这个表示固件的什么?(好像不是版本,因为是running才赋值的)
    private var fwVer: String?
    
    // 固件数据(等式后面的表示容量和初始化值？)
    private var fwData = [UInt8](repeating: 0, count: FW_SIZE)
    
    // 这是一个数组,数组里面存的是字典？
    private var regCache = [[Int : UInt8]](repeating: [:], count: PAGE_COUNT)
    
    // 烧录的进度
    private var fwBlkToFlash = -1 // if >= 0 the fw flashing is in progress
    
    private var fwUpdateEnabled = false
    
    // 数组,存若干Bool值
    private var fwBlock = [Bool](repeating: false, count: FW_SIZE / FW_BLOCK_SIZE)
    
    // 失败次数计数?
    private var failCnt = 0
    
    private var devStatus: UInt8 = CLEADevice.STATUS_NOT_CONNECTED
    
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
        if quirkAccessory == nil {
            if let connEA = getEA() {
                let eam = EAAccessoryManager.shared()
                for ea in eam.connectedAccessories {
                    if !eaSupportsCLProtocol(ea: ea) && connEA.name == ea.name && connEA.manufacturer == ea.manufacturer {
                        log(message: "**** Quirk EA \(ea.name) is used to update invalid info", obj: self)
                        
                        ea.delegate    = self
                        quirkAccessory = ea
                    }
                }
            }
        }
        return quirkAccessory
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
    
    // 发一条指令给硬件.是干嘛用的的?
    private func updateHwStateRegsCache() {
        if hwStateRegsCnt != nil && hwStateRegsPage != nil {
            for i in 0..<hwStateRegsCnt! {
                // 调用接口方法,发送指令requestRegistersRead
                CLEAProtocol.shared().requestRegisterRead(register: i, page: hwStateRegsPage!)
            }
        }
    }
    
    // 升级过程中更新更新硬件状态?
    @objc private func refreshHwState() {
        updateDeviceStatus()
    }
    
    // 解析固件?
    private func parseS19Line(s: String) {
        
    }
    
}
