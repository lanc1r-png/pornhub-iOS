//
//  AppDelegate.swift
//  ICO-visualizer
//
//  Created by Anonymous on 24/09/2020.
//  Copyright © 2020 Anonymous. All rights reserved.
//

import UIKit
import SDWebImage
import AVFoundation
import AlamofireNetworkActivityLogger

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    private var audioLevel : Float = 0.0

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        SDImageCache.shared.config.maxMemoryCost = 150 * 1024 * 1024
        SDImageCache.shared.config.shouldCacheImagesInMemory = true
        SDWebImageDownloader.shared.config.maxConcurrentDownloads = 10
        SDWebImageDownloader.shared.config.downloadTimeout = 20
        SDWebImageDownloader.shared.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        SDWebImageDownloader.shared.setValue("https://www.pornhub.com/", forHTTPHeaderField: "Referer")
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            AVAudioSession.sharedInstance().addObserver(self, forKeyPath: "outputVolume", options: NSKeyValueObservingOptions.new, context: nil)
            audioLevel = AVAudioSession.sharedInstance().outputVolume
        } catch {
            print(error)
        }
        #if DEBUG
            NetworkActivityLogger.shared.level = .debug
            NetworkActivityLogger.shared.startLogging()
        #endif
        return true
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume"{
            let audioSession = AVAudioSession.sharedInstance()
            if audioSession.outputVolume > audioLevel {
                NotificationCenter.default.post(Notification(name: .didPressVolumeUp, object: nil, userInfo: ["volume" : audioSession.outputVolume]))
            }
            if audioSession.outputVolume < audioLevel {
                NotificationCenter.default.post(Notification(name: .didPressVolumeDown, object: nil, userInfo: ["volume" : audioSession.outputVolume]))
            }
            audioLevel = audioSession.outputVolume
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

