//
//  VideoReceiver.swift
//  Chonchon
//
//  Created by Diogo Vianna V. Araújo on 15/9/24.
//

import CoreMedia
import Foundation
import Network

class VideoReceiver {
  weak var delegate: VideoReceiverDelegate?

  private let queue: DispatchQueue = DispatchQueue(label: "videoReceiverQueue")
  private let port: UInt16 = 5004
  private var listener: NWListener!
  private var frameSequenceCurrent: UInt32 = 0
  private var fragmentBuffer: [UInt16: Data] = [:]

  init() {
    startListening()
  }

  private func startListening() {
    do {
      listener = try NWListener(using: .udp, on: NWEndpoint.Port(rawValue: port)!)
      print("Listening on port \(port)")
    } catch {
      print("Failed to create listener: \(error)")
      return
    }

    listener.newConnectionHandler = { [weak self] connection in
      self?.handleConnection(connection)
    }
    listener.start(queue: queue)
  }

  private func handleConnection(_ connection: NWConnection) {
    print("Connection received")
    connection.start(queue: queue)
    self.receive(on: connection)
  }

  private func receive(on connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) {
      [weak self] data, _, isComplete, error in
      if let data = data {
        guard data.count >= 10 else {
          print("Error: Packet too short")
          return
        }
        if data[1] == 0x01 {
          self?.processFramePacket(data)
        }
        if data[1] == 0x02 {
          self?.processParametersPacket(data)
        }

      }
      if error == nil {
        self?.receive(on: connection)
      } else if let error = error {
        print("Connection error: \(error)")
      }
    }
  }

  private func processFramePacket(_ data: Data) {
    let fragmentSequenceTotal = UInt16(data[4]) << 8 | UInt16(data[5])
    let frameSequenceNumber =
      UInt32(data[6]) << 24 | UInt32(data[7]) << 16 | UInt32(data[8]) << 8 | UInt32(data[9])
    let payload = data.subdata(in: 10..<data.count)

    // check for old frames
    if frameSequenceNumber < frameSequenceCurrent {
      print("Error: Received old frame, discarting")
      return
    }

    // check for new frames and cleanup old data
    if frameSequenceNumber > frameSequenceCurrent {
      fragmentBuffer = [:]
      frameSequenceCurrent = frameSequenceNumber
    }

    // Check if fragmented data
    if fragmentSequenceTotal == 0 {
      //not fragmented, send payload to delegate
      self.delegate?.videoReceiver(self, didReceiveEncodedFrame: payload)
      frameSequenceCurrent = frameSequenceNumber + 1
    } else {
      //fragmented, deal with it
      handleFragmentationUnit(data: data)
    }
  }

  func processParametersPacket(_ data: Data) {
    print("receving format description")
    let payload = data.subdata(in: 10..<data.count)
    if let formatDescription = createFormatDescription(from: payload) {
      self.delegate?.videoReceiver(self, didReceiveFormatDescription: formatDescription)
    }
  }

  private func handleFragmentationUnit(data: Data) {
    let fragmentSequenceNumber = UInt16(data[2]) << 8 | UInt16(data[3])
    let fragmentSequenceTotal = UInt16(data[4]) << 8 | UInt16(data[5])
    let frameSequenceNumber =
      UInt32(data[6]) << 24 | UInt32(data[7]) << 16 | UInt32(data[8]) << 8 | UInt32(data[9])
    let payload = data.subdata(in: 10..<data.count)

    if fragmentBuffer[fragmentSequenceNumber] == nil {
      fragmentBuffer[fragmentSequenceNumber] = payload
    }

    if fragmentBuffer.count == fragmentSequenceTotal {
      var completeFrame = Data()
      for fragmentIndex in 0..<fragmentSequenceTotal {
        if let fragment = fragmentBuffer[fragmentIndex] {
          completeFrame.append(fragment)
        } else {
          print("Error: Missing fragment \(fragmentIndex)")
          return
        }
      }
      print("Reconstructed full frame")
      self.delegate?.videoReceiver(self, didReceiveEncodedFrame: completeFrame)
      frameSequenceCurrent = frameSequenceNumber + 1
      fragmentBuffer = [:]
    }
  }
}

protocol VideoReceiverDelegate: AnyObject {
  func videoReceiver(_ receiver: VideoReceiver, didReceiveEncodedFrame data: Data)
  func videoReceiver(
    _ receiver: VideoReceiver,
    didReceiveFormatDescription formatDescription: CMVideoFormatDescription)
}

private struct ParameterSet: Codable {
  let parameterSetCount: Int
  let parameterDataBase64: String
  let parameterDataSizeInBytes: Int
}

private func createFormatDescription(from jsonData: Data) -> CMVideoFormatDescription? {
  // Step 1: Decode the JSON data into an array of ParameterSet
  let decoder = JSONDecoder()
  var parameterSets: [ParameterSet]

  do {
    parameterSets = try decoder.decode([ParameterSet].self, from: jsonData)
  } catch {
    print("Failed to decode JSON: \(error)")
    return nil
  }

  // Step 2: Convert the Base64-encoded data back to raw data
  var parameterSetPointers: [UnsafePointer<UInt8>] = []
  var parameterSetSizes: [Int] = []

  for paramSet in parameterSets {
    if let data = Data(base64Encoded: paramSet.parameterDataBase64) {
      // Allocate mutable memory and copy the bytes
      let mutableBytesPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
      data.copyBytes(to: mutableBytesPointer, count: data.count)

      // Convert to UnsafePointer<UInt8> and store it
      parameterSetPointers.append(UnsafePointer(mutableBytesPointer))
      parameterSetSizes.append(data.count)
    } else {
      print("Failed to decode Base64 string")
      return nil
    }
  }

  // Step 3: Create HEVC format description from the parameter sets
  var formatDescription: CMVideoFormatDescription?

  let status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(
    allocator: kCFAllocatorDefault,
    parameterSetCount: parameterSets.count,
    parameterSetPointers: &parameterSetPointers,
    parameterSetSizes: &parameterSetSizes,
    nalUnitHeaderLength: 4,  // Typically, NAL unit header length is 4 bytes
    extensions: nil,
    formatDescriptionOut: &formatDescription
  )

  // Step 4: Check if format description was successfully created
  if status != noErr {
    print("Failed to create format description: \(status)")
    return nil
  }

  // Clean up allocated memory
  for pointer in parameterSetPointers {
    pointer.deallocate()
  }

  return formatDescription
}
