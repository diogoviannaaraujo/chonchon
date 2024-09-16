//
//  EventSender.swift
//  Chonchon
//
//  Created by Diogo Vianna V. Araújo on 15/9/24.
//

import Foundation
import Network

class EventSender {
  private let connection: NWConnection
  private let queue = DispatchQueue(label: "eventSenderQueue")
  private var eventSequenceNumber: UInt32 = 0

  init(port: UInt16 = 5005) {
    let params = NWParameters.udp
    self.connection = NWConnection(
      host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: params)
    self.connection.start(queue: queue)
  }

  private func createCursorPacket(
    type: UInt8, position: CGPoint, extraData1: UInt8, extraData2: UInt8
  ) -> Data {
    let cursorX = UInt16(position.x * 65535)
    let cursorY = UInt16(position.y * 65535)

    var header = Data(count: 12)
    header[0] = 0x01  // Version 1
    header[1] = type
    header[2] = UInt8(eventSequenceNumber >> 24)
    header[3] = UInt8((eventSequenceNumber >> 16) & 0xFF)
    header[4] = UInt8((eventSequenceNumber >> 8) & 0xFF)
    header[5] = UInt8(eventSequenceNumber & 0xFF)
    header[6] = UInt8(cursorX >> 8)
    header[7] = UInt8(cursorX & 0xFF)
    header[8] = UInt8(cursorY >> 8)
    header[9] = UInt8(cursorY & 0xFF)
    header[10] = extraData1
    header[11] = extraData2

    return header
  }

  func sendCursorMovePacket(pos: CGPoint) {
    let packet = createCursorPacket(type: 0xA1, position: pos, extraData1: 0x00, extraData2: 0x00)
    send(packet)
  }

  func sendCursorButtonUpPacket(pos: CGPoint, button: Int) {
    let packet = createCursorPacket(type: 0xA2, position: pos, extraData1: UInt8(button), extraData2: 0x00)
    send(packet)
  }

  func sendCursorButtonDownPacket(pos: CGPoint, button: Int) {
    let packet = createCursorPacket(type: 0xA3, position: pos, extraData1: UInt8(button), extraData2: 0x00)
    send(packet)
  }

  private func send(_ packet: Data) {
    print("sending event")
    connection.send(
      content: packet,
      completion: .contentProcessed { error in
        if let error = error {
          print("Send error: \(error)")
        }
      })
  }
}
