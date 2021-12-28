//
//  ViewController.swift
//  MakingVideo
//
//  Created by MZ01-KYONGH on 2021/12/22.
//

import Cocoa
import AVKit
import AVFoundation
import Photos

class ViewController: NSViewController {
    
    typealias UIImage = NSImage
    
    var projectURL: String?
    var videoURL: String?
    var photoURLs: [URL] = []
    var photos: [NSImage] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    
    @IBAction func clickedGetPhotos(_ sender: NSButton) {
        openProject()
    }
    
    @IBAction func clickedMakeVideo(_ sender: NSButton) {
        buildVideoFromImageArray(framesArray: photos)
    }
    
    
    func saveVideoToLibrary(videoURL: URL) {
        print("\(videoURL)")
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }) { saved, error in
            
            if let error = error {
                print("Error saving video to librayr: \(error.localizedDescription)")
            }
            if saved {
                print("Video save to library")
                
            }
        }
    }
    
    private func makeVideoURL() {
        guard let projectURL = projectURL else {
            print("Failed to create projectURL")
            return
        }

        let videoFolder = projectURL + "video/"
        videoURL = "file://" + videoFolder + "result.mp4"
        
        guard let videoURL = videoURL else {
            return
        }
        
        do {
            if !FileManager.default.fileExists(atPath: videoFolder){
                try FileManager.default.createDirectory(atPath: videoFolder, withIntermediateDirectories: true, attributes: nil)
                // print("Success to create videoURL")
            }
        } catch {
            print(error)
        }
    }
    
    func buildVideoFromImageArray(framesArray: [UIImage]) {
        var images = framesArray
        let outputSize = CGSize(width:images[0].size.width, height: images[0].size.height)
        
        makeVideoURL()

        guard let videoURL = videoURL else {
            print("Failed to make videoURL")
            return
        }

        let videoOutputURL = URL(string: videoURL)

        guard let videoOutputURL = videoOutputURL else {
            print("Failed to make videoOutputURL")
            return
        }
        
        if FileManager.default.fileExists(atPath: videoOutputURL.path) {
            do {
                try FileManager.default.removeItem(atPath: videoOutputURL.path)
            } catch {
                fatalError("Unable to delete file: \(error) : \(#function).")
            }
        }
        
        guard let videoWriter = try? AVAssetWriter(outputURL: videoOutputURL, fileType: AVFileType.mp4) else {
            fatalError("AVAssetWriter error")
        }
        
        let outputSettings = [AVVideoCodecKey : AVVideoCodecType.h264, AVVideoWidthKey : NSNumber(value: Float(outputSize.width)), AVVideoHeightKey : NSNumber(value: Float(outputSize.height))] as [String : Any]
        
        guard videoWriter.canApply(outputSettings: outputSettings, forMediaType: AVMediaType.video) else {
            fatalError("Negative : Can't apply the Output settings...")
        }
        
        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        let sourcePixelBufferAttributesDictionary = [
            kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: NSNumber(value: Float(outputSize.width)),
            kCVPixelBufferHeightKey as String: NSNumber(value: Float(outputSize.height))
        ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        
        if videoWriter.startWriting() {
            videoWriter.startSession(atSourceTime: CMTime.zero)
            assert(pixelBufferAdaptor.pixelBufferPool != nil)
            
            let media_queue = DispatchQueue(__label: "mediaInputQueue", attr: nil)
            
            videoWriterInput.requestMediaDataWhenReady(on: media_queue, using: { () -> Void in
                let fps: Int32 = 30//2
                let frameDuration = CMTimeMake(value: 1, timescale: fps)
                
                var frameCount: Int64 = 0
                var appendSucceeded = true
                
                while (!images.isEmpty) {
                    if (videoWriterInput.isReadyForMoreMediaData) {
                        let nextPhoto = images.remove(at: 0)
                        let lastFrameTime = CMTimeMake(value: frameCount, timescale: fps)
                        let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                        
                        var pixelBuffer: CVPixelBuffer? = nil
                        let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
                        
                        if let pixelBuffer = pixelBuffer, status == 0 {
                            let managedPixelBuffer = pixelBuffer
                            
                            CVPixelBufferLockBaseAddress(managedPixelBuffer, [])
                            
                            let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
                            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                            let context = CGContext(data: data, width: Int(outputSize.width), height: Int(outputSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(managedPixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
                            
                            context?.clear(CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height))
                            
                            let horizontalRatio = CGFloat(outputSize.width) / nextPhoto.size.width
                            let verticalRatio = CGFloat(outputSize.height) / nextPhoto.size.height
                            
                            let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit
                            
                            let newSize = CGSize(width: nextPhoto.size.width * aspectRatio, height: nextPhoto.size.height * aspectRatio)
                            
                            let x = newSize.width < outputSize.width ? (outputSize.width - newSize.width) / 2 : 0
                            let y = newSize.height < outputSize.height ? (outputSize.height - newSize.height) / 2 : 0
                            
                            context?.draw(nextPhoto.cgImage!, in: CGRect(x: x, y: y, width: newSize.width, height: newSize.height))
                            
                            CVPixelBufferUnlockBaseAddress(managedPixelBuffer, [])
                            
                            appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                            frameCount += 1
                        } else {
                            print("Failed to allocate pixel buffer")
                            appendSucceeded = false
                        }
                    }
                    if !appendSucceeded {
                        break
                    }
                    
                }
                videoWriterInput.markAsFinished()
                videoWriter.finishWriting { () -> Void in
                    // print("Done saving")
                    self.saveVideoToLibrary(videoURL: videoOutputURL)
                }
            })
        }
    }
    
    private func openProject() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        
        let status = openPanel.runModal()
        
        if status == NSApplication.ModalResponse.OK {
            guard let url = URL(string: openPanel.url!.absoluteString) else { return }
            var photosURL = url.absoluteString
            let startIdx: String.Index = photosURL.index(photosURL.startIndex, offsetBy: 7)
            photosURL = String(photosURL[startIdx...])
            projectURL = photosURL
            loadImage(path: photosURL)
        }
    }
    
    
    private func loadImage(path: String) {
        if path != "" {
            let imagePath = path
            let url = URL(string: imagePath)
            let fileManager = FileManager.default
            let properties = [URLResourceKey.localizedNameKey,
                              URLResourceKey.creationDateKey,
                              URLResourceKey.localizedTypeDescriptionKey]
            
            do {
                let imagesURL = try fileManager.contentsOfDirectory(at: url!, includingPropertiesForKeys: properties, options:FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
                let jpgURL = imagesURL.filter{ $0.pathExtension == "jpg" || $0.pathExtension == "png" }
                self.photoURLs = jpgURL.sorted { a, b in
                    return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == ComparisonResult.orderedAscending
                }
                urlToNSImage(urls: photoURLs)
            }
            catch let error as NSError {
                print(error.description)
            }
            
        }
    }
    
    private func urlToNSImage(urls: [URL]) {
        for url in urls {
            let imageData = try! Data(contentsOf: url)
            let image = NSImage(data: imageData)
            photos.append(image!)
        }
        if !urls.isEmpty {
            print("Success to save Images! Try to make Video")
        }
    }

}

