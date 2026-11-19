//
//  ReelsViewCoordinator.swift
//  ICO-visualizer
//
//  Created by Anonymous on 10/11/21.
//  Copyright © 2021 Anonymous. All rights reserved.
//

import Foundation

class ReelsViewCoordinator {
    private var delegate: ReelsViewControllerDelegate!
    
    public var videos: [ReelElement] = []
    
    private var cursor: Int = 1
    
    init(_ delegate: ReelsViewControllerDelegate) {
        self.delegate = delegate
    }
    
    func load(){
        switch UserPreferences.shared.reelSource {
        case .redgifs:
            self.fetchFromRedgifs()
        case .xxxtik:
            self.fetchFromXXXTik()
        case .tikporn:
            self.fetchFromTikPorn()
        }
    }
    
    func fetchFromRedgifs(){
        APIService.shared.fetchRedgifs(page: self.cursor) { response in
            switch response {
            case .success(let response):
                var users: [String: RedgifsUser] = [:]
                for user in response.users ?? [] {
                    if let name = user.username?.lowercased() { users[name] = user }
                }
                var result: [ReelElement] = []
                for gif in response.gifs ?? [] {
                    guard let url = gif.urls?.hd ?? gif.urls?.sd, URL(string: url) != nil else { continue }
                    let user = users[(gif.userName ?? "").lowercased()]
                    let profile = user?.profileUrl ?? gif.userName.map { "https://www.redgifs.com/users/\($0)" }
                    result.append(ReelElement(videoUrl: url, username: gif.userName, avatarUrl: user?.profileImageUrl, likes: gif.likes?.int, views: gif.views?.int, tags: gif.tags, verified: gif.verified, externalUrl: profile, duration: gif.duration?.int, width: gif.width?.int, height: gif.height?.int))
                }
                if result.isEmpty && self.videos.isEmpty {
                    self.delegate.showReelsError("No data found".localized)
                    return
                }
                let start = self.videos.count
                self.videos.append(contentsOf: result)
                let indexPaths = (start..<(start + result.count)).map { IndexPath(row: $0, section: 0) }
                self.delegate.reloadView(newIndexs: indexPaths)
            case .failure(let error):
                self.delegate.showReelsError(error.localizedDescription)
            }
        }
    }
    
    func fetchFromXXXTik(){
        APIService.shared.fetchTikFeeds(cursor: cursor) { response in
            switch response {
            case .success(let result):
                guard let posts = result.data?.posts else {
                    return
                }
                var row = self.videos.count - 1
                for post in posts {
                    var url: String? = nil
                    if post.redGifsVideoURL != nil {
                        url = post.redGifsVideoURL
                    }
                    else if post.vimeoURI != nil {
                        url = post.vimeoURI
                    }
                    var externalUrl: String? = nil
                    if let author = post.author?.name {
                        externalUrl = "https://xxxtik.com/@\(author.replacingOccurrences(of: " ", with: ""))"
                    }
                    let reel = ReelElement(videoUrl: url, username: post.author?.name, avatarUrl: nil, likes: post.count?.reactions, views: post.reactionInitial, tags: post.tags?.map({ $0.name ?? "" }), verified: post.author?.emailVerified, externalUrl: externalUrl ?? post.source, duration: nil, width: post.width, height: post.height)
                    if url != nil {
                        self.videos.append(reel)
                    }
                }
                
                var indexPathsToReload = [IndexPath]()
                let section = 0
                for _ in posts {
                    let indexPath = IndexPath(row: row, section: section)
                    row+=1
                    indexPathsToReload.append(indexPath)
                }
                self.delegate.reloadView(newIndexs: indexPathsToReload)
            case .failure(let error):
                self.delegate.showReelsError(error.localizedDescription)
            }
        }
    }
    
    func fetchFromTikPorn(){
        APIService.shared.fetchTikPornFeeds(count: 7) { response in
            switch response {
            case .success(let result):
                var row = self.videos.count - 1
                for item in result {
                    var username: String = ""
                    var externalUrl: String? = nil
                    if let producer = item.producerName{
                        username += producer
                        externalUrl = "https://tik-tok.porn/@\(producer.replacingOccurrences(of: " ", with: ""))"
                    }
                    if let star = item.pornstars?.first?.name {
                        username += "\n@\(star)"
                    }
                    let reel = ReelElement(videoUrl: item.fileurl, username: username, avatarUrl: nil, likes: Int(item.likeCount ?? "0"), views: nil, tags: item.tags?.map({ $0.name ?? "" }), verified: nil, externalUrl: externalUrl, duration: nil, width: nil, height: nil)
                    self.videos.append(reel)
                }
                var indexPathsToReload = [IndexPath]()
                let section = 0
                for _ in result {
                    let indexPath = IndexPath(row: row, section: section)
                    row+=1
                    indexPathsToReload.append(indexPath)
                }
                
                self.delegate.reloadView(newIndexs: indexPathsToReload)
            case .failure(let error):
                self.delegate.showReelsError(error.localizedDescription)
            }
        }
    }
    
    func reloadAll(){
        self.videos = []
        self.cursor = 1
        self.delegate.reloadCollection()
        self.load()
    }
    
    func loadMore(){
        self.cursor += 1
        self.load()
    }
}
