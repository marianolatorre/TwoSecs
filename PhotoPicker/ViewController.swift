//
//  ViewController.swift
//  Holidays
//
//  Created by Mariano Latorre on 1/23/15.
//  Copyright (c) 2016 Mariano Latorre. All rights reserved.
//

import UIKit
import AVFoundation
//import AVFoundation.AVError
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
    let nextVideoKey: String = "nextVideoKey"
    var maxVideo : Int = 0
    var capturing : Bool = false
    var showingTableView : Bool = false
    var showingPlayer : Bool = false
    var avPlayer : AVPlayer?
    
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let forceTouchRecognizer = ForceTouchGestureRecognizer(target: self, action: #selector(handleForceTouchGesture))
        self.previewView.addGestureRecognizer(forceTouchRecognizer)
        
        maxVideo = defaults.integerForKey(nextVideoKey)
        
        updateConstraintsForMode()
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorColor = .clearColor()
        tableView.backgroundColor = .clearColor()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(playerDidFinishPlaying), name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)

    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        captureSession = AVCaptureSession()
        captureSession!.sessionPreset = AVCaptureSessionPresetHigh
        
        let backCamera = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        var error: NSError?
        var input: AVCaptureDeviceInput!
        do {
            input = try AVCaptureDeviceInput(device: backCamera)
        } catch let error1 as NSError {
            error = error1
            input = nil
        }
        
        if error == nil {
            if captureSession!.canAddInput(input) {
                captureSession!.addInput(input)
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
    }
    
    private var tempFilePath: NSURL = {
        let tempPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent("tempMovie").URLByAppendingPathExtension("mp4").absoluteString
        if NSFileManager.defaultManager().fileExistsAtPath(tempPath) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(tempPath)
            } catch { }
        }
        return NSURL(string: tempPath)!
    }()
    
    func documentsSaveDir() -> String {
        let nsDocumentDirectory = NSSearchPathDirectory.DocumentDirectory
        let nsUserDomainMask = NSSearchPathDomainMask.UserDomainMask
        let paths = NSSearchPathForDirectoriesInDomains(nsDocumentDirectory, nsUserDomainMask, true)
        if let dirPath = paths.first {
            return dirPath
        }
        return ""
    }
    
    private func mergedFileUrl(number: Int) -> NSURL {
        return fileNumber(number, name: "merged_", fileExt: "mp4")
    }
    
    private func videoFileUrl(number: Int) -> NSURL {
        return fileNumber(number, name: "video_", fileExt: "mp4")
    }

    private func thumbnailFileUrl(number: Int) -> NSURL {
        return fileNumber(number, name: "thumbnail_", fileExt: "png")
    }
    
    
    private func fileNumber(number: Int, name: String, fileExt: String) -> NSURL {
        
        let path = NSURL(fileURLWithPath: documentsSaveDir()).URLByAppendingPathComponent(name + String(number)).URLByAppendingPathExtension(fileExt).absoluteString
        if NSFileManager.defaultManager().fileExistsAtPath(path) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(path)
            } catch { }
        }
        return NSURL(string: path)!
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
        
        if gestureRecognizer.force > 0.8  && maxVideo > 0 && !showingPlayer {
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
        avPlayer = AVPlayer(URL: mergedFileUrl(maxVideo-1))
        let playerLayer = AVPlayerLayer(player: avPlayer)
        playerLayer.frame = self.playerView.bounds
        self.playerView.layer.addSublayer(playerLayer)
        avPlayer!.play()
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
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer!.frame = previewView.bounds
    }

    
    @IBAction func captureVideoButton(sender: AnyObject) {
        
        if !capturing {
            capturing = true
            movieOutput!.startRecordingToOutputFileURL(videoFileUrl(maxVideo), recordingDelegate: self)
            self.didPressTakePhoto(UIButton())
        }
    }
    
    @IBAction func didPressTakePhoto(sender: UIButton) {
        
        if let videoConnection = stillImageOutput!.connectionWithMediaType(AVMediaTypeVideo) {
            videoConnection.videoOrientation = AVCaptureVideoOrientation.Portrait
            stillImageOutput?.captureStillImageAsynchronouslyFromConnection(videoConnection, completionHandler: {(sampleBuffer, error) in
                if (sampleBuffer != nil) {
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    
                    do {
                        try imageData.writeToURL(self.thumbnailFileUrl(self.maxVideo), options: .DataWritingAtomic)
                    }
                    catch {
                        // error!!!
                    }
                }
            })
        }
    }
    
    @IBAction func didPressTakeAnother(sender: AnyObject) {
        captureSession!.startRunning()
    }

    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        
        print ("Video \(maxVideo) saved!")
        showingTableView = true
        animate()
        merge()
        
        maxVideo = maxVideo + 1
        defaults.setInteger(maxVideo, forKey:nextVideoKey)
        capturing = false
        
        tableView.reloadData()
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return maxVideo
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell : UITableViewCell = tableView.dequeueReusableCellWithIdentifier("cell") as UITableViewCell!
        
        cell.imageView?.image = UIImage(data: NSData(contentsOfURL: thumbnailFileUrl(maxVideo - indexPath.row - 1))!)
        cell.backgroundColor = UIColor.clearColor()
        
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 150.0
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    
    func merge() {
        let assetOptions = [AVURLAssetPreferPreciseDurationAndTimingKey : true]
        
        let firstAsset = AVURLAsset(URL: mergedFileUrl(maxVideo-1), options: assetOptions);
        let secondAsset = AVURLAsset(URL: videoFileUrl(maxVideo), options: assetOptions);
        
        let firstTime = maxVideo == 0
        
        
        if firstTime {
            let fileManager = NSFileManager.defaultManager();
            do {
                try fileManager.copyItemAtURL(videoFileUrl(maxVideo), toURL: mergedFileUrl(maxVideo))
            }catch {
                // error
            }
            return
        }
        
        // 1 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
        let mixComposition = AVMutableComposition()
        
        // 2 - Create two video tracks
        
        let firstTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        
        let track2 = secondAsset.tracksWithMediaType(AVMediaTypeVideo)[0]
        let track1 = firstAsset.tracksWithMediaType(AVMediaTypeVideo)[0]
        
        do {
            try firstTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, track1.timeRange.duration), ofTrack:track1 , atTime: kCMTimeZero)
        } catch _ {
            print("Failed to load first track")
        }
        
        let secondTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        do {
            
            try secondTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, track2.timeRange.duration), ofTrack:track2 , atTime: track1.timeRange.duration)
        } catch _ {
            print("Failed to load second track")
        }
        
        // 2.1
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeAdd( track1.timeRange.duration, track2.timeRange.duration))
        
        // 2.2
        let firstInstruction = videoCompositionInstructionForTrack(firstTrack, asset: firstAsset)
        firstInstruction.setOpacity(0.0, atTime: track1.timeRange.duration)
        let secondInstruction = videoCompositionInstructionForTrack(secondTrack, asset: secondAsset)
        
        mainInstruction.layerInstructions = [firstInstruction, secondInstruction]
        
        // 2.3
        
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(1, 30)
        mainComposition.renderSize = CGSize(width: UIScreen.mainScreen().bounds.width, height: UIScreen.mainScreen().bounds.height)
        
        // 3 - Audio track
