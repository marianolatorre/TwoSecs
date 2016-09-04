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
import QuartzCore

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var leadingPlayerViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var takeVideoButton: UIButton!
    
    var captureSession: AVCaptureSession?
    var stillImageOutput: AVCaptureStillImageOutput?
    var movieOutput: AVCaptureMovieFileOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var defaults: NSUserDefaults = NSUserDefaults.standardUserDefaults()
    var avPlayer : AVPlayer?
    var videoClips:[NSURL] = [NSURL]()
    var thumbnails = [UIImage]()
    var exportReady : Bool = false
    var lastExport : NSURL?
    var audioCapture:AVCaptureDevice?
    var backCameraVideoCapture:AVCaptureDevice?
    var frontCameraVideoCapture:AVCaptureDevice?
    
    
    var _capturing : Bool = false
    var capturing : Bool  {
        get{
            return _capturing
        }
        set{
            takeVideoButton.setImage(UIImage(named: newValue ? "recording": "record"), forState: .Normal)
            
            if newValue {
                glowButtonAnimate()
            }
            
            _capturing = newValue
        }
    }
    var _showingTableView : Bool = false
    var showingTableView : Bool {
        get {return _showingTableView}
        set{
            if newValue {
                takeVideoButton.setImage(UIImage(named: "Trash-Can"), forState: .Normal)
            }else {
                takeVideoButton.setImage(UIImage(named: "record"), forState: .Normal)
            }
            _showingTableView = newValue
        }
    }
    
    var _showingPlayer : Bool = false
    var showingPlayer : Bool {
        get {return _showingPlayer}
        set {
            if newValue {
                takeVideoButton.setImage(UIImage(named: "Delete-100"), forState: .Normal)
            }else {
                takeVideoButton.setImage(UIImage(named: "record"), forState: .Normal)
            }
            _showingPlayer = newValue
        }
    }
    
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
        
        self.collectionHeightConstraint.constant = self.view.frame.size.height - 200
        self.collectionView.backgroundColor = UIColor.clearColor()
        let tapAway = UITapGestureRecognizer(target: self, action: #selector(dismissCollection))
        tapAway.cancelsTouchesInView = false
        self.collectionView.addGestureRecognizer(tapAway)
        
        updateConstraintsForMode()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(playerDidFinishPlaying), name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
        
        if audioCapture == nil{
            return
        }
        beginSession()
        
        if videoClips.count > 1 {
            mergeVideoClips()
        }
    }
    
    func dismissCollection(){
        
        showingTableView = false
        animate()
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
        
        if videoClips.count < 1 {
            return
        }
        
        switch gestureRecognizer.state {
        case .Began:
            showingTableView = !showingTableView
            animate()
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
    
    func glowButtonAnimate() -> Void {
        
        UIView.animateWithDuration(0.3, animations: {
            self.takeVideoButton.transform = CGAffineTransformMakeScale(1.5, 1.5)
            }, completion: {
                (value: Bool) in
                UIView.animateWithDuration(0.3, animations: {
                    self.takeVideoButton.transform = CGAffineTransformIdentity
                })
        })
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
            collectionTopConstraint.constant = 20
        }else {
            collectionTopConstraint.constant = collectionView.frame.size.height * -1
        }
        
        if showingPlayer {
            leadingPlayerViewConstraint.constant = 0
        }
        else {
            leadingPlayerViewConstraint.constant = playerView.frame.size.width * -1
        }
    }
    
    @IBAction func captureVideoButton(sender: AnyObject) {
        
        if showingPlayer {
            showingPlayer = false
            animate()
            avPlayer!.pause()
            return
        }
        
        if showingTableView {
            let alert = UIAlertController(title: "Alert", message: "Are you sure you want to delete all videos?", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .Destructive, handler: {
                action in
                switch action.style{
                case .Destructive:
                    print("destructive")
                    self.deleteProject()
                default:
                    print("default2")
                }
                
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: {
                action in
                switch action.style{
                case .Cancel:
                    print("cancel")
                default:
                    print("default1")
                }
                
            }))
            self.presentViewController(alert, animated: true, completion: nil)
        }
        
        if !capturing && !showingPlayer && !showingTableView {
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
    
    func deleteProject() {
    
        let fileManager = NSFileManager.defaultManager()
        
        for clipUrl in videoClips {
            
            do {
                try fileManager.removeItemAtURL(clipUrl)
            }catch {
                print("Couldnt delete file")
            }
        }
        
        videoClips = [NSURL]()
        thumbnails = [UIImage]()
        saveVideoClipPaths()
        showingTableView = false
        animate()
        collectionView.reloadData()
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
    
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return thumbnails.count
    }
    
    // make a cell for each cell index path
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        // get a reference to our storyboard cell
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("collectionCell", forIndexPath: indexPath) as! CollectionViewCell
        
        // Use the outlet in our custom class to get a reference to the UILabel in the cell
        cell.thumbnailImageView.image = thumbnails[indexPath.row]
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate protocol
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        // handle tap events
        print("You selected cell #\(indexPath.item)!")
        showingTableView = false
        animate()
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
        
        saveVideoClipPaths()
        
        capturing = false
        collectionView.reloadData()
        
        self.showingTableView = false
        self.animate()
        
        if videoClips.count > 1{
            mergeVideoClips()
        }
    }
    
    func saveVideoClipPaths() {
    
        let textPaths : [String] = videoClips.flatMap{
            let theFileName = ($0.absoluteString as NSString).lastPathComponent
            return theFileName
        }
        
        defaults.setObject(textPaths, forKey: "videoClipPaths")
    }
    
    func getThumbnail(outputFileURL:NSURL) -> UIImage {
        
        print ("thumbnail: \(outputFileURL)")
        let clip = AVURLAsset(URL: outputFileURL)
        let imgGenerator = AVAssetImageGenerator(asset: clip)
        let cgImage = try! imgGenerator.copyCGImageAtTime(CMTimeMake(0, 1), actualTime: nil)
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
