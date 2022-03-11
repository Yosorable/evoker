import { invoke, subscribe } from "../../bridge"
import { dispatch, on, off } from "@nzoth/shared"

let audioId = 0

const enum AudioOperateMethods {
  play = "play",
  pause = "pause",
  stop = "stop",
  seek = "seek",
  destroy = "destroy",
  setVolume = "setVolume"
}

class InnerAudioContext {
  private _src: string = ""
  private readonly id: number = audioId++

  startTime: number = 0
  autoplay: boolean = false
  loop: boolean = false
  private _volume: number = 1
  playbackRate: number = 1
  readonly duration: number = 0
  readonly currentTime: number = 0
  readonly paused: boolean = false
  readonly buffered: number = 0

  private onPlayCallback?: () => void
  private onCanplayCallback?: () => void

  private removaAllListener

  constructor() {
    const { onPlay, onEnded, removaAllListener } = useAudio(this.id)

    onPlay(() => {
      typeof this.onPlayCallback === "function" && this.onPlayCallback()
    })

    onEnded(() => {
      if (this.loop) {
        this.seek(0)
        this.play()
      }
      typeof this.onPlayCallback === "function" && this.onPlayCallback()
    })
    this.removaAllListener = removaAllListener
  }

  get src() {
    return this._src
  }

  set src(newValue) {
    this._src = newValue
    this.autoplay && this.play()
  }

  get volume() {
    return this._volume
  }

  set volume(newValue) {
    this._volume = newValue
    this.src &&
      this.operate(AudioOperateMethods.setVolume, { volume: newValue })
  }

  private operate(method: AudioOperateMethods, data: Record<string, any> = {}) {
    invoke("operateInnerAudioContext", {
      audioId: this.id,
      method,
      data
    })
  }

  play() {
    if (this.src === "") {
      console.warn("[NZoth] InnerAudioContext src is empty")
      return
    }
    this.operate(AudioOperateMethods.play, {
      src: this.src,
      startTime: this.startTime,
      volume: this.volume,
      playbackRate: this.playbackRate
    })
  }

  pause() {
    this.operate(AudioOperateMethods.pause)
  }

  stop() {
    this.operate(AudioOperateMethods.stop)
  }

  seek(position: number) {
    this.operate(AudioOperateMethods.seek, { position })
  }

  destroy() {
    this.operate(AudioOperateMethods.destroy)
    this.removaAllListener()
  }

  onCanplay(callback: () => void) {
    this.onCanplayCallback = callback
  }

  offCanplay() {
    this.onCanplayCallback = undefined
  }

  onPlay(callback: () => void) {
    this.onPlayCallback = callback
  }

  offPlay() {
    this.onPlayCallback = undefined
  }

  onPause(callback: () => void) {}

  offPause(callback: () => void) {}

  onStop(callback: () => void) {}

  offStop(callback: () => void) {}

  onEdned(callback: () => void) {}

  offEnded(callback: () => void) {}

  onTimeUpdate(callback: () => void) {}

  offTimeUpdate(callback: () => void) {}

  onError(callback: () => void) {}

  offError(callback: () => void) {}

  onWaiting(callback: () => void) {}

  offWaiting(callback: () => void) {}

  onSeeking(callback: () => void) {}

  offSeeking(callback: () => void) {}

  onSeeked(callback: () => void) {}

  offSeeked(callback: () => void) {}
}

export function createInnerAudioContext() {
  return new InnerAudioContext()
}

enum AudioSubscribeKeys {
  APP_SERVICE_AUDIO_CONTEXT_ON_PLAY = "APP_SERVICE_AUDIO_CONTEXT_ON_PLAY",
  APP_SERVICE_AUDIO_CONTEXT_ON_ENDED = "APP_SERVICE_AUDIO_CONTEXT_ON_ENDED"
}

Object.values(AudioSubscribeKeys).forEach(key => {
  subscribe(key, message => {
    dispatch(key, message)
  })
})

function useAudio(audioId: number) {
  const ids = new Map<string, number>()

  function createListener(
    key: AudioSubscribeKeys,
    callback: (data: any) => void
  ) {
    const id = on(key, data => {
      if (data.audioId === audioId) {
        callback(data)
      }
    })
    ids.set(key, id)
    return id
  }

  function onPlay(callback: () => void) {
    return createListener(
      AudioSubscribeKeys.APP_SERVICE_AUDIO_CONTEXT_ON_PLAY,
      callback
    )
  }

  function onEnded(callback: () => void) {
    return createListener(
      AudioSubscribeKeys.APP_SERVICE_AUDIO_CONTEXT_ON_ENDED,
      callback
    )
  }

  function removaAllListener() {
    ids.forEach((value, key) => {
      off(key, value)
    })
  }

  return {
    onPlay,
    onEnded,
    removaAllListener
  }
}
