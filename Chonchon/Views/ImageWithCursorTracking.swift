import Cocoa
//
//  CursorTrackingImage.swift
//  Chonchon
//
//  Created by Diogo Vianna V. Araújo on 15/9/24.
//
import SwiftUI

struct CursorTrackingImage: NSViewRepresentable {
  let image: CGImage
  var onCursorMove: ((CGPoint) -> Void)?  // Callback for cursor position (is inside, position)
  var onCursorButtonUp: ((CGPoint, CGMouseButton) -> Void)?  // Callback for mouse clicks (is clicked, position)
  var onCursorButtonDown: ((CGPoint, CGMouseButton) -> Void)?
  var onCursorDragged: ((CGPoint, CGMouseButton) -> Void)?

  func makeNSView(context: Context) -> NSImageViewWithTracking {
    let imageView = NSImageViewWithTracking()
    imageView.image = NSImage(cgImage: image, size: CGSize(width: 160, height: 100))  // Set the image
    imageView.onCursorMove = onCursorMove  // Set the cursor movement callback
    imageView.onCursorButtonUp = onCursorButtonUp
    imageView.onCursorButtonDown = onCursorButtonDown
    imageView.onCursorDragged = onCursorDragged
    imageView.imageScaling = .scaleProportionallyUpOrDown
    return imageView
  }

  func updateNSView(_ nsView: NSImageViewWithTracking, context: Context) {
    nsView.image = NSImage(cgImage: image, size: CGSize(width: 160, height: 100))
    nsView.onCursorMove = onCursorMove
    nsView.onCursorButtonUp = onCursorButtonUp
    nsView.onCursorButtonUp = onCursorButtonUp
    nsView.onCursorDragged = onCursorDragged
    nsView.imageScaling = .scaleProportionallyUpOrDown
  }
}

class NSImageViewWithTracking: NSImageView {
  var onCursorMove: ((CGPoint) -> Void)?
  var onCursorButtonUp: ((CGPoint, CGMouseButton) -> Void)?  // Callback for mouse release events
  var onCursorButtonDown: ((CGPoint, CGMouseButton) -> Void)?  // Callback for mouse click events
  var onCursorDragged: ((CGPoint, CGMouseButton) -> Void)?

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    self.trackingAreas.forEach { self.removeTrackingArea($0) }  // Remove existing tracking areas

    let options: NSTrackingArea.Options = [
      .mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect,
    ]
    let trackingArea = NSTrackingArea(
      rect: self.bounds, options: options, owner: self, userInfo: nil)
    self.addTrackingArea(trackingArea)  // Add a new tracking area to track mouse movements and clicks
  }

  private func getCursorPosition(_ event: NSEvent) -> CGPoint {
    let cursorWinPos = convert(event.locationInWindow, from: nil)
    let cursorOnImage = CGPoint(x: cursorWinPos.x / frame.width, y: cursorWinPos.y / frame.height)
    return cursorOnImage
  }

  override func mouseMoved(with event: NSEvent) {
    super.mouseMoved(with: event)
    onCursorMove?(getCursorPosition(event))
  }

  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
    onCursorButtonDown?(
      getCursorPosition(event), CGMouseButton(rawValue: UInt32(event.buttonNumber))!)
  }

  override func rightMouseDown(with event: NSEvent) {
    super.rightMouseDown(with: event)
    onCursorButtonDown?(
      getCursorPosition(event), CGMouseButton(rawValue: UInt32(event.buttonNumber))!)
  }

  override func mouseUp(with event: NSEvent) {
    super.mouseUp(with: event)
    onCursorButtonUp?(
      getCursorPosition(event), CGMouseButton(rawValue: UInt32(event.buttonNumber))!)
  }

  override func rightMouseUp(with event: NSEvent) {
    super.rightMouseUp(with: event)
    onCursorButtonUp?(
      getCursorPosition(event), CGMouseButton(rawValue: UInt32(event.buttonNumber))!)
  }

  override func mouseDragged(with event: NSEvent) {
    super.mouseDragged(with: event)
    onCursorDragged?(getCursorPosition(event), CGMouseButton(rawValue: UInt32(event.buttonNumber))!)
  }
}
