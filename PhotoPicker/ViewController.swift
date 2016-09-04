//
//  ViewController.swift
//  Holidays
//
//  Created by Mariano Latorre on 1/23/15.
//  Copyright (c) 2016 Mariano Latorre. All rights reserved.
//

import UIKit
import AVFoundation
import AssetsLibrary
import AVKit
import AVFoundation.AVPlayerLayer

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var trailingTableViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var leadingPlayerViewConstraint: NSLayoutConstraint!
    
    var captureSession: AVCaptureSession?
    var stillImageOutput: AVCaptureStillImageOutput?
    var movieOutput: AVCaptureMovieFileOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var defaults: NSUserDefaults = NSUserDefaults.standardUserDefaults()
    var capturing : Bool = false
    var showingTableView : Bool = false
    var showingPlayer : Bool = false
    var avPlayer : AVPlayer?
    var videoClips:[NSURL] = [NSURL]()
    var thumbnails = [UIImage]()
    var exportReady : Bool = false
    var lastExport : NSURL?
    var audioCapture:AVCaptureDevice?
    var backCameraVideoCapture:AVCaptureDevice?
    var frontCameraVideoCapture:AVCaptureDevice?

    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        videoClips = (defaults.objectForKey("videoClipPaths") as? [String] ?? [String]() ).flatMap{
            let filename = $0
            let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
            let path = "\(documentsPath)/\(filename)"
            let url = NSURL(fileURLWithPath: path)
            return url
        }
        
        print(videoClips)
        
        for clipUrl in videoClips {
            var error: NSError?
            if clipUrl.checkResourceIsReachableAndReturnError(&error) == false {
                return
            }            
            
            thumbnails.append(getThumbnail(clipUrl))
        }

        captureSession = AVCaptureSession()
        
        let forceTouchRecognizer = ForceTouchGestureRecognizer(target: self, action: #selector(handleForceTouchGesture))
        self.previewView.addGestureRecognizer(forceTouchRecognizer)
        
        let devices = AVCaptureDevice.devices()
        for device in devices {
            
            if device.hasMediaType(AVMediaTypeAudio){
                audioCapture = device as? AVCaptureDevice
            }else if device.hasMediaType(AVMediaTypeVideo){
                if device.position == AVCaptureDevicePosition.Back{
                    backCameraVideoCapture = device as? AVCaptureDevice
                }else{
                    frontCameraVideoCapture = device as? AVCaptureDevice
                }
            }
        }
        
        updateConstraintsForMode()
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorColor = .clearColor()
        tableView.backgroundColor = .clearColor()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(playerDidFinishPlaying), name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
        
        if audioCapture == nil{
            return
        }
        beginSession()

        if videoClips.count > 1 {
            mergeVideoClips()
        }
    }
    
    func beginSession() -> Void {
    
        captureSession = AVCaptureSession()
        captureSession!.sessionPreset = AVCaptureSessionPresetHigh
        
        do{
            try captureSession?.addInput(AVCaptureDeviceInput(device: audioCapture!))
        }catch{
            print(error)
            return
        }
        
        do{
            try captureSession?.addInput(AVCaptureDeviceInput(device: backCameraVideoCapture!))
        }catch{
            print(error)
            return
        }
        
        stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput!.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        
        if captureSession!.canAddOutput(stillImageOutput) {
            captureSession!.addOutput(stillImageOutput)
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
            previewLayer!.connection?.videoOrientation = AVCaptureVideoOrientation.Portrait
            previewView.layer.addSublayer(previewLayer!)
        }
        
        movieOutput = AVCaptureMovieFileOutput()
        movieOutput!.movieFragmentInterval = kCMTimeInvalid
        movieOutput!.maxRecordedDuration = CMTimeMakeWithSeconds(2,30)
        
        if captureSession!.canAddOutput(movieOutput) {
            captureSession!.addOutput(movieOutput)
        }
        
        captureSession!.startRunning()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer!.frame = previewView.bounds
    }

    func handleForceTouchGesture(gestureRecognizer: ForceTouchGestureRecognizer) {
        
        switch gestureRecognizer.state {
        case .Began:
            showingTableView = !showingTableView
            animate()
        case .Ended:
            if showingTableView {
                showingTableView = false
                animate()
            }
        default:
            print()
        }
        
        if gestureRecognizer.force > 0.8  && exportReady && !showingPlayer {
            showingTableView = false
            showingPlayer = true
            startPlayer()
            animate()
        }
    }
    
    func playerDidFinishPlaying(note: NSNotification) {
        showingPlayer = false
        showingTableView = false
        animate()
    }
    
    func animate() {
        
        self.view.layoutIfNeeded()
        UIView .animateWithDuration(0.4) {
            self.updateConstraintsForMode()
            self.view.layoutIfNeeded()
        }
    }
    
    func startPlayer() {
        if let url = lastExport {
            avPlayer = AVPlayer(URL: url)
            let playerLayer = AVPlayerLayer(player: avPlayer)
            playerLayer.frame = self.playerView.bounds
            self.playerView.layer.addSublayer(playerLayer)
            avPlayer!.play()
        }
    }
    
    func updateConstraintsForMode() {
    
        if showingTableView {
            trailingTableViewConstraint.constant = 0
        }else {
            trailingTableViewConstraint.constant = tableView.frame.size.width * -1
        }
        
        if showingPlayer {
            leadingPlayerViewConstraint.constant = 0
        }
        else {
            leadingPlayerViewConstraint.constant = playerView.frame.size.width * -1
        }
    }
    
    @IBAction func captureVideoButton(sender: AnyObject) {
        
        if !capturing && !showingPlayer {
            capturing = true
            
            let formatter = NSDateFormatter()
            formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
            let date = NSDate()
            let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
            let outputPath = "\(documentsPath)/\(formatter.stringFromDate(date)).mp4"
            let outputURL = NSURL(fileURLWithPath: outputPath)
            
            movieOutput!.startRecordingToOutputFileURL(outputURL, recordingDelegate: self)
        }
    }
    
    
    @IBAction func didPressTakeAnother(sender: AnyObject) {
        captureSession!.startRunning()
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        
        showingTableView = true
        animate()
        cropVideo(outputFileURL)
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return thumbnails.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell : UITableViewCell = tableView.dequeueReusableCellWithIdentifier("cell") as UITableViewCell!
        
        cell.imageView?.image = thumbnails[indexPath.row]
        cell.backgroundColor = UIColor.clearColor()
        
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 150.0
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func cropVideo(outputFileURL:NSURL){
        
        let videoAsset: AVAsset = AVAsset(URL: outputFileURL) as AVAsset
        
        let clipVideoTrack = videoAsset.tracksWithMediaType(AVMediaTypeVideo).first! as AVAssetTrack
        
        let composition = AVMutableComposition()
        composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: CMPersistentTrackID())
        
        let videoComposition = AVMutableVideoComposition()
        
        videoComposition.renderSize = CGSizeMake(720, 720)
        videoComposition.frameDuration = CMTimeMake(1, 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(180, 30))
        
        // rotate to portrait
        let transformer:AVMutableVideoCompositionLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: clipVideoTrack)
        let t1 = CGAffineTransformMakeTranslation(720, 0);
        let t2 = CGAffineTransformRotate(t1, CGFloat(M_PI_2));
        
        transformer.setTransform(t2, atTime: kCMTimeZero)
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        let date = NSDate()
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
        let outputPath = "\(documentsPath)/\(formatter.stringFromDate(date)).mp4"
        let outputURL = NSURL(fileURLWithPath: outputPath)
        let exporter = AVAssetExportSession(asset: videoAsset, presetName: AVAssetExportPresetHighestQuality)!
        exporter.videoComposition = videoComposition
        exporter.outputURL = outputURL
        exporter.outputFileType = AVFileTypeQuickTimeMovie
        
        exporter.exportAsynchronouslyWithCompletionHandler({ () -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                self.handleExportCompletion(exporter)
            })
        })
    }
    
    func handleExportCompletion(session: AVAssetExportSession) {
        let thumbnail =  self.getThumbnail(session.outputURL!)
        videoClips.append(session.outputURL!)
        thumbnails.append(thumbnail)
        
        
        print(videoClips)
        
        let textPaths : [String] = videoClips.flatMap{
            let theFileName = ($0.absoluteString as NSString).lastPathComponent
            return theFileName
        }
        
        defaults.setObject(textPaths, forKey: "videoClipPaths")
        
        capturing = false
        tableView.reloadData()
        
        self.showingTableView = false
        self.animate()
        
        self.tableView.reloadData()
        if videoClips.count > 1{
            mergeVideoClips()
        }        
    }
    
    func getThumbnail(outputFileURL:NSURL) -> UIImage {
       
        print ("thumbnail: \(outputFileURL)")
        let clip = AVURLAsset(URL: outputFileURL)
        let imgGenerator = AVAssetImageGenerator(asset: clip)
        let cgImage = try! imgGenerator.copyCGImageAtTime(
            CMTimeMake(0, 1), actualTime: nil)
        let uiImage = UIImage(CGImage: cgImage)
        return uiImage
    }
    
    func mergeVideoClips(){
        
        let composition = AVMutableComposition()
        
        let videoTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let audioTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var time:Double = 0.0
        for video in self.videoClips {
            let asset = AVAsset(URL: video)
            let videoAssetTrack = asset.tracksWithMediaType(AVMediaTypeVideo)[0]
            let audioAssetTrack = asset.tracksWithMediaType(AVMediaTypeAudio)[0]
            let atTime = CMTime(seconds: time, preferredTimescale:1)
            do{
                try videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration) , ofTrack: videoAssetTrack, atTime: atTime)
                
                try audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration) , ofTrack: audioAssetTrack, atTime: atTime)
                
            }catch{
                print("something bad happend I don't want to talk about it")
            }
            time +=  asset.duration.seconds
        }
        
        let directory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateStyle = .LongStyle
        dateFormatter.timeStyle = .ShortStyle
        let date = dateFormatter.stringFromDate(NSDate())
        let savePath = "\(directory)/mergedVideo-\(date).mp4"
        let url = NSURL(fileURLWithPath: savePath)
        
        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        exporter?.outputURL = url
        exporter?.shouldOptimizeForNetworkUse = true
        exporter?.outputFileType = AVFileTypeMPEG4
        exporter?.exportAsynchronouslyWithCompletionHandler({ () -> Void in
            self.exportReady = true
            self.lastExport = url
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.finalExportCompletion(exporter!)
            })
        })
    }
    
    func finalExportCompletion(session: AVAssetExportSession) {
        let library = ALAssetsLibrary()
        if library.videoAtPathIsCompatibleWithSavedPhotosAlbum(session.outputURL) {
            var completionBlock: ALAssetsLibraryWriteVideoCompletionBlock
            
            completionBlock = { assetUrl, error in
                if error != nil {
                    print("error writing to disk")
                } else {
                    
                }
            }
            
            library.writeVideoAtPathToSavedPhotosAlbum(session.outputURL, completionBlock: completionBlock)
        }
    }
}
