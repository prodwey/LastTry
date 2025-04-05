import Foundation
import AVFoundation
import CoreData

struct Artist: Identifiable, Codable {
    var id: String
    var name: String
    var cpf: String?
    var rg: String?
    var dateOfBirth: Date?
    var email: String?
    var phone: String?
    var publisher: String?
    var recordingLabel: String?
}

// MARK: - CoreDataConvertible
extension Artist: CoreDataConvertible {
    typealias Entity = ArtistEntity
    
    func toEntity(in context: NSManagedObjectContext) -> ArtistEntity {
        ArtistEntity.createOrUpdate(from: self, in: context)
    }
    
    static func fromEntity(_ entity: ArtistEntity) -> Artist {
        entity.toModel()
    }
}

enum AudioFormat: String, Codable, CaseIterable {
    case wav = "WAV"
    case aac = "AAC"
    case amr = "AMR"
    case mp3 = "MP3"
    case mp4 = "MP4"
    case ogg = "OGG"
    case opus = "OPUS"
    case m4a = "M4A"
    
    var fileExtension: String {
        return self.rawValue.lowercased()
    }
    
    static func fromFileExtension(_ extension: String) -> AudioFormat? {
        return AudioFormat.allCases.first { $0.fileExtension == `extension`.lowercased() }
    }
}

struct Song: Identifiable, Codable {
    var id: String
    var name: String
    var fileURL: URL?
    var format: AudioFormat
    var artists: [Artist]
    var lyrics: String?
    var dateCreated: Date
    var fileSize: Int64? // In bytes
    var duration: TimeInterval? // In seconds
    var sessionId: String
    
    // Player related properties are not persisted
    var audioPlayer: AVAudioPlayer?
    
    enum CodingKeys: String, CodingKey {
        case id, name, fileURL, format, artists, lyrics, dateCreated, fileSize, duration, sessionId
    }
}

// MARK: - CoreDataConvertible
extension Song: CoreDataConvertible {
    typealias Entity = SongEntity
    
    func toEntity(in context: NSManagedObjectContext) -> SongEntity {
        SongEntity.createOrUpdate(from: self, in: context)
    }
    
    static func fromEntity(_ entity: SongEntity) -> Song {
        entity.toModel()
    }
}

class SongManager: ObservableObject {
    @Published var songs: [Song] = []
    
    // Reference to CoreData manager
    private let coreDataManager = CoreDataManager.shared
    
    func addSong(name: String, fileURL: URL, artists: [Artist], lyrics: String?, sessionId: String) {
        guard let format = AudioFormat.fromFileExtension(fileURL.pathExtension) else { return }
        
        // Get file size
        let fileSize = getFileSize(url: fileURL)
        
        // Get audio duration
        let duration = getAudioDuration(url: fileURL)
        
        let newSong = Song(
            id: UUID().uuidString,
            name: name,
            fileURL: fileURL,
            format: format,
            artists: artists,
            lyrics: lyrics,
            dateCreated: Date(),
            fileSize: fileSize,
            duration: duration,
            sessionId: sessionId
        )
        
        // Add song to array
        songs.append(newSong)
    }
    
    private func getFileSize(url: URL) -> Int64? {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resources.fileSize {
                return Int64(fileSize)
            }
        } catch {
            print("Error getting file size: \(error)")
        }
        return nil
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval? {
        // Create AVURLAsset
        let asset = AVURLAsset(url: url)
        
        // For simplicity, use the synchronous method which is still available
        // This avoids the async/await complexity for now
        return asset.duration.seconds
    }
    
    func searchSongs(query: String) -> [Song] {
        guard !query.isEmpty else { return songs }
        
        let lowercasedQuery = query.lowercased()
        return songs.filter { song in
            // Search by song name
            if song.name.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            // Search by artist name
            if song.artists.contains(where: { $0.name.lowercased().contains(lowercasedQuery) }) {
                return true
            }
            
            return false
        }
    }
} 
