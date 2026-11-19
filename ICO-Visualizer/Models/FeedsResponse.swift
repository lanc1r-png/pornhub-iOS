//
//  FeedsResponse.swift
//  ICO-visualizer
//
//  Created by Anonymous on 10/11/21.
//  Copyright © 2021 Anonymous. All rights reserved.
//

import Foundation

// MARK: - FeedsResponse
struct FeedsResponse: Codable {
    let hotGifs: [HorizontalGIF]
    let hotCreators: [Creator]
    let hotImages: [HorizontalGIF]
    let newCreators: [Creator]
    let verifiedGifs, soundGifs, verifiedImages, verticalGifs: [HorizontalGIF]
    let longGifs, horizontalGifs: [HorizontalGIF]
}

// MARK: - HorizontalGIF
struct HorizontalGIF: Codable {
    let id: String?
    let createDate: Int?
    let hasAudio: Bool?
    let width, height, likes: Int?
    let tags: [String]?
    let verified: Bool?
    let views, duration: Int?
    let published: Bool?
    let urls: Urls?
    let userName: String?
    let type: Int?
    let avgColor: String?
    let gallery: String?
    let user: User?
}

// MARK: - Urls
struct Urls: Codable {
    let sd, hd: String?
    let gif: String?
    let poster: String?
    let thumbnail: String?
    let vthumbnail: String?
}

// MARK: - User
struct User: Codable {
    let creationtime, followers, following, gifs: Int?
    let name: String?
    let profileImageURL: String?
    let profileURL: String?
    let publishedGifs, subscription: Int?
    let url: String?
    let username: String?
    let verified: Bool?
    let views: Int?

    enum CodingKeys: String, CodingKey {
        case creationtime, followers, following, gifs, name
        case profileImageURL = "profileImageUrl"
        case profileURL = "profileUrl"
        case publishedGifs, subscription, url, username, verified, views
    }
}

// MARK: - Creator
struct Creator: Codable {
    let id, name: String?
    let followers, gifs: Int?
    let verified: Bool?
    let views: Int?
    let thumbnail: String?
    let poster: String?
    let preview: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, followers, gifs, verified, views, thumbnail, poster, preview
        case avatarURL = "avatarUrl"
    }
}



// MARK: - Redgifs v2 search (current API)

/// Decodes numbers that the API may send as Int, Double or String.
struct LooseNumber: Codable {
    let value: Double
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { value = Double(i) }
        else if let d = try? c.decode(Double.self) { value = d }
        else if let s = try? c.decode(String.self), let d = Double(s) { value = d }
        else { value = 0 }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
    var int: Int { Int(value) }
}

struct RedgifsGif: Codable {
    let id: String?
    let userName: String?
    let likes: LooseNumber?
    let views: LooseNumber?
    let duration: LooseNumber?
    let width: LooseNumber?
    let height: LooseNumber?
    let tags: [String]?
    let verified: Bool?
    let urls: Urls?
}

struct RedgifsUser: Codable {
    let username: String?
    let profileImageUrl: String?
    let profileUrl: String?
}

struct RedgifsSearchResponse: Codable {
    let gifs: [RedgifsGif]?
    let users: [RedgifsUser]?
}
