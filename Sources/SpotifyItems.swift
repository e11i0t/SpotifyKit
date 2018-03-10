//
//  SpotifyItems.swift
//  SpotifyKit
//
//  Created by Marco Albera on 16/09/2017.
//

import Foundation

/**
 Item type for Spotify search query
 */
public enum SpotifyItemType: String, CodingKey {
    case track, album, artist, playlist, user
    
    enum SearchKey: String, CodingKey {
        case tracks, albums, artists, playlists, users
    }
    
    var searchKey: SearchKey {
        switch self {
        case .track:
            return .tracks
        case .album:
            return .albums
        case .artist:
            return .artists
        case .playlist:
            return .playlists
        case .user:
            return .users
        }
    }
}

struct SpotifyImage: Decodable {
    var url: String
}

// MARK: Items data types

public protocol SpotifyItem: Decodable {
    var id:   String { get }
    var uri:  String { get }
    var name: String { get }
    
    static var type: SpotifyItemType { get }
}

public protocol SpotifyTrackCollection {
    var collectionTracks: [SpotifyTrack]? { get }
}

public protocol SpotifySearchItem: SpotifyItem { }

public protocol SpotifyLibraryItem: SpotifyItem { }

public struct SpotifyUser: SpotifySearchItem {
    public var id:   String
    public var uri:  String
    public var name: String { return display_name ?? id }
    
    public static let type: SpotifyItemType = .user
    public var email: String?
    public var artUri: String { return images.first?.url ?? "" }
    
    //private
    var images:       [SpotifyImage]
    var display_name: String?
}

public struct SpotifyTrack: SpotifySearchItem, SpotifyLibraryItem {
    public var id:    String
    public var uri:   String
    public var name:  String
    
    public var album: SpotifyAlbum? // Simplified track objects are optional
    public var duration_ms: Int?
    public var artist: SpotifyArtist { return artists.first! }
    
    public static let type: SpotifyItemType = .track
    // private
    var artists = [SpotifyArtist]()
}

public struct SpotifyAlbum: SpotifySearchItem, SpotifyTrackCollection {
    struct Image: Decodable { var url: String }
    struct Tracks: Decodable { var items: [SpotifyTrack] }
    
    public var id:   String
    public var uri:  String
    public var name: String
    
    public static let type: SpotifyItemType = .album
    public var collectionTracks: [SpotifyTrack]? { return tracks?.items }
    public var artist: SpotifyArtist { return artists.first! }
    public var artSmallUri: String { return images.last!.url }
    public var artUri: String { return images.count > 2 ? images[1].url : images.first!.url }
    public var artLargeUri: String { return images.first!.url }
    
    // private
    var tracks: Tracks? // Track list is contained only in full album objects
    var images  = [Image]()
    var artists = [SpotifyArtist]()
}

public struct SpotifyPlaylist: SpotifySearchItem {
    struct Image: Decodable { var url: String }
    struct Tracks: Decodable {
        struct Item: Decodable { var track: SpotifyTrack }
        
        var items: [Item]?
        var href: String
        var total: Int
    }
    
    public var id:   String
    public var uri:  String
    public var name: String
    
    public var collectionTracks: [SpotifyTrack]? { return tracks.items?.map { $0.track } }
    public var tracksCount: Int { return tracks.total }
    public var tracksUri: String { return tracks.href }
    public var artSmallUri: String { return images.last!.url }
    public var artUri: String { return images.count > 2 ? images[1].url : images.first!.url }
    public var artLargeUri: String { return images.first!.url }
    
    public static var type: SpotifyItemType = .playlist
    
    // privates
    var tracks: Tracks
    var images  = [Image]()
}

public struct SpotifyArtist: SpotifySearchItem {
    public var id:   String
    public var uri:  String
    public var name: String
    
    public static var type: SpotifyItemType = .artist
}


//
// Objects response from API
//
public struct SpotifyCurrentItem: Decodable {
    public var progress_ms: Int
    public var is_playing: Bool
    public var item: SpotifyTrack
}

public struct SpotifyCurrentPlaylists: Decodable {
    public var collectionPlaylists: [SpotifyPlaylist] { return items }
    public var limit: Int
    public var total: Int
    public var offset: Int
    
    // private
    var items: [SpotifyPlaylist]
}

public struct SpotifyCurrentAlbums: Decodable {
    struct CurrentAlbum: Decodable {
        var added_at: String
        var album: SpotifyAlbum
    }
    
    public var collectionAlbums: [SpotifyAlbum] { return items.map { $0.album } }
    public var limit: Int
    public var total: Int
    public var offset: Int
    
    // private
    var items: [CurrentAlbum]
}


//
////
//

public struct SpotifyLibraryResponse<T> where T: SpotifyLibraryItem {
    struct SavedItem {
        var item: T?
    }
    
    // Playlists from user library come out directly as an array
    var unwrappedItems: [T]?
    
    // Tracks and albums from user library come wrapped inside a "saved item" object
    // that contains the saved item (keyed by type: "track" or "album")
    // and the save date
    var wrappedItems: [SavedItem]?
    
    public var items: [T] {
        if let wrap = wrappedItems {
            return wrap.flatMap { $0.item }
        }
        
        if let items = unwrappedItems {
            return items
        }
        
        return []
    }
}

extension SpotifyLibraryResponse.SavedItem: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SpotifyItemType.self)

        self.init(item: try? container.decode(T.self, forKey: T.type))
    }
}

extension SpotifyLibraryResponse: Decodable {
    enum Key: String, CodingKey {
        case items
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        
        switch T.type {
        case .track, .album:
            self.init(unwrappedItems: nil,
                      wrappedItems: try? container.decode([SavedItem].self,
                                                          forKey: .items))
            
        case .playlist:
            self.init(unwrappedItems: try? container.decode([T].self,
                                                            forKey: .items),
                      wrappedItems: nil)
        default:
            self.init(unwrappedItems: nil, wrappedItems: nil)
        }
    }
}

public struct SpotifyFindResponse<T> where T: SpotifySearchItem {
    public struct Results: Decodable {
        public var items: [T]
    }
    
    public var results: Results
}

extension SpotifyFindResponse: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SpotifyItemType.SearchKey.self)
        
        var results = Results(items: [])
        
        if let fetchedResults = try? container.decode(Results.self, forKey: T.type.searchKey) {
            results = fetchedResults
        }
        
        self.init(results: results)
    }
}
