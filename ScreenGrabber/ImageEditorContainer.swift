//
//  ImageEditorContainer.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 11/14/25.
//

import SwiftUI

/// Container for ImageEditorView that prevents Swift metadata crashes
/// by providing a stable initialization context for sheet presentations.
struct ImageEditorContainer: View {
    let imageURL: URL
    
    var body: some View {
        ImageEditorView(imageURL: imageURL)
            .frame(minWidth: 1200, idealWidth: 1400, maxWidth: .infinity,
                   minHeight: 800, idealHeight: 900, maxHeight: .infinity)
    }
}