//        if let loadedAudioAsset = audioAsset {
//            let audioTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: 0)
//            do {
//                try audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, CMTimeAdd(firstAsset.duration, secondAsset.duration)),
//                                               ofTrack: loadedAudioAsset.tracksWithMediaType(AVMediaTypeAudio)[0] ,
//                                               atTime: kCMTimeZero)
//            } catch _ {
//                print("Failed to load Audio track")
//            }
//        }
//        
        // 4 - Get path
//        let documentDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
//        let dateFormatter = NSDateFormatter()
//        dateFormatter.dateStyle = .LongStyle
//        dateFormatter.timeStyle = .ShortStyle
//        let date = dateFormatter.stringFromDate(NSDate())
//        let savePath = (documentDirectory as NSString).stringByAppendingPathComponent("mergeVideo-\(date).mov")
        
        
        let url = mergedFileUrl(maxVideo)
        
        // 5 - Create Exporter
        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.outputURL = url
        exporter.outputFileType = AVFileTypeQuickTimeMovie
//        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = mainComposition
        exporter.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeAdd( track1.timeRange.duration, track2.timeRange.duration - CMTimeMake(5, 1000) ))
        
        
        // 6 - Perform the Export
        exporter.exportAsynchronouslyWithCompletionHandler() {
            dispatch_async(dispatch_get_main_queue()) { _ in
//                self.exportDidFinish(exporter)
                print ("finished")
                self.showingTableView = false
                self.animate()

            }
        }
        
    }
    
    func videoCompositionInstructionForTrack(track: AVCompositionTrack, asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction {
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let assetTrack = asset.tracksWithMediaType(AVMediaTypeVideo)[0]
        
        let transform = assetTrack.preferredTransform
        let assetInfo = orientationFromTransform(transform)
        
        var scaleToFitRatio = UIScreen.mainScreen().bounds.width / assetTrack.naturalSize.width
        if assetInfo.isPortrait {
            scaleToFitRatio = UIScreen.mainScreen().bounds.width / assetTrack.naturalSize.height
            let scaleFactor = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio)
            instruction.setTransform(CGAffineTransformConcat(assetTrack.preferredTransform, scaleFactor),
                                     atTime: kCMTimeZero)
        } else {
            let scaleFactor = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio)
            var concat = CGAffineTransformConcat(CGAffineTransformConcat(assetTrack.preferredTransform, scaleFactor), CGAffineTransformMakeTranslation(0, UIScreen.mainScreen().bounds.width / 2))
            if assetInfo.orientation == .Down {
                let fixUpsideDown = CGAffineTransformMakeRotation(CGFloat(M_PI))
                let windowBounds = UIScreen.mainScreen().bounds
                let yFix = assetTrack.naturalSize.height + windowBounds.height
                let centerFix = CGAffineTransformMakeTranslation(assetTrack.naturalSize.width, yFix)
                concat = CGAffineTransformConcat(CGAffineTransformConcat(fixUpsideDown, centerFix), scaleFactor)
            }
            instruction.setTransform(concat, atTime: kCMTimeZero)
        }
        
        return instruction
    }
    
    func orientationFromTransform(transform: CGAffineTransform) -> (orientation: UIImageOrientation, isPortrait: Bool) {
        var assetOrientation = UIImageOrientation.Up
        var isPortrait = false
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            assetOrientation = .Right
            isPortrait = true
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            assetOrientation = .Left
            isPortrait = true
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            assetOrientation = .Up
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            assetOrientation = .Down
        }
        return (assetOrientation, isPortrait)
    }
}



