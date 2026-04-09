import Foundation


// MARK: Crate
public struct Crate: Codable, Identifiable {
    public var id: String = UUID().uuidString
    public var owner_id: String? = nil
    public var name: String = ""
    public var sortOrder: Int = 0
    public var createdAt: String? = ""
    public var vinyl_entry_ids: [String] = []
    public var for_sale: Bool = false

    /// Protected system crate — cannot be renamed or deleted
    var isUnsorted: Bool { name == "Unsorted" }

    enum CodingKeys: String, CodingKey {
        case id, name
        case owner_id   = "owner_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case vinyl_entry_ids = "vinyl_entry_ids"
        case for_sale = "for_sale"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        owner_id = try container.decodeIfPresent(String.self, forKey: .owner_id)
        name = try container.decode(String.self, forKey: .name)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        for_sale = try container.decode(Bool.self, forKey: .for_sale)
        
        // Handle vinyl_entry_ids being null in the database
        vinyl_entry_ids = try container.decodeIfPresent([String].self, forKey: .vinyl_entry_ids) ?? []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(owner_id, forKey: .owner_id)
        try container.encode(name, forKey: .name)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encode(vinyl_entry_ids, forKey: .vinyl_entry_ids)
        try container.encode(for_sale, forKey: .for_sale)
    }
    
    public init(owner_id: String, name: String, sortOrder: Int, createdAt: String, vinyl_entry_ids: [String], for_sale: Bool){
        self.owner_id = owner_id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.vinyl_entry_ids = vinyl_entry_ids
        self.for_sale = for_sale
    }
}
