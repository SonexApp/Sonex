import Foundation

// MARK: VinylEntry
struct VinylEntry: Codable, Identifiable, Hashable {
    let id: RecordID
    let ownerID: UserID?
    let discogsID: String?
    let nfcTagHash: String?
    let title: String
    let artist: String
    let label: String?
    let year: Int?
    let pressing: String?
    let format: VinylFormat?
    let grade: VinylGrade?
    let gradeNotes: String?
    let coverArtURL: String?
    let audioNoteURL: String?
    let forSale: Bool
    let askingPrice: Decimal?
    let crateID: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID      = "owner_id"
        case discogsID    = "discogs_id"
        case nfcTagHash   = "nfc_tag_hash"
        case title
        case artist
        case label
        case year
        case pressing
        case format
        case grade
        case gradeNotes   = "grade_notes"
        case coverArtURL  = "cover_art_url"
        case audioNoteURL = "audio_note_url"
        case forSale      = "for_sale"
        case askingPrice  = "asking_price"
        case crateID      = "crate_id"
        case createdAt    = "created_at"
    }
}
