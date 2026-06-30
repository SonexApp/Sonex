import Foundation

public enum ReleaseEdition: String, Codable, CaseIterable {
    case standard = "standard"
    case limitedEdition = "limited"
    case reissue = "reissue"
    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .limitedEdition: return "Limited Edition"
        case .reissue: return "Reissue"
        }
    }
}

public struct VinylEntry: Codable, Identifiable {
    public let id: String
    public let ownerId: String
    public var discogsId: String?
    public var nfcTagHash: String?
    public var title: String
    public var artist: String
    public var label: String?
    public var year: Int?
    public var pressing: String?
    public var format: String?
    public var mediaGrade: VinylGrade?
    public var gradeNotes: String?
    public var coverArtUrl: String?
    public var forSale: Bool
    public var askingPrice: Double?
    public let createdAt: String?
    public var catalogNumber: String?
    public var matrixCode: String?
    public var barcode: String?
    public var releaseEdition: ReleaseEdition
    public var editionNotes: String?
    public var sleeveGrade: VinylGrade?
    public var locationNote: String?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, label, year, pressing, format
        case ownerId      = "owner_id"
        case discogsId    = "discogs_id"
        case nfcTagHash   = "nfc_tag_hash"
        case mediaGrade   = "media_grade"
        case gradeNotes   = "grade_notes"
        case coverArtUrl  = "cover_art_url"
        case forSale      = "for_sale"
        case askingPrice  = "asking_price"
        case createdAt    = "created_at"
        case catalogNumber = "catalog_number" // Note: matches the typo in your DB schema
        case matrixCode   = "matrix_code"
        case barcode      = "barcode"
        case releaseEdition = "release_edition"
        case editionNotes = "edition_notes"
        case sleeveGrade  = "sleeve_grade"
        case locationNote = "location_note"
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
        mediaGrade: VinylGrade? = nil,
        gradeNotes: String? = nil,
        coverArtUrl: String? = nil,
        forSale: Bool = false,
        askingPrice: Double? = nil,
        createdAt: String? = nil,
        catalogNumber: String? = nil,
        matrixCode: String? = nil,
        barcode: String? = nil,
        releaseEdition: ReleaseEdition = .standard,
        editionNotes: String? = nil,
        sleeveGrade: VinylGrade? = nil,
        locationNote: String? = nil
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
        self.mediaGrade = mediaGrade
        self.gradeNotes = gradeNotes
        self.coverArtUrl = coverArtUrl
        self.forSale = forSale
        self.askingPrice = askingPrice
        self.createdAt = createdAt
        self.catalogNumber = catalogNumber
        self.matrixCode = matrixCode
        self.barcode = barcode
        self.releaseEdition = releaseEdition
        self.editionNotes = editionNotes
        self.sleeveGrade = sleeveGrade
        self.locationNote = locationNote
    }
}
