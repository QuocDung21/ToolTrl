import SwiftUI
#if canImport(PencilKit) && canImport(UIKit)
import PencilKit
import UIKit

public struct PencilKitCanvasView: UIViewRepresentable {
    @Binding public var canvasView: PKCanvasView
    public let toolPicker: PKToolPicker
    public var isToolPickerVisible: Bool
    public var allowFingerDrawing: Bool
    public var onDrawingChanged: (() -> Void)? = nil
    
    public init(
        canvasView: Binding<PKCanvasView>,
        toolPicker: PKToolPicker,
        isToolPickerVisible: Bool = true,
        allowFingerDrawing: Bool = false,
        onDrawingChanged: (() -> Void)? = nil
    ) {
        self._canvasView = canvasView
        self.toolPicker = toolPicker
        self.isToolPickerVisible = isToolPickerVisible
        self.allowFingerDrawing = allowFingerDrawing
        self.onDrawingChanged = onDrawingChanged
    }
    
    public func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: .systemBlue, width: 2.5)
        canvasView.drawingPolicy = allowFingerDrawing ? .anyInput : .pencilOnly
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        
        DispatchQueue.main.async {
            toolPicker.setVisible(isToolPickerVisible, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        }
        
        return canvasView
    }
    
    public func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawingPolicy = allowFingerDrawing ? .anyInput : .pencilOnly
        DispatchQueue.main.async {
            toolPicker.setVisible(isToolPickerVisible, forFirstResponder: uiView)
            toolPicker.addObserver(uiView)
            if isToolPickerVisible && !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilKitCanvasView
        
        init(_ parent: PencilKitCanvasView) {
            self.parent = parent
        }
        
        public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.onDrawingChanged?()
        }
    }
}
#endif
