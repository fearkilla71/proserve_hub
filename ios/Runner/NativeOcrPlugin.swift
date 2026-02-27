import Flutter
import UIKit
import Vision

/// Flutter platform channel plugin that uses Apple Vision framework for OCR.
/// Replaces Google ML Kit to avoid MLImage simulator incompatibility.
class NativeOcrPlugin: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.verohue.proservehub/ocr",
            binaryMessenger: registrar.messenger()
        )
        let instance = NativeOcrPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "recognizeText":
            guard let args = call.arguments as? [String: Any],
                  let imagePath = args["imagePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "imagePath is required", details: nil))
                return
            }
            recognizeText(imagePath: imagePath, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func recognizeText(imagePath: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: imagePath)
            guard let image = UIImage(contentsOfFile: url.path),
                  let cgImage = image.cgImage else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "IMAGE_ERROR", message: "Could not load image at \(imagePath)", details: nil))
                }
                return
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "OCR_ERROR", message: error.localizedDescription, details: nil))
                }
                return
            }

            let text = request.results?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""

            DispatchQueue.main.async {
                result(text)
            }
        }
    }
}
