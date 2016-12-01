//
//  CLEAProtocol.swift
//  LightingTo3.5
//
//  Created by SPK_Antony on 28/11/2016.
//  Copyright © 2016 Spark Technology Inc. All rights reserved.
//

// 此类负责和硬件通讯

import UIKit
import ExternalAccessory

class Queue<T> {
    // queue是一个arry?
    var queue = [T]()
    
    func isEmpty() -> Bool {
        return queue.count == 0
    }
    
    func queue(data: T) {
        queue.append(data)
    }
    
    func dequeue() -> T? {
        // 加判断,防止数组越界?
        if queue.count > 0 {
            return queue.remove(at: 0)
        }
        return nil;
    }
    
    func deleteAll() {
        queue.removeAll(keepingCapacity: false)
    }
}

class CLEAProtocol: NSObject, StreamDelegate {
    
    // MARK: 常量
    
    // 以下是指令相关的Packet Tag(原项目用1～5,不是0x开头的,确认有无影响)
    // 请求硬件状态?
    static let STATUS_TAG: UInt8       = 0x01
    // 请求固件升级
    static let UPDATE_FW_TAG: UInt8    = 0x02
    // 烧录固件
    static let FLASH_FW_BLK_TAG: UInt8 = 0x03
    // 启动固件升级?
    static let BOOT_FW_TAG:UInt8       = 0x04
    // 取消固件升级
    static let CANCEL_TAG: UInt8       = 0x05
    // 写入
    static let WRITE_TAG: UInt8        = 0xEA
    // 读取
    static let READ_TAG: UInt8         = 0xEB
    
    static let TIMEOUT   = 3.0
    static let RETRY_CNT = 10
    
    // MARK: 单例
    static private var sharedInstance: CLEAProtocol?
    
    class func shared() -> CLEAProtocol {
        if sharedInstance == nil {
            sharedInstance = CLEAProtocol()
        }
        return sharedInstance!
    }
    
    // MARK:- 接口方法
    // MARK: 判断是协议是否相等
    func supportsProtocol(protocolName: String) -> Bool {
        return eaProtocolString == protocolName
    }
    
    // MARK: 打开传输通道
    func openSession(ea: EAAccessory) -> Bool {
        if clEASession != nil {
            closeSession()
            log(message: "**** 打开前已经有旧的通道(已经创建了clEASession对象),所以要先关闭之前的通道?,", obj: self)
        }
        
        if ea.isConnected {
            clEASession = EASession(accessory: ea, forProtocol: eaProtocolString)
            
            if clEASession != nil {
                // 语法:这里可以强制解包,是因为上面已经坐了判断——是否为空
                clEASession!.inputStream!.delegate = self
                clEASession!.inputStream!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                clEASession!.inputStream!.open()
                
                clEASession!.outputStream!.delegate = self
                clEASession!.outputStream!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                clEASession!.outputStream?.open()
                
                return true
            }
            log(message: "**** 创建不了 EASession对象", obj: self)
        }
        log(message: "**** 硬件没有连接?!", obj: self)
        return false
    }
    
    // MARK: 关闭传输通道
    func closeSession() {
        if clEASession != nil {
            clEASession!.inputStream!.close()
            clEASession!.inputStream!.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
            clEASession!.inputStream!.delegate = nil
            
            clEASession!.outputStream!.close()
            clEASession!.outputStream!.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
            clEASession!.outputStream!.delegate = nil
            
            // 重置所有参数,变量?
            reset()
            
            clEASession = nil
        }
    }
    
    // MARK: 重置
    func reset() {
        // objc_sync_enter(),objc_sync_exit()是为了对代码进行"原子操作"(在写入或读取时,只允许在一个时刻一个角色进行操作),
        objc_sync_enter(self)
        dataPackets.deleteAll()
        waitingResponseFor = nil
        stopTimeOutTimer()
        objc_sync_exit(self)
        log(message: "RESET", obj: self)
    }
    
    // MARK: 鉴别是不是预期的指令(其他类没有用到这个方法,不可以写成私有?)
    // MARK: BOOT_FW_TAG、CANCEL_TAG不是预期的?
    func responseExpected(packetTag: UInt8) -> Bool {
        if packetTag == CLEAProtocol.BOOT_FW_TAG || packetTag == CLEAProtocol.CANCEL_TAG {
            return false
        }
        return true
    }
    
