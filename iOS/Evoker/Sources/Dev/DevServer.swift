//
//  DevServer.swift
//
//  Copyright (c) Evoker. All rights reserved. (https://evokerdev.com)
//
//  This source code is licensed under The MIT license.
//

import Foundation
import Zip

class DevServer: WebSocket {
    
    struct AppUpdateOptions: Decodable {
        let appId: String
        var files: [String]
        let version: String
        let launchOptions: LaunchOptions?
        
        struct LaunchOptions: Decodable {
            let page: String?
        }
    }
    
    private var attemptCount = 0
    
    private let lock = Lock()
    
    private var needUpdateApps: [String: AppUpdateOptions] = [:]
    
    private var heartTimer: Timer?
    
    public init(host: String = "", port: UInt16 = 5173) {
        var ip = host
        if ip.isEmpty,
           let ipFile = Bundle.main.url(forResource: "IP", withExtension: "txt"),
           let _ip = try? String(contentsOf: ipFile).split(separator: "\n").first {
            ip = String(_ip)
        }
        if ip.isEmpty {
            ip = "127.0.0.1"
        }
        super.init(url: URL(string: "ws://\(ip):\(port)")!)
    }
    
    override func appWillEnterForeground() {
        super.appWillEnterForeground()
        
        attemptCount = 0
        reconnect()
    }
    
    override func onOpen() {
        Logger.debug("dev server: connected")
        
        attemptCount = 0
        
        heartTimer?.invalidate()
        heartTimer = nil
        
        heartTimer = Timer(timeInterval: 60,
                           target: self,
                           selector: #selector(self.sendHeart),
                           userInfo: nil,
                           repeats: true)
        RunLoop.main.add(heartTimer!, forMode: .common)
    }
    
    override func onError(_ error: Error) {
        NotifyType.fail("connect dev server fail, please check network, error: \(error.localizedDescription)").show()
    }
    
    override func onClose(_ code: Int, reason: String?) {
        Logger.debug("dev server disconnected")
        
        heartTimer?.invalidate()
        heartTimer = nil
        
        reconnect()
    }
    
    override func onRecv(_ data: Data) {
        guard data.count > 64 else { return }
        
        let headerData = data.subdata(in: 0..<64)
        let bodyData = data.subdata(in: 64..<data.count)
        guard let headerString = String(data: headerData, encoding: .utf8)?
                .replacingOccurrences(of: "\0", with: "") else { return }
        
        switch headerString {
        case "--CHECKVERSION--":
            checkVersion(bodyData)
        case "--UPDATE--":
            update(bodyData)
        default:
            let header = headerString.components(separatedBy: "---")
            recvFile(bodyData, header: header)
        }
    }
    
    override func connect() {
        guard Engine.shared.config.dev.useDevServer else { return }
        super.connect()
    }
    
    override func reconnect() {
        if attemptCount + 1 > 10 {
            return
        }
        
        let delay = TimeInterval(attemptCount) * 5.0
        attemptCount += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            super.reconnect()
        }
    }
    
    @objc
    func sendHeart() {
        try? send("ping")
    }
}

private extension DevServer {
    
    func checkVersion(_ body: Data) {
        guard let message = body.toDict(),
              let appId = message["appId"] as? String else { return }
        let version = PackageManager.shared.localAppVersion(appId: appId, envVersion: .develop)
        if let msg = ["event": "version", "data": ["version": version]].toJSONString() {
            try? send(msg)
        }
    }
    
    func update(_ body: Data) {
        guard let options: AppUpdateOptions = body.toModel() else { return }
        PackageManager.shared.setLocalAppVersion(appId: options.appId,
                                                   envVersion: .develop,
                                                   version: options.version)
        lock.lock()
        needUpdateApps[options.appId] = options
        lock.unlock()
    }
    
    func recvFile(_ body: Data, header: [String]) {
        guard header.count >= 3 else { return }
        
        let appId = header[0]
        let version = header[1]
        let package = header[2]
        
        lock.lock()
        guard var options = needUpdateApps[appId], options.version == version else {
            lock.unlock()
            return
        }
        
        var packageURL: URL
        if package == "sdk" {
            packageURL = FilePath.jsSDK(version: "dev")
        } else if package == "app" {
            packageURL = FilePath.appDist(appId: appId, envVersion: .develop)
        } else {
            lock.unlock()
            return
        }

        do {
            let (_, filePath) =  FilePath.generateTmpEKFilePath(ext: "zip")
            try FilePath.createDirectory(at: filePath.deletingLastPathComponent())
            
            if FileManager.default.createFile(atPath: filePath.path, contents: body, attributes: nil) {
                try FilePath.createDirectory(at: packageURL)
                try Zip.unzipFile(filePath, destination: packageURL, overwrite: true, password: nil, progress: nil)
                
                if let index = options.files.firstIndex(of: package) {
                    options.files.remove(at: index)
                    needUpdateApps[appId] = options
                }
                
                if options.files.isEmpty {
                    DispatchQueue.main.async {
                        NotifyType.success("DEV_RELOAD").show()
                        self.needUpdateApps[appId] = nil
                        var info: [String: Any] = ["appId": appId]
                        if let launchOptions = options.launchOptions {
                            info["launchOptions"] = launchOptions
                        }
                        NotificationCenter.default.post(name: DevServer.didUpdateNotification, object: info)
                        self.lock.unlock()
                    }
                } else {
                    lock.unlock()
                }
            }
        } catch {
            lock.unlock()
            DispatchQueue.main.async {
                NotifyType.fail(error.localizedDescription).show()
            }
        }
    }
}

extension DevServer {
    
    static let didUpdateNotification = Notification.Name("EvokerDevServerDidUpdateNotification")
}
