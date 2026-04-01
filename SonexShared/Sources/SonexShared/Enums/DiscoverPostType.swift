// MARK: DiscoverPostType
enum DiscoverPostType: String, Codable, CaseIterable {
    case forSale     = "for_sale"
    case wanted      = "wanted"
    case swap        = "swap"
    case popUp       = "pop_up"
    case digSession  = "dig_session"
    case announcement = "announcement"
}