    // MARK: 查询是否为"等待状态"?(判断waitingResponseFor是否有数据)
    func waitingForResponse() -> Bool {
        objc_sync_enter(self)
        let state = (waitingResponseFor != nil)
        objc_sync_exit(self)
        return state
    }
    
    // MARK: StreamDelegate
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.openCompleted:
            log(message: "\(aStream) stream opened", obj: self)
            
        case Stream.Event.hasBytesAvailable:
            log(message: "\(aStream) stream has data", obj: self)
            
            // 收到硬件的数据会回调此方法?
            objc_sync_enter(self)
            // 处理接收到的数据
            parseResponse()
            
            // 为什么这里又要发送指令(数据)
            sendRequest()
            
            if waitingResponseFor == nil {
                // TODO: 发送通告，状态改变
            }
            
            objc_sync_exit(self)
            
        case Stream.Event.hasSpaceAvailable:
            log(message: "\(aStream) stream has space", obj: self)
            
            // 可以发数据给硬件(其他指令也发送数据,和在这里发,有什么区别?)
            objc_sync_enter(self)
            // 发送数据
            sendRequest()
            objc_sync_exit(self)
            
        case Stream.Event.errorOccurred:
            log(message: "stream error", obj: self)
            
        case Stream.Event.endEncountered:
            log(message: "stream EOF", obj: self)
            
