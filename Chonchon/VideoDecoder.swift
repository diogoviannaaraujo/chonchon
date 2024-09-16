//
//  VideoDecoder.swift
//  Chonchon
//
//  Created by Diogo Vianna V. Araújo on 13/9/24.
//

import CoreImage
import CoreMedia
import Foundation
import VideoToolbox

class VideoDecoder {
  weak var delegate: VideoDecoderDelegate?

  private var decompressionSession: VTDecompressionSession?
  private var formatDescription: CMVideoFormatDescription?

  func update(formatDescription: CMVideoFormatDescription) {
    if self.formatDescription == nil {
      self.formatDescription = formatDescription
      initializeDecompressionSession()
    }
  }

  func initializeDecompressionSession() {
    guard let formatDescription = formatDescription else { return }

    // Create the decompression session
    var callback = VTDecompressionOutputCallbackRecord(
      decompressionOutputCallback: decompressionOutputCallback,
      decompressionOutputRefCon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    )

    let status = VTDecompressionSessionCreate(
      allocator: nil,
      formatDescription: formatDescription,
      decoderSpecification: nil,
      imageBufferAttributes: nil,
      outputCallback: &callback,
      decompressionSessionOut: &decompressionSession
    )

    if status != noErr {
      print("Error creating decompression session: \(status)")
    }
  }

  func decode(data: Data) {

    guard let decompressionSession = decompressionSession else {
      print("Decompression session not initialized")
      return
    }

    // Create CMBlockBuffer from the data, this is where double free happens
    var blockBuffer: CMBlockBuffer?
    let status = CMBlockBufferCreateWithMemoryBlock(
      allocator: kCFAllocatorDefault,
      memoryBlock: nil,  // Let CMBlockBuffer manage memory
      blockLength: data.count,
      blockAllocator: nil,
      customBlockSource: nil,
      offsetToData: 0,
      dataLength: data.count,
      flags: 0,
      blockBufferOut: &blockBuffer
    )

    if status == kCMBlockBufferNoErr {
      // Copy data into the CMBlockBuffer
      CMBlockBufferReplaceDataBytes(
        with: (data as NSData).bytes,
        blockBuffer: blockBuffer!,
        offsetIntoDestination: 0,
        dataLength: data.count
      )
    }

    // Create CMSampleBuffer from the CMBlockBuffer
    var sampleBuffer: CMSampleBuffer?
    var sampleSizeArray = [data.count]

    let sampleBufferStatus = CMSampleBufferCreateReady(
      allocator: kCFAllocatorDefault,
      dataBuffer: blockBuffer,
      formatDescription: formatDescription,
      sampleCount: 1,
      sampleTimingEntryCount: 0,
      sampleTimingArray: nil,
      sampleSizeEntryCount: 1,
      sampleSizeArray: &sampleSizeArray,
      sampleBufferOut: &sampleBuffer
    )

    if sampleBufferStatus != noErr {
      print("Error creating sample buffer: \(sampleBufferStatus)")
      return
    }

    // Decode the sample buffer
    guard let sampleBufferUnwrapped = sampleBuffer else { return }

    let flags = VTDecodeFrameFlags._EnableAsynchronousDecompression
    var infoFlags = VTDecodeInfoFlags()

    let decodeStatus = VTDecompressionSessionDecodeFrame(
      decompressionSession,
      sampleBuffer: sampleBufferUnwrapped,
      flags: flags,
      frameRefcon: nil,
      infoFlagsOut: &infoFlags
    )

    if decodeStatus != noErr {
      print("Error decoding frame: \(decodeStatus)")
    }
  }

  func invalidate() {
    if let session = decompressionSession {
      VTDecompressionSessionInvalidate(session)
      decompressionSession = nil
    }
  }

  deinit {
    invalidate()
  }
}

private let decompressionOutputCallback: VTDecompressionOutputCallback = {
  (
    decompressionOutputRefCon,
    sourceFrameRefCon,
    status,
    infoFlags,
    imageBuffer,
    presentationTimeStamp,
    presentationDuration
  ) in
  guard status == noErr, let imageBuffer = imageBuffer else {
    print("Decompression error: \(status)")
    return
  }

  let decoder = Unmanaged<VideoDecoder>.fromOpaque(decompressionOutputRefCon!).takeUnretainedValue()
  decoder.displayFrame(imageBuffer)
}

extension VideoDecoder {
  func displayFrame(_ imageBuffer: CVImageBuffer) {
    CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)

    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
    let context = CIContext()

    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
      DispatchQueue.main.async {
        self.delegate?.videoDecoder(self, didDecodeFrame: cgImage)
      }
    }

    CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
  }
}

protocol VideoDecoderDelegate: AnyObject {
  func videoDecoder(_ decoder: VideoDecoder, didDecodeFrame image: CGImage)
}
