import { onUnmounted } from "vue"
import { NZJSBridge } from "../../bridge"
import { dispatch, on, off } from "@nzoth/shared"

enum CameraSubscribeKeys {
  WEBVIEW_CAMERA_INIT_DONE = "WEBVIEW_CAMERA_INIT_DONE",
  WEBVIEW_CAMERA_SCAN_CODE = "WEBVIEW_CAMERA_SCAN_CODE"
}

Object.values(CameraSubscribeKeys).forEach(key => {
  NZJSBridge.subscribe(key, message => {
    dispatch(key, message)
  })
})

export default function useCamera(cameraId: number) {
  const ids = new Map<string, number>()

  function createListener(
    key: CameraSubscribeKeys,
    callback: (data: any) => void
  ) {
    const id = on(key, data => {
      if (data.cameraId === cameraId) {
        callback(data)
      }
    })
    ids.set(key, id)
    return id
  }

  function onInit(callback: (data: { maxZoom: number }) => void) {
    return createListener(
      CameraSubscribeKeys.WEBVIEW_CAMERA_INIT_DONE,
      callback
    )
  }

  function onScanCode(callback: (data: { value: string }) => void) {
    return createListener(
      CameraSubscribeKeys.WEBVIEW_CAMERA_SCAN_CODE,
      callback
    )
  }

  function removaAllListener() {
    ids.forEach((value, key) => {
      off(key, value)
    })
  }

  onUnmounted(() => {
    removaAllListener()
  })

  return {
    onInit,
    onScanCode,
    removaAllListener
  }
}
