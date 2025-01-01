import SwiftUI
import AVFoundation
import Photos
import PlaygroundSupport

class CameraRecorder: NSObject, ObservableObject {
    private var captureSession: AVCaptureSession?
    private var movieOutput = AVCaptureMovieFileOutput()
    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var currentCameraInput: AVCaptureDeviceInput?
    @Published var isRecording = false
    @Published var recordedVideoURL: URL?
    
    override init() {
        super.init()
        setupSession(for: .front) // Default to front camera
    }
    
    private func setupSession(for position: AVCaptureDevice.Position) {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        let camera: AVCaptureDevice?
        if position == .front {
            camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        } else {
            camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }
        
        guard let selectedCamera = camera,
              let cameraInput = try? AVCaptureDeviceInput(device: selectedCamera),
              captureSession?.canAddInput(cameraInput) == true else {
            print("Could not add camera input for position \(position)")
            return
        }
        
        if let currentInput = currentCameraInput {
            captureSession?.removeInput(currentInput)
        }
        
        captureSession?.addInput(cameraInput)
        currentCameraInput = cameraInput
        
        if captureSession?.canAddOutput(movieOutput) == true {
            captureSession?.addOutput(movieOutput)
        }
        
        captureSession?.startRunning()
    }
    
    func setupWideAngleCameraAtMaxFPS() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        guard let wideAngleCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let cameraInput = try? AVCaptureDeviceInput(device: wideAngleCamera),
              captureSession?.canAddInput(cameraInput) == true else {
            print("Wide angle camera not available.")
            return
        }
        
        if let currentInput = currentCameraInput {
            captureSession?.removeInput(currentInput)
        }
        
        captureSession?.addInput(cameraInput)
        currentCameraInput = cameraInput
        
        // Set the camera to its maximum FPS
        if let maxFrameRateRange = maxFrameRate(for: wideAngleCamera) {
            do {
                try wideAngleCamera.lockForConfiguration()
                wideAngleCamera.activeVideoMinFrameDuration = maxFrameRateRange.minFrameDuration
                wideAngleCamera.activeVideoMaxFrameDuration = maxFrameRateRange.minFrameDuration
                wideAngleCamera.unlockForConfiguration()
                print("Set wide angle camera to max FPS: \(1.0 / maxFrameRateRange.minFrameDuration.seconds) FPS")
            } catch {
                print("Could not set frame rate: \(error.localizedDescription)")
            }
        }
        
        if captureSession?.canAddOutput(movieOutput) == true {
            captureSession?.addOutput(movieOutput)
        }
        
        captureSession?.startRunning()
    }
    
    private func maxFrameRate(for device: AVCaptureDevice) -> AVFrameRateRange? {
        return device.activeFormat.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate })
    }
    
    func switchCamera(to position: AVCaptureDevice.Position) {
        captureSession?.stopRunning()
        setupSession(for: position)
    }
    
    func startRecording() {
        guard !isRecording else {
            print("Already recording.")
            return
        }
        
        isRecording = true
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        print("Recording started to \(outputURL.absoluteString).")
    }
    
    func stopRecording() {
        guard isRecording else {
            print("Not currently recording.")
            return
        }
        
        isRecording = false
        movieOutput.stopRecording()
        print("Recording stopped.")
    }
}

extension CameraRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error == nil {
            print("Recording finished. File saved to: \(outputFileURL.absoluteString).")
            saveVideoToPhotoLibrary(outputFileURL)
        } else {
            print("Error recording file: \(error!.localizedDescription)")
        }
    }
    // MARK: - recordFrontAndBack Function
    
    func recordFrontAndBack() {
        
        
        let frontRecordingTime: TimeInterval = 6.0
        let backRecordingTime: TimeInterval = 6.0
        
        self.switchCamera(to: .front)
        self.startRecording()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + frontRecordingTime) { [weak self] in
            self?.stopRecording()
            
            // Wait for a moment before switching to back camera
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.switchCamera(to: .back)
                self?.startRecording()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + backRecordingTime) {
                    self?.stopRecording()
                }
            }
        }
    }
    
    func saveVideoToPhotoLibrary(_ videoURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                print("Photo Library access not granted.")
                return
            }
            
            DispatchQueue.main.async {
                UISaveVideoAtPathToSavedPhotosAlbum(videoURL.path, nil, nil, nil)
                print("Video saved to Photo Library.")
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var recorder = CameraRecorder()
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    recorder.switchCamera(to: .front)
                    recorder.startRecording()
                }) {
                    Text("Record Front Camera")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(recorder.isRecording)
                .opacity(recorder.isRecording ? 0.5 : 1.0)
                
                Button(action: {
                    recorder.switchCamera(to: .back)
                    recorder.startRecording()
                }) {
                    Text("Record Back Camera")
                        .font(.headline)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(recorder.isRecording)
                .opacity(recorder.isRecording ? 0.5 : 1.0)
            }
            .padding()
            
            
            
            Button(action: {
                recorder.recordFrontAndBack()
            }) {
                Text("Record Front and Back Sequentially")
                    .font(.headline)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(recorder.isRecording)
            .opacity(recorder.isRecording ? 0.5 : 1.0)
            
            Button(action: {
                recorder.stopRecording()
            }) {
                Text("Stop Recording")
                    .font(.headline)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .disabled(!recorder.isRecording)
            .opacity(recorder.isRecording ? 1.0 : 0.5)
        }
    }
} 
