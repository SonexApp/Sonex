import Foundation

// MARK: - User Statistics Models

/// Friendship status enumeration
public enum FriendshipStatus: String, Codable, CaseIterable {
    case active = "active"
    case pending = "pending"
    case blocked = "blocked"
    case inactive = "inactive"
    case accepted =  "accepted"
    case following = "following"
    case declined = "declined"
}

/// Exchange status enumeration  
public enum ExchangeStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case cancelled = "cancelled"
    case completed = "completed"
    case disputed = "disputed"
    case countered = "countered"
}

/// Comprehensive statistics for a user's profile
public struct UserStats: Codable {
    public let cratesCount: Int
    public let followingCount: Int
    public let followersCount: Int
    public let exchangesCount: Int
    public let totalRecordsCount: Int
    
    public init(
        cratesCount: Int = 0,
        followingCount: Int = 0,
        followersCount: Int = 0,
        exchangesCount: Int = 0,
        totalRecordsCount: Int = 0
    ) {
        self.cratesCount = cratesCount
        self.followingCount = followingCount
        self.followersCount = followersCount
        self.exchangesCount = exchangesCount
        self.totalRecordsCount = totalRecordsCount
    }
    
    enum CodingKeys: String, CodingKey {
        case cratesCount = "crates_count"
        case followingCount = "following_count"
        case followersCount = "followers_count"
        case exchangesCount = "exchanges_count"
        case totalRecordsCount = "total_records_count"
    }
}

/// Individual stat item for display
public struct StatItem: Identifiable {
    public let id = UUID()
    public let value: Int
    public let title: String
    public let action: () -> Void
    
    init(value: Int, title: String, action: @escaping () -> Void) {
        self.value = value
        self.title = title
        self.action = action
    }
}

/// Friendship relationship for following/followers lists
public struct FriendshipRelation: Codable, Identifiable {
    public let id: UUID
    public let user: SonexUser
    public let status: FriendshipStatus
    public let isFollowing: Bool  // True if current user is following this user
    public let isFollower: Bool   // True if this user is following current user
    public let createdAt: String
    
    public init(
        id: UUID,
        user: SonexUser,
        status: FriendshipStatus,
        isFollowing: Bool,
        isFollower: Bool,
        createdAt: String
    ) {
        self.id = id
        self.user = user
        self.status = status
        self.isFollowing = isFollowing
        self.isFollower = isFollower
        self.createdAt = createdAt
    }
    
    // Custom decoding with fallbacks for missing data
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode ID, fallback to generating one if missing
        if let id = try? container.decode(UUID.self, forKey: .id) {
            self.id = id
        } else if let idString = try? container.decode(String.self, forKey: .id),
                  let uuid = UUID(uuidString: idString) {
            self.id = uuid
        } else {
            print("⚠️ FriendshipRelation: Missing or invalid ID, generating new one")
            self.id = UUID()
        }
        
        // Decode user - this is required
        self.user = try container.decode(SonexUser.self, forKey: .user)
        
        // Decode status with fallback
        self.status = (try? container.decode(FriendshipStatus.self, forKey: .status)) ?? .active
        
        // Decode boolean flags with fallbacks
        self.isFollowing = (try? container.decode(Bool.self, forKey: .isFollowing)) ?? false
        self.isFollower = (try? container.decode(Bool.self, forKey: .isFollower)) ?? false
        
        // Decode createdAt with fallback
        self.createdAt = (try? container.decode(String.self, forKey: .createdAt)) ?? ISO8601DateFormatter().string(from: Date())
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case user
        case status
        case isFollowing = "is_following"
        case isFollower = "is_follower"
        case createdAt = "created_at"
    }
}

/// Exchange summary for user's exchange history
public struct ExchangeSummary: Codable, Identifiable {
    public let id: String
    public let otherUser: SonexUser
    public let recordCount: Int
    public let totalPrice: Double?
    public let status: ExchangeStatus
    public let isSellerInExchange: Bool  // True if current user is the seller
    public let completedAt: String?
    
    public init(
        id: String,
        otherUser: SonexUser,
        recordCount: Int,
        totalPrice: Double?,
        status: ExchangeStatus,
        isSellerInExchange: Bool,
        completedAt: String?
    ) {
        self.id = id
        self.otherUser = otherUser
        self.recordCount = recordCount
        self.totalPrice = totalPrice
        self.status = status
        self.isSellerInExchange = isSellerInExchange
        self.completedAt = completedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case otherUser = "other_user"
        case recordCount = "record_count"
        case totalPrice = "total_price"
        case status
        case isSellerInExchange = "is_seller"
        case completedAt = "completed_at"
    }
}

// MARK: - Safe Decoding Extensions

extension Array where Element == FriendshipRelation {
    /// Safely decode an array of FriendshipRelation, filtering out any that fail to decode
    public static func safelyDecoded(from data: Data) -> [FriendshipRelation] {
        do {
            // Try normal decoding first
            return try JSONDecoder().decode([FriendshipRelation].self, from: data)
        } catch {
            print("⚠️ Failed to decode FriendshipRelation array normally, trying individual decode: \(error)")
            
            // If that fails, try to decode as array of JSON objects and decode individually
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    print("❌ Could not parse JSON as array of dictionaries")
                    return []
                }
                
                var validRelations: [FriendshipRelation] = []
                
                for (index, relationDict) in json.enumerated() {
                    do {
                        let relationData = try JSONSerialization.data(withJSONObject: relationDict)
                        let relation = try JSONDecoder().decode(FriendshipRelation.self, from: relationData)
                        validRelations.append(relation)
                    } catch {
                        print("⚠️ Skipping invalid FriendshipRelation at index \(index): \(error)")
                        continue
                    }
                }
                
                print("✅ Successfully decoded \(validRelations.count) out of \(json.count) relationships")
                return validRelations
                
            } catch {
                print("❌ Failed to decode FriendshipRelation array with fallback method: \(error)")
                return []
            }
        }
    }
}