        default:
            log(message: "stream other event \(eventCode)", obj: self)
        }
    }
    
    // MARK:- Commands(指令部分:9条)
    // MARK: Command-查询状态
    func requestStatusUpdate() {
        log(message: "status request", obj: self)
        
        let dataPacket: [UInt8] = [CLEAProtocol.STATUS_TAG]
        
        objc_sync_enter(self)
        // 组织数据. queue()方法,其实是append数据到数组中
        dataPackets.queue(data: dataPacket)
        
        // 发送数据
        sendRequest()
        objc_sync_exit(self)
    }
    
    // MARK: Command-请求升级
    func requestFwUpdate() {
        log(message: "update FW request", obj: self)
        
        let dataPacket: [UInt8] = [CLEAProtocol.UPDATE_FW_TAG]
        
        objc_sync_enter(self)
        dataPackets.queue(data: dataPacket)
        sendRequest()
        objc_sync_exit(self)
    }
    
    // MARK: Command-烧录固件
    // 固件大小是14KB, 一次发送的数据量大小限制是多少? 是需要分拆数据包进行发送吗?
    func requestFwBlockFlash(blkNum: UInt8, fwData: [UInt8]) {
        log(message: "FW block to flash request - \(blkNum)", obj: self)
        
        // 声明一个数组变量, 前两个byte分别存放0x03、blkNum
        var dataPacket: [UInt8] = [CLEAProtocol.FLASH_FW_BLK_TAG, blkNum]
        
        // TODO: 两个64要用CLEADevice.FW_BLOCK_SIZE代替
        for i in 0..<64 {
            // 组织数据(为什么不用dataPackets的queue了？)
            dataPacket.append(fwData[Int(blkNum) * 64 + i])
        }
        
        objc_sync_enter(self)
        dataPackets.queue(data: dataPacket)
        sendRequest()
        objc_sync_exit(self)
    }
    
    // MARK: Command-引导启动?
    // 请求升级前要先发一条这样的指令,"重启进bootloader，擦除application的flash，准备接收接下来的数据"?
    func requestFwBoot() {
        log(message: "boot FW request", obj: self)
        
        let dataPacket: [UInt8] = [CLEAProtocol.BOOT_FW_TAG]
        
        objc_sync_enter(self)
        dataPackets.queue(data: dataPacket)
        sendRequest()
        objc_sync_exit(self)
    }
    
    // MARK: Command-取消升级
    func requestFwUpdateCancel() {
        log(message: "cancel FW update request", obj: self)
        
        let dataPacket: [UInt8] = [CLEAProtocol.CANCEL_TAG]
        
        objc_sync_enter(self)
        dataPackets.queue(data: dataPacket)
        sendRequest()
        objc_sync_exit(self)
    }
    
    // MARK:注册"写"数据?(注册了才能写入数据?还是这是另一个写入数据的指令?)
    // 好像这个接口方法都没有被用到
    func requestRegistersWrite(register: UInt8, values: [UInt8], page: UInt8 = 0) {
        log(message: "page \(page) reg \(register) val \(values[0])", obj: self)
        
        // values是需要写的数据？
        var dataPacket: [UInt8] = [CLEAProtocol.WRITE_TAG, page, register, UInt8(values.count)]
        dataPacket += values
        
        objc_sync_enter(self)
        dataPackets.queue(data: dataPacket)
        sendRequest()
        objc_sync_exit(self)
    }
    
    // 这个又是干嘛的?都没有被用到
    func requestRegisterWrite(register: UInt8, value: UInt8, page: UInt8 = 0) {
        requestRegistersWrite(register: register, values: [value], page: page)
    }
    
    
    func requestRegistersRead(register: UInt8, count: UInt8, page: UInt8 = 0) {
        log(message: "page \(page) reg \(register) cnt \(count)", obj: self)
        
        let dataPacket: [UInt8] = [CLEAProtocol.READ_TAG, page, register, count]
        
        objc_sync_enter(self)
        dataPackets.queue(data: dataPacket)
        sendRequest()
        objc_sync_exit(self)
    }
    
    // MARK:注册"读"数据? 这个方法有被其他类调用
    func requestRegisterRead(register: UInt8, page: UInt8 = 0) {
        requestRegistersRead(register: register, count: 1, page: page)
    }
    
    
    // MARK:- 私有部分
    // 协议字符串
    private let eaProtocolString: String
    // EASession对象
    private var clEASession: EASession?
    // 这是一个类实例?
    private var dataPackets = Queue<[UInt8]>()
    // 数组,装什么数据的？(应该是发送的数据)
    private var waitingResponseFor: [UInt8]?
    // 重试次数?
    private var retries = 0
    // 超时定时器?
    private var toutTimer: Timer?
    
    // 覆盖初始化方法,初始化该类时,就获取协议字符串(com.fengeek.f002)
    private override init() {
        eaProtocolString = (Bundle.main.infoDictionary?["UISupportedExternalAccessoryProtocols"] as! [String])[0]
    }
    
    // MARK: 实作接收硬件数据的方法
    private func parseResponse() -> Bool {
        var ret = false
        
        var dataPacket = [UInt8](repeating: 0, count: 128)
        
        if let cnt = clEASession?.inputStream?.read(&dataPacket, maxLength: dataPacket.count) {
            // 打印接收到的数据前三个字节？
            log(message: "<<<<< packet sz \(cnt) packet tag \(dataPacket[0]) data \(dataPacket[1]) \(dataPacket[2]) \(dataPacket[3])...", obj: self)
            
            if cnt >= 2 {
                // 如果接收到的数据大于等于2bytes,再判断是哪条指令
                
                switch dataPacket[0] {
                    
                case CLEAProtocol.STATUS_TAG:
                    if waitingResponseFor != nil && (
                        waitingResponseFor![0] == CLEAProtocol.STATUS_TAG ||
                        waitingResponseFor![0] == CLEAProtocol.UPDATE_FW_TAG ||
                        waitingResponseFor![0] == CLEAProtocol.FLASH_FW_BLK_TAG) {
                        
                        // 如果waitingResponseFor不为空,并且是STATUS_TAG、UPDATE_FW_TAG、FLASH_FW_BLK_TAG三种状态中的一种,要将waitingResponseFor置空?
                        waitingResponseFor = nil
                        stopTimeOutTimer()
                    }
                    
                    // TODO: 设置状态,调用CLEADevice的setStatus方法?
                    
                    ret = true
                    
                case CLEAProtocol.READ_TAG:
                    if waitingResponseFor != nil && (
                        waitingResponseFor![0] == CLEAProtocol.READ_TAG ||
                        waitingResponseFor![0] == CLEAProtocol.WRITE_TAG) {
                        
                        // 如果waitingResponseFor不为空,并且是READ_TAG、WRITE_TAG两种状态中的一种,要将waitingResponseFor置空?
                        waitingResponseFor = nil
                        stopTimeOutTimer()
                    }
                    
                    if cnt >= 4 && cnt >= 4 + Int(dataPacket[3]) {
                        
                        // 如果cnt大于等于4,要拿到数据,调用CLEADevice的setRegister方法？有什么用？
                        let page = UInt8(dataPacket[1])
                        let reg  = UInt8(dataPacket[2])
                        let vcnt = Int(dataPacket[3])
                        
                        for i in 0..<vcnt {
                            // TODO: 要调用CLEADevice的setRegister?
                            log(message: "\(page) \(reg) \(vcnt) \(i)", obj: self)
                        }
                        ret = true
                    } else {
                        // 如果cnt数据bytes少于4,表示是不完整的
                        log(message: "Incomplete response", obj: self)
                    }
                    
                default:
                    // 除了STATUS_TAG、READ_TAG，其他都是无效的响应?
                    log(message: "Invalid response: unsupported tag \(dataPacket[0])", obj: self)
                }
            } else {
                // 如果cnt数据bytes少于2,表示是无效的响应
                log(message: "Invalid response: byte cnt \(cnt)", obj: self)
            }
        } else {
            // 如果cnt为nil,表示根本没有传输通道？
            log(message: "No connection channel to EA", obj: self)
        }
        return ret
    }
    
    // MARK: 实作发送数据给硬件的方法
    private func sendRequest() {
        if !dataPackets.isEmpty() {
            // 如果dataPackets不为空(就是有内容咯)(注意前面的感叹号)
            
            if let canSend = clEASession?.outputStream?.hasSpaceAvailable {
                
                if canSend && waitingResponseFor == nil {
                    // waitingResponseFor为空才能发送?
                    
                    // dequeue方法,是删除数组中的第一个元素？
                    if let dataPacket = dataPackets.dequeue() {
                        log(message: ">>>>>  packet tag \(dataPacket[0]) packet sz \(dataPacket.count)", obj: self)
                        
                        // 传输数据
                        let cnt = clEASession!.outputStream!.write(dataPacket, maxLength: dataPacket.count)
                        
                        // 如果发送的数据量和原数据包量(dataPacket)数量不一致,就打印出"只发送了多少bytes"
                        // 这里也可以使用类似下面的断言吧?
                        if cnt != dataPacket.count {
                            log(message: "**** only \(cnt) bytes sent", obj: self)
                        }
                        
                        // "断言": 如果发送量和原有数据包量相等,就打印"数据包可以一次发送完毕"
                        assert(cnt == dataPacket.count, "Code assumes that the whole data packet can be sent in a single write call")
                        
                        if responseExpected(packetTag: dataPacket[0]) {
                            // 如果是预期的指令,将要发送的数据(数据包)赋值给waitingResponseFor(用途是?)
                            // 非预期指令是:BOOT_FW_TAG、CANCEL_TAG，其他都是预期的指令
                            waitingResponseFor = dataPacket
                            
                            // 开启定时器
                            startTimeOutTimer()
                        }
                    } else {
                        // dataPackets中没有数据?
                        log(message: "**** Queue is empty?!", obj: self)
                    }
                } else {
                    // 如果不能发送, 打印出来：是hasSpaceAvailable为false，还是waitingResponseFor不为空
                    var s = "Can't send now, device is busy -"
                    if !canSend {
                        s += " does not accept data! "
                    }
                    if waitingResponseFor != nil {
                        s += " not responded yet!"
                    }
                    log(message: s, obj: self)
                }
            } else {
                // outputStream的hasSpaceAvailable为false
                log(message: "No connected EA", obj: self)
            }
        } else {
            // dataPackets的isEmpty为YES
            log(message: "Queue is empty", obj: self)
        }
    }
    
    // 开启定时器
    private func startTimeOutTimer() {
        toutTimer = Timer.scheduledTimer(timeInterval: CLEAProtocol.TIMEOUT,
                                         target: self,
                                         selector: #selector(CLEAProtocol.retryRequest),
                                         userInfo: nil,
                                         repeats: false)
    }
    
    // 停止定时器
    private func stopTimeOutTimer() {
        if toutTimer != nil && toutTimer!.isValid {
            toutTimer!.invalidate()
        }
        retries = 0
    }
    
    // 重新尝试
    // @objc关键字,表示要暴露给Objectibe-C使用？（这里没有需要和OC混编吧?）
    @objc private func retryRequest() {
        
        objc_sync_enter(self)
        if waitingResponseFor != nil {
            // 如果等待发送的数据不为空
            
            if retries < CLEAProtocol.RETRY_CNT {
                // 如果重试次数少于10次
                log(message: "response timeout for packet with tag \(waitingResponseFor![0]) packet sz \(waitingResponseFor!.count)", obj: self)
                
                dataPackets.queue(data: waitingResponseFor!)
                
                waitingResponseFor = nil
                
                retries += 1
                
                sendRequest()
            } else {
                // TODO: 重新设置状态，调用CLEADevice的setStatus方法?
            }
        } else {
            // waitingResponseFor是空,没有数据需要重新发送?
            log(message: "nothing to retry?!", obj: self)
        }
        objc_sync_exit(self)
    }
}
