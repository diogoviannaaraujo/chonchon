//
//  ClientViewModel.swift
//  Chonchon
//
//  Created by Diogo Vianna V. Araújo on 14/9/24.
//

import CoreMedia
import CoreVideo
import Foundation
import SwiftUI

class ClientViewModel: ObservableObject {
  @Published var currentFrame: CGImage?

  let videoReceiver = VideoReceiver()
  let videoDecoder = VideoDecoder()
  let eventSender = EventSender()

  init() {
    videoReceiver.delegate = self
    videoDecoder.delegate = self
  }

  func handleCursorMove(pos: CGPoint) {
    eventSender.sendCursorMovePacket(pos: pos)
  }
  func handleCursorButtonUp(pos: CGPoint, button: CGMouseButton) {
      eventSender.sendCursorButtonUpPacket(pos: pos, button: Int(button.rawValue))
  }
  func handleCursorButtonDown(pos: CGPoint, button: CGMouseButton) {
      eventSender.sendCursorButtonDownPacket(pos: pos, button: Int(button.rawValue))
  }
}

extension ClientViewModel: VideoReceiverDelegate {
  func videoReceiver(_ receiver: VideoReceiver, didReceiveEncodedFrame data: Data) {
    videoDecoder.decode(data: data)
  }

  func videoReceiver(
    _ receiver: VideoReceiver,
    didReceiveFormatDescription formatDescription: CMVideoFormatDescription
  ) {
    videoDecoder.update(formatDescription: formatDescription)
  }

}

extension ClientViewModel: VideoDecoderDelegate {
  func videoDecoder(_ decoder: VideoDecoder, didDecodeFrame image: CGImage) {
    print("Showing new frame")
    DispatchQueue.main.async {
      self.currentFrame = image
    }
  }
}
