//
//  LevelCompletionVC.swift
//  EnglishForBeginners
//
//  Created by Dmitriy Mamatov on 27/03/2018.
//  Copyright © 2018 Omega-R. All rights reserved.
//

import UIKit
import ORCommonCode_Swift
import AVFoundation
import AVKit
import Reachability
import Photos

class LevelCompletionVC: BaseVC, URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let permanentURL = documentsDirectory.appendingPathComponent(location.lastPathComponent)

            do {
                // If file already exists, remove it (optional)
                if fileManager.fileExists(atPath: permanentURL.path) {
                    try fileManager.removeItem(at: permanentURL)
                }

                try fileManager.moveItem(at: location, to: permanentURL)
                // Now you can safely save the video to the Photos library
                saveVideoToPhotoLibrary(url: permanentURL)
            } catch {
                print("Could not move file to permanent location: \(error)")
            }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
                print("Download error: \(error.localizedDescription)")
            } else {
                print("Download task completed successfully.")
            }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            // Update your progress bar's value here
            print("progress is \(progress)")
        }
    }
    
    
    
    
    @IBOutlet weak var viewStarsContainer: UIView!
    @IBOutlet weak var viewNewRank: UIView!
    @IBOutlet weak var viewExperienceInfoContainer: UIView!
    
    @IBOutlet weak var labelNewRankName: UILabel!
    
    @IBOutlet weak var labelEarnedExperience: UILabel!
    @IBOutlet weak var labelNewRankExperience: UILabel!
    @IBOutlet weak var quizImageView: UIImageView!

    @IBOutlet weak var teacherView: UIView!
    @IBOutlet weak var teacherImageView: UIImageView!
    
    weak var viewExperienceInfo: ExperienceInfoView!
    weak var starsView: StarsView!
    
    var activityIndicator: UIActivityIndicatorView?
    var stars: Int = 0
    var experience: Int = 0
    var topic: Topic?
    
    var isExamCompletion = false
    var starsWereAnimated = false

    var displayedAd = false
    
    lazy var playerViewController: AVPlayerViewController = {
        let playerViewController = AVPlayerViewController()
        playerViewController.showsPlaybackControls = true
        return playerViewController
    }()
    
    lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Close", for: .normal)
        button.addTarget(self, action: #selector(closePlayer), for: .touchUpInside)
        button.tintColor = UIColor.white
        button.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        return button
    }()
    
    // MARK: - ViewController lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        prepareView()
        setupNotifications()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    @objc func closePlayer() {
        // Example of stopping the player and removing the view
        quitVideoAndShowProgress()
        
        // If using a modal presentation, you might instead call:
        // dismiss(animated: true, completion: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if (stars == 0) {
            animateStars()
        } else {
            showTeacher()
            
        }
    }

    // MARK: - Prepare UI
    
    func prepareView() {
        
        let oldOverallExperience = ProfileManager.getOverallExperience()
        let newOverallExperience = oldOverallExperience + experience
        
        ProfileManager.saveExperience(experience: newOverallExperience, difference: experience)
        
        let oldRank = RankCalculator(experience: oldOverallExperience).rank
        let newRankCalculator = RankCalculator(experience: newOverallExperience)
        let newRank = newRankCalculator.rank
        
        if oldRank == newRank {
            updateExperienceInfo(with: newRankCalculator)
        } else {
            updateNewRankView(with: newRankCalculator)
        }
        
        viewStarsContainer.isHidden = isExamCompletion
        quizImageView.isHidden = !isExamCompletion
        
        prepareForAnimation()
        
        if experience > 0 {
            let experienceText = String(format: "xp".localizedWithCurrentLanguage(), experience)
            let expirienceAttributedString = NSMutableAttributedString(string: experienceText, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20, weight: .medium)])
            if let numberRange = experienceText.range(of: "\(experience)") {
                let range = NSRange(numberRange, in: experienceText)
                expirienceAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 20, weight: .bold), range: range)
            }
            if let plusRange = experienceText.range(of: "+") {
                let range = NSRange(plusRange, in: experienceText)
                expirienceAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 20, weight: .bold), range: range)
            }
            labelEarnedExperience.attributedText = expirienceAttributedString
        } else {
            labelEarnedExperience.text = ""
        }
    }
    
    func prepareExperienceLabel() {
        if experience > 0 {
            let experienceText = String(format: "xp".localizedWithCurrentLanguage(), experience)
            let expirienceAttributedString = NSMutableAttributedString(string: experienceText, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20, weight: .medium)])
            if let numberRange = experienceText.range(of: "\(experience)") {
                let range = NSRange(numberRange, in: experienceText)
                expirienceAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 20, weight: .bold), range: range)
            }
            if let plusRange = experienceText.range(of: "+") {
                let range = NSRange(plusRange, in: experienceText)
                expirienceAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 20, weight: .bold), range: range)
            }
            labelEarnedExperience.attributedText = expirienceAttributedString
        } else {
            labelEarnedExperience.text = ""
        }
    }
    
    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    func prepareForAnimation() {
        if !isExamCompletion {
            starsView = StarsView.or_loadFromNib(containerToFill: viewStarsContainer) 
            starsView.setStarCount(stars, animated: true)
            starsView.imageViews.forEach { $0.layer.opacity = 0 }
        }
    }

    func showTeacher() {
        
        or_dispatch_in_main_queue_after(0.75) { [weak self] in
            if let sSelf = self {
                sSelf.playVideo()
            }
        }
    }
    
    func showResults() {
        teacherView.isHidden = true
        
        animateStars()
    }
    
    func animateStars() {
        guard !starsWereAnimated else {
            return
        }
        
        starsWereAnimated = true
        
        if !isExamCompletion, stars != 0 {
            let viewsToAnimate = starsView.imageViews.or_limitedBySize(stars)
            let starsAnimator = StarsAnimator(views: viewsToAnimate, scale: 15, singleDuration: 0.6)
            starsAnimator.animate()
            or_dispatch_in_main_queue_after(0.6 * Double(stars)) { [weak self] in
                if let sSelf = self {
                    sSelf.displayedAd = true
                    AdManager.shared.showInterstitial(in: sSelf, onClose: nil)
                }
            }
        }
    }
    
    func updateExperienceInfo(with rankCalculator: RankCalculator) {
        let viewExperienceInfo = ExperienceInfoView.or_loadFromNib(containerToFill: viewExperienceInfoContainer) 
        
        let colorPack = ExperienceInfoView.ColorPack(rankColor: AppColors.completionRankColor, currentExperienceColor: .white, filledProgressColor: .white, emptyProgressColor: AppColors.completionEmptyProgressColor, experienceToNextColor: AppColors.completionExperienceToNextRankColor, otherColor: AppColors.completionOtherColor)
        
        viewExperienceInfo.updateColors(with: colorPack)
        viewExperienceInfo.update(with: rankCalculator)
        
        self.viewExperienceInfo = viewExperienceInfo
    }
    
    func updateNewRankView(with rankCalculator: RankCalculator) {
        viewNewRank.isHidden = false
        viewExperienceInfoContainer.isHidden = true
        
        labelNewRankName.text = rankCalculator.rank.title.capitalized
        labelNewRankExperience.text = "\(rankCalculator.experience)"
    }

    // MARK: - Actions
    
    @IBAction func okPressed(_ sender: Any) {
        if (!displayedAd) {
            displayedAd = true
            AdManager.shared.showInterstitial(in: self) { [weak self] in
                self?.popToController(with: TopicsViewController.self)
            }
        } else {
            popToController(with: TopicsViewController.self)
        }
    }
    
    @IBAction func sharePressed(_ sender: Any) {
        if topic != nil {
            AnalyticsHelper.logEventWithParameters(event: .Lesson_Finish_Share, themeId: topic?.theme?.name, topicId: topic?.name, typeOfLesson: nil, starsCount: nil, language: nil)
        }
        
        let isNewRankAchieved = !viewNewRank.isHidden
        
        var description: String = ""
        
        if isNewRankAchieved {
            description = String(format: "new-rank-share".localizedWithCurrentLanguage(), labelNewRankName.text!)
        } else if isExamCompletion {
            description = String(format: "experience-share".localizedWithCurrentLanguage(), experience)
        } else if case 1...3 = stars {
            description = String(format: "\(stars)-star\(stars > 1 ? "s" : "")-share".localizedWithCurrentLanguage(), experience)
        }
        
        FBSharer().shareUserResults(fromVC: self, link: URL(string: "https://itunes.apple.com/gb/app/learn-model-english/id1367918761?mt=8"), quote: description)
        // changed ru to gb on 21/7/19
    }
    
    // MARK: - Public

    func setInfo(stars: Int, experience: Int) {
        self.stars = stars
        self.experience = experience
    }
    
}

