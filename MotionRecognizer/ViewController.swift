//
//  ViewController.swift
//  MotionRecognizer
//
//  Created by Dotugo Indonesia on 10/18/17.
//  Copyright © 2017 Ansyar Hafid. All rights reserved.
//

import AVFoundation
import Vision
import UIKit

class ViewController: UIViewController {
    
    @IBOutlet private weak var cameraView: UIView!
    
    @IBOutlet private weak var highlightView: UIView? {
        didSet{
            self.highlightView?.layer.borderColor = UIColor.red.cgColor
            self.highlightView?.layer.borderWidth = 4
            self.highlightView?.backgroundColor = .clear
        }
    }
    
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private lazy var captureSession: AVCaptureSession = {
        let session             = AVCaptureSession()
        session.sessionPreset   = AVCaptureSession.Preset.photo
        guard
            let frontCamera     = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.back),
            let input           = try? AVCaptureDeviceInput(device: frontCamera)
        else { return session }
        
        session.addInput(input)
        
        return session
    }()
    
    private let visionSequenceHandler = VNSequenceRequestHandler()
    private var lastObservation: VNDetectedObjectObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //make the camera appear on the screen
        self.cameraView.layer.addSublayer(self.cameraLayer)
        
        //register for delegation
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyQueue"))
        self.captureSession.addOutput(videoOutput)
        
        //begin session
        self.captureSession.startRunning()
    }

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.cameraLayer.frame = self.cameraView?.bounds ?? .zero
    }
    
    private func handleVisionRequestUpdate(_ request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            //make sure there is a result
            guard let newObservation    = request.results?.first as? VNDetectedObjectObservation else { return }
            self.lastObservation        = newObservation
            
            // check the confidence level before updating the UI
            guard newObservation.confidence >= 0.3 else {
                // hide the rectangle when we lose accuracy so the user knows something is wrong
                self.highlightView?.frame = .zero
                return
            }
            
            //calculate view rect
            var transformedRect         = newObservation.boundingBox
            transformedRect.origin.y    = 1 - transformedRect.origin.y
            let convertedRect           = self.cameraLayer.layerRectConverted(fromMetadataOutputRect: transformedRect)
            
            self.highlightView?.frame    = convertedRect
        }
    }
    
    
    @IBAction private func userTapped(_ sender: UITapGestureRecognizer) {
        //get the tap center
        self.highlightView?.frame.size  = CGSize(width: 120, height: 120)
        self.highlightView?.center      = sender.location(in: self.view)
        
        //convert rect to initial observation
        let originalRect        = self.highlightView?.frame ?? .zero
        var convertedRect       = self.cameraLayer.metadataOutputRectConverted(fromLayerRect: originalRect)
        convertedRect.origin.y  = 1 - convertedRect.origin.y
        
        //set the observation
        let newObservation = VNDetectedObjectObservation(boundingBox: convertedRect)
        self.lastObservation = newObservation
    }

}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard
            //get CVPixelBuffer
            let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            //make sure there is previous observation into request
            let lastObservation = self.lastObservation
            else { return }
        
        //create request
        let request = VNTrackObjectRequest(detectedObjectObservation: lastObservation, completionHandler: self.handleVisionRequestUpdate)
        //set accuracy high
        request.trackingLevel = .accurate
        
        //perform request
        do {
            try self.visionSequenceHandler.perform([request], on: pixelBuffer)
        } catch {
            print("Throws: \(error.localizedDescription)")
        }
    }
}

