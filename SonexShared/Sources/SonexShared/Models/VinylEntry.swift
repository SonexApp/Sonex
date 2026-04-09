import Foundation

public struct VinylEntry: Codable, Identifiable {
    public let id: String
    let ownerId: String
    var discogsId: String?
    var nfcTagHash: String?
    var title: String
    var artist: String
    var label: String?
    var year: Int?
    var pressing: String?
    var format: String?
    var grade: VinylGrade?
    var gradeNotes: String?
    var coverArtUrl: String?
    var audioNoteUrl: String?
    public var forSale: Bool
    var askingPrice: Double?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, label, year, pressing, format, grade
        case ownerId      = "owner_id"
        case discogsId    = "discogs_id"
        case nfcTagHash   = "nfc_tag_hash"
        case gradeNotes   = "grade_notes"
        case coverArtUrl  = "cover_art_url"
        case audioNoteUrl = "audio_note_url"
        case forSale      = "for_sale"
        case askingPrice  = "asking_price"
        case createdAt    = "created_at"
    }
    
    public init(
        id: String = UUID().uuidString,
        ownerId: String,
        discogsId: String? = nil,
        nfcTagHash: String? = nil,
        title: String,
        artist: String,
        label: String? = nil,
        year: Int? = nil,
        pressing: String? = nil,
        format: String? = nil,
        grade: VinylGrade? = nil,
        gradeNotes: String? = nil,
        coverArtUrl: String? = nil,
        audioNoteUrl: String? = nil,
        forSale: Bool = false,
        askingPrice: Double? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.discogsId = discogsId
        self.nfcTagHash = nfcTagHash
        self.title = title
        self.artist = artist
        self.label = label
        self.year = year
        self.pressing = pressing
        self.format = format
        self.grade = grade
        self.gradeNotes = gradeNotes
        self.coverArtUrl = coverArtUrl
        self.audioNoteUrl = audioNoteUrl
        self.forSale = forSale
        self.askingPrice = askingPrice
        self.createdAt = createdAt
    }
}