// MARK: - Video
extension LevelCompletionVC {
    
    
    
    func playVideo() {
        
        if activityIndicator == nil {
            if #available(iOS 13.0, *) {
                activityIndicator = UIActivityIndicatorView(style: .large)
            } else {
                activityIndicator = UIActivityIndicatorView(style: .gray)
            }
                activityIndicator?.center = view.center
                activityIndicator?.hidesWhenStopped = true
                if let indicator = activityIndicator {
                    playerViewController.view.addSubview(indicator)
                }
            }
        
        activityIndicator?.startAnimating()
        guard
            let reachability = try? Reachability(),
            [.cellular, .wifi].contains(reachability.connection)
        else {
            showResults()
            activityIndicator?.stopAnimating()
            return
        }
        let videoURL = MotivationalVideoManager.shared.nextVideoURL
        let player = AVPlayer(url: videoURL)
        player.volume = 5
        playerViewController.player = player
        addChild(playerViewController)
        playerViewController.view.frame = view.frame
        view.addSubview(playerViewController.view)
        
        
        playerViewController.contentOverlayView?.addSubview(self.closeButton)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        if let overlayView = playerViewController.contentOverlayView {
            overlayView.addSubview(closeButton)
            
            let guide = overlayView.safeAreaLayoutGuide
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 0),
                closeButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: 0),
                closeButton.widthAnchor.constraint(equalToConstant: 100),
                closeButton.heightAnchor.constraint(equalToConstant: 100)
            ])
        }
        
        playerViewController.view.alpha = 0
        UIView.animate(withDuration: 0.5, delay: 0, options: []) { [weak self] in
            self?.playerViewController.view.alpha = 1
            
        } completion: { _ in
            self.activityIndicator?.stopAnimating()
            player.play()
        }
    }
    
    @objc func playerDidFinishPlaying() {

        let alertController = UIAlertController(title: "Video Completed.", message: "Do You want to download this video to your photo library? Your video will be downloaded in the background while you can keep using the app.", preferredStyle: .alert)
        let downloadAction = UIAlertAction(title: "Download", style: .default) { (action) in
            // Handle the action when the user taps the button
            self.checkDownloadPermission()
            
        }
        let quitAction = UIAlertAction(title: "Quit", style: .default) { (action) in
            // Handle the action when the user taps the button
            self.quitVideoAndShowProgress()
        }
        alertController.addAction(downloadAction)
        alertController.addAction(quitAction)
        
        self.present(alertController, animated: true)
        
        
    }
    
    func quitVideoAndShowProgress(){
        MotivationalVideoManager.shared.setNextVideoAsLast()

        // close the video and show results
        UIView.animate(withDuration: 0.5, delay: 0, options: []) { [weak self] in
            self?.playerViewController.view.alpha = 0
        } completion: { [weak self] _ in
            or_dispatch_in_main_queue_after(0.5) { [weak self] in
                self?.playerViewController.removeFromParent()
                self?.playerViewController.view.removeFromSuperview()
                self?.showResults()
            }
        }
    }
    
    
    // download video from a url
    func downloadAndSaveVideo(from urlString: URL) {
        quitVideoAndShowProgress()
        DispatchQueue.global(qos: .background).async {
            let urlData = NSData(contentsOf: urlString)
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
            let filePath="\(documentsPath)/tempFile.mp4"
            DispatchQueue.main.async {
                urlData?.write(toFile: filePath, atomically: true)
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: filePath))
                }) { completed, error in
                    if completed {
                        print("Video is saved!")
                    }
                    
                }
            }
            
        }
    }
    
    private func saveVideoToPhotoLibrary(url: URL) {
        
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            let videoPath = url.path
                // Save the video
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { saved, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error saving video to photo library: \(error.localizedDescription), \(error)")
    
                    } else if saved {
                        print("Video successfully saved to photo library.")
                    }
                }
            }
        default:
            print("default")
        }
    }
    
    // Check Download and save permission from the user's phone.
    func checkDownloadPermission(){
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            // Permission already granted
            print("Authorized")
            downloadAndSaveVideo(from: MotivationalVideoManager.shared.nextVideoURL)
        case .notDetermined:
            // Request permission
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized {
                    self.downloadAndSaveVideo(from: MotivationalVideoManager.shared.nextVideoURL)
                } else {
                    print("Denied")
                    self.quitVideoAndShowProgress()
                }
            }
        case .denied:
            quitVideoAndShowProgress()
            
        default:
            // Permission denied
            self.showPermissionAlert(title: "Photo Library Permission.", message: "We need to use photo library in order to download your videos. You can change this in App Settings.")
            
        }
    }
    
    // If the user has denied permission, handle the case.
    func showPermissionAlert(title: String, message: String){
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default) { (action) in
            // Handle the action when the user taps the button
            self.quitVideoAndShowProgress()
        }
        alertController.addAction(okAction)
        
    }
    
    
    
}
