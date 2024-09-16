//
//  ClientView.swift
//  Chonchon
//
//  Created by Diogo Vianna V. Araújo on 13/9/24.
//

import Foundation
import SwiftUI

struct ClientView: View {
  @ObservedObject var viewModel = ClientViewModel()

  var body: some View {
    VStack {
      if let image = viewModel.currentFrame {
        CursorTrackingImage(
          image: image,
          onCursorMove: { position in
            viewModel.handleCursorMove(pos: position)
          },
          onCursorButtonUp: { position, button in
              viewModel.handleCursorButtonUp(pos: position, button: button)
          },
          onCursorButtonDown: { position, button in
              viewModel.handleCursorButtonDown(pos: position, button: button)
          },
          onCursorDragged: { position, button in
              viewModel.handleCursorMove(pos: position)
          }
        ).scaledToFit()
      } else {
        // Show a placeholder when there's no frame
        Text("Waiting for screen data")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }
}
