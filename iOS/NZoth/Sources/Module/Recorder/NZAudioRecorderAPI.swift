//
//  NZAudioRecorderAPI.swift
//
//  Copyright (c) NZoth. All rights reserved. (https://nzothdev.com)
//  
//  This source code is licensed under The MIT license.
//

import Foundation

enum NZAudioRecorderAPI: String, NZBuiltInAPI {
    
    case operateAudioRecorder
    
    func onInvoke(appService: NZAppService, bridge: NZJSBridge, args: NZJSBridge.InvokeArgs) {
        DispatchQueue.main.async {
            switch self {
            case .operateAudioRecorder:
                self.operateAudioRecorder(appService: appService, bridge: bridge, args: args)
            }
        }
    }
    
    private func operateAudioRecorder(appService: NZAppService, bridge: NZJSBridge, args: NZJSBridge.InvokeArgs) {
        struct Params: Decodable {
            let method: Method
            var startData: NZAudioRecorder.Params?
            
            enum Method: String, Decodable {
                case start
                case stop
                case pause
                case resume
            }
        }
        
        guard let module: NZAudioRecorderModule = appService.getModule() else {
            let error = NZError.bridgeFailed(reason: .moduleNotFound(NZAudioRecorderModule.name))
            bridge.invokeCallbackFail(args: args, error: error)
            return
        }
        
        guard let params: Params = args.paramsString.toModel() else {
            let error = NZError.bridgeFailed(reason: .jsonParseFailed)
            bridge.invokeCallbackFail(args: args, error: error)
            return
        }
        
        switch params.method {
        case .start:
            if let params = params.startData {
                module.recorder.startRecord(params: params)
            } else {
                bridge.subscribeHandler(method: NZAudioRecorderModule.onErrorSubscribeKey,
                                        data: ["error": "start options invalid"])
            }
        case .stop:
            module.recorder.stop()
        case .pause:
            module.recorder.pause()
        case .resume:
            module.recorder.resume()
        }
    }
}
