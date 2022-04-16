//
//  NZAuthAPI.swift
//
//  Copyright (c) NZoth. All rights reserved. (https://nzothdev.com)
//  
//  This source code is licensed under The MIT license.
//

import Foundation

enum NZAuthAPI: String, NZBuiltInAPI {
   
    case openAuthorizationView
    case getSetting
    case getAuthorize
    case setAuthorize
    case openSetting
    
    func onInvoke(appService: NZAppService, bridge: NZJSBridge, args: NZJSBridge.InvokeArgs) {
        DispatchQueue.main.async {
            switch self {
            case .openAuthorizationView:
                self.openAuthorizationView(appService: appService, bridge: bridge, args: args)
            case .getSetting:
                self.getSetting(appService: appService, bridge: bridge, args: args)
            case .getAuthorize:
                self.getAuthorize(appService: appService, bridge: bridge, args: args)
            case .setAuthorize:
                self.setAuthorize(appService: appService, bridge: bridge, args: args)
            case .openSetting:
                self.openSetting(appService: appService, bridge: bridge, args: args)
            }
        }
    }
            
    private func openAuthorizationView(appService: NZAppService, bridge: NZJSBridge, args: NZJSBridge.InvokeArgs) {
        guard let viewController = appService.rootViewController else {
            let error = NZError.bridgeFailed(reason: .visibleViewControllerNotFound)
            bridge.invokeCallbackFail(args: args, error: error)
            return
        }
        
        guard let params: NZAuthorizationView.Params = args.paramsString.toModel() else {
            let error = NZError.bridgeFailed(reason: .jsonParseFailed)
            bridge.invokeCallbackFail(args: args, error: error)
            return
        }
        
        let authView = NZAuthorizationView(params: params)
        let cover = NZCoverView(contentView: authView)
        authView.completionHandler = { authorized in
            NZEngine.shared.shouldInteractivePopGesture = true
            cover.hide()
            bridge.invokeCallbackSuccess(args: args, result: ["authorized": authorized])
        }
        cover.show(to: viewController.view)
        NZEngine.shared.shouldInteractivePopGesture = false
    }
    
    private func getSetting(appService: NZAppService, bridge: NZJSBridge, args: NZJSBridge.InvokeArgs) {
        let (authSetting, error) = appService.storage.getAllAuthorization()
        if let error = error {
            bridge.invokeCallbackFail(args: args, error: error)
        } else {
            bridge.invokeCallbackSuccess(args: args, result: ["authSetting": authSetting])
        }
    }
    
    private func getAuthorize(appService: NZAppService, bridge: NZJSBridge, args: NZJSBridge.InvokeArgs) {
        struct Params: Decodable {
            let scope: String
        }
        
        guard let params: Params = args.paramsString.toModel() else {
            let error = NZError.bridgeFailed(reason: .jsonParseFailed)
            bridge.invokeCallbackFail(args: args, error: error)
            return
        }
        
        let (authorized, error) = appService.storage.getAuthorization(params.scope)
        if let error = error {
            bridge.invokeCallbackFail(args: args, error: error)
        } else {
            bridge.invokeCallbackSuccess(args: args, result: ["status": authorized])
        }
    }
    
    private func setAuthorize(appService: NZAppService, bridge: NZJSBridge, args: NZJSBridge.InvokeArgs) {
        struct Params: Decodable {
            let scope: String
            let authorized: Bool
        }
        
        guard let params: Params = args.paramsString.toModel() else {
            let error = NZError.bridgeFailed(reason: .jsonParseFailed)
            bridge.invokeCallbackFail(args: args, error: error)
            return
        }
        
        if let error = appService.storage.setAuthorization(params.scope, authorized: params.authorized) {
            bridge.invokeCallbackFail(args: args, error: error)
        } else {
            bridge.invokeCallbackSuccess(args: args)
        }
    }
    
    private func openSetting(appService: NZAppService, bridge: NZJSBridge, args: NZJSBridge.InvokeArgs) {
        let viewModel = NZSettingViewModel(appService: appService)
        viewModel.popViewControllerHandler = {
            let (authSetting, error) = appService.storage.getAllAuthorization()
            if let error = error {
                bridge.invokeCallbackFail(args: args, error: error)
            } else {
                bridge.invokeCallbackSuccess(args: args, result: ["authSetting": authSetting])
            }
        }
        appService.rootViewController?.pushViewController(viewModel.generateViewController(), animated: true)
    }
}
