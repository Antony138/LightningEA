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
    // 请求硬件状态?
    static let STATUS_TAG: UInt8       = 1
    // 请求固件升级
    static let UPDATE_FW_TAG: UInt8    = 2
    // 烧录固件
    static let FLASH_FW_BLK_TAG: UInt8 = 3
    // 启动固件升级?
    static let BOOT_FW_TAG:UInt8       = 4
    // 取消固件升级
    static let CANCEL_TAG: UInt8       = 5
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
    
    // MARK:- 私有部分
    // 协议字符串
    private let eaProtocolString: String = ""
    // EASession对象
    private var clEASession: EASession?
    // 这是一个类实例?
    private var dataPackets = Queue<[UInt8]>()
    // 数组,装什么数据的？
    private var waitingResponseFor: [UInt8]?
    // 重试次数?
    private var retries = 0
    // 超时定时器?
    private var toutTimer: Timer?
    
    // 停止定时器
    private func stopTimeOutTimer() {
        if toutTimer != nil && toutTimer!.isValid {
            toutTimer!.invalidate()
        }
        retries = 0
    }
    
    
    
    
    
    
    
    
    

}
