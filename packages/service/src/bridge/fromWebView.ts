import { InnerJSBridge } from "./bridge"
import type { InvokeCallback } from "@nzoth/bridge"
import { navigateTo, navigateBack, redirectTo, reLaunch, switchTab } from "./api/route"
import { getCurrentWebViewId } from "../app"

const enum Events {
  INVOKE_APP_SERVICE = "invokeAppServiceMethod",
  CALLBACK_APP_SERVICE = "callbackAppServiceMethod",
  INVOKE_WEB_VIEW = "invokeWebViewMethod",
  CALLBACL_WEB_VIEW = "callbackWebViewMethod"
}

let callbackId = 0

const callbacks = new Map<number, InvokeCallback<any>>()

export function invokeWebViewMethod<T = unknown>(
  event: string,
  params: any = {},
  callback?: InvokeCallback<T>
) {
  const cbId = callbackId++
  InnerJSBridge.publish(
    Events.INVOKE_WEB_VIEW,
    {
      event,
      params,
      callbackId: cbId
    },
    getCurrentWebViewId()
  )
  if (callback) {
    callbacks.set(cbId, callback)
  }
}

InnerJSBridge.subscribe<{ callbackId: number; result: any }>(Events.CALLBACL_WEB_VIEW, message => {
  const { callbackId, result } = message
  const callback = callbacks.get(callbackId)
  if (callback) {
    callback(result)
    callbacks.delete(callbackId)
  }
})

const methods: Record<string, Function> = {
  navigateTo,
  redirectTo,
  switchTab,
  reLaunch,
  navigateBack
}

InnerJSBridge.subscribe<{ callbackId: number; event: string; params: any[] }>(
  Events.INVOKE_APP_SERVICE,
  (message, webViewId) => {
    const { callbackId, event, params } = message
    const method = methods[event]
    if (method) {
      method
        .call(null, params || [])
        .then((result: any) => {
          InnerJSBridge.publish(
            Events.CALLBACK_APP_SERVICE,
            {
              result: { errMsg: "", data: result },
              callbackId
            },
            webViewId
          )
        })
        .catch((error: string) => {
          InnerJSBridge.publish(
            Events.CALLBACK_APP_SERVICE,
            {
              result: { errMsg: error, data: {} },
              callbackId
            },
            webViewId
          )
        })
    }
  }
)
