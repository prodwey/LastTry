import Foundation
import CoreData

// Custom error types for news management
enum NewsError: Error, LocalizedError, Equatable {
    case itemNotFound(String)
    case failedToFetch(String)
    case failedToSave(String)
    case failedToLoad(String)
    case invalidResponse(String)
    case networkError(String)
    case parsingError(String)
    case serverError(Int)
    case rateLimitExceeded
    case coreDataError(String)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound(let message):
            return "News item not found: \(message)"
        case .failedToFetch(let message):
            return "Failed to fetch news: \(message)"
        case .failedToSave(let message):
            return "Failed to save news: \(message)"
        case .failedToLoad(let message):
            return "Failed to load news: \(message)"
        case .invalidResponse(let message):
            return "Invalid server response: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError(let message):
            return "Error parsing data: \(message)"
        case .serverError(let statusCode):
            return "Server error with status code: \(statusCode)"
        case .rateLimitExceeded:
            return "API rate limit exceeded, try again later"
        case .coreDataError(let message):
            return "Database error: \(message)"
        }
    }
    
    // Implementation of Equatable for cases with associated values
    static func == (lhs: NewsError, rhs: NewsError) -> Bool {
        switch (lhs, rhs) {
        case (.itemNotFound(let lhs), .itemNotFound(let rhs)):
            return lhs == rhs
        case (.failedToFetch(let lhs), .failedToFetch(let rhs)):
            return lhs == rhs
        case (.failedToSave(let lhs), .failedToSave(let rhs)):
            return lhs == rhs
        case (.failedToLoad(let lhs), .failedToLoad(let rhs)):
            return lhs == rhs
        case (.invalidResponse(let lhs), .invalidResponse(let rhs)):
            return lhs == rhs
        case (.networkError(let lhs), .networkError(let rhs)):
            return lhs == rhs
        case (.parsingError(let lhs), .parsingError(let rhs)):
            return lhs == rhs
        case (.serverError(let lhs), .serverError(let rhs)):
            return lhs == rhs
        case (.rateLimitExceeded, .rateLimitExceeded):
            return true
        case (.coreDataError(let lhs), .coreDataError(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

enum NewsCategory: String, CaseIterable, Identifiable, Codable {
    case brazil = "Brazil"
    case global = "Global"
    
    var id: String { self.rawValue }
}

struct NewsItem: Identifiable, Codable {
    var id: String
    var title: String
    var content: String
    var source: String
    var url: URL?
    var imageURL: URL?
    var publicationDate: Date
    var category: NewsCategory
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, source, url, imageURL, publicationDate, category
    }
    
    init(id: String, title: String, content: String, source: String, url: URL?, imageURL: URL?, publicationDate: Date, category: NewsCategory) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.url = url
        self.imageURL = imageURL
        self.publicationDate = publicationDate
        self.category = category
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        source = try container.decode(String.self, forKey: .source)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        publicationDate = try container.decode(Date.self, forKey: .publicationDate)
        category = try container.decode(NewsCategory.self, forKey: .category)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encode(publicationDate, forKey: .publicationDate)
        try container.encode(category, forKey: .category)
    }
}

// MARK: - CoreDataConvertible
extension NewsItem: CoreDataConvertible {
    typealias Entity = NewsItemEntity
    
    func toEntity(in context: NSManagedObjectContext) -> NewsItemEntity {
        NewsItemEntity.createOrUpdate(from: self, in: context)
    }
    
    static func fromEntity(_ entity: NewsItemEntity) -> NewsItem {
        entity.toModel()
    }
}

class NewsManager: ObservableObject, NewsManagerProtocol {
    // MARK: - Singleton
    
    /// Shared instance for global access
    static let shared = NewsManager()
    
    // MARK: - Published Properties
    
    @Published var newsItems: [NewsItem] = []
    @Published var newsError: NewsError? = nil
    
    // MARK: - Private Properties
    
    // Service dependencies
    private let coreDataManager = CoreDataManager.shared
    private let errorService: ErrorHandlingServiceProtocol
    
    // MARK: - Initialization
    
    /// Private initializer for singleton pattern
    private init() {
        print("NewsManager: Initializing shared instance")
        self.errorService = ServiceLocator.shared.resolve(ErrorHandlingServiceProtocol.self) ?? ErrorHandlingService.shared
        fetchNews()
    }
    
    /// Dependency injection initializer for testing
    init(errorService: ErrorHandlingServiceProtocol) {
        print("NewsManager: Initializing with custom dependencies")
        self.errorService = errorService
        // Don't automatically fetch news in test environment
    }
    
    // MARK: - Public Methods
    
    /// Fetch news from the server or generate sample data
    func fetchNews() {
        // In a real app, this would make an API call to fetch news
        // For demo purposes, we'll create some sample news items
        
        let brazilNews: [NewsItem] = [
            NewsItem(
                id: UUID().uuidString,
                title: "New Bossa Nova Festival Announced in Rio",
                content: "The annual Bossa Nova Festival will take place next month in Rio de Janeiro, featuring top artists from around Brazil.",
                source: "Música Brasileira Today",
                url: URL(string: "https://example.com/news/1"),
                imageURL: URL(string: "https://example.com/images/news1.jpg"),
                publicationDate: Date().addingTimeInterval(-86400), // Yesterday
                category: .brazil
            ),
            NewsItem(
                id: UUID().uuidString,
                title: "São Paulo Music Production Hub Expands",
                content: "The leading music production hub in São Paulo is expanding its facilities to accommodate more artists and producers.",
                source: "Estúdio Brasil",
                url: URL(string: "https://example.com/news/2"),
                imageURL: URL(string: "https://example.com/images/news2.jpg"),
                publicationDate: Date().addingTimeInterval(-172800), // 2 days ago
                category: .brazil
            )
        ]
        
        let globalNews: [NewsItem] = [
            NewsItem(
                id: UUID().uuidString,
                title: "New AI Music Production Tool Launched",
                content: "A revolutionary AI-powered music production tool has been launched, allowing artists to create professional-quality tracks more easily.",
                source: "Music Tech Weekly",
                url: URL(string: "https://example.com/news/3"),
                imageURL: URL(string: "https://example.com/images/news3.jpg"),
                publicationDate: Date().addingTimeInterval(-43200), // 12 hours ago
                category: .global
            ),
            NewsItem(
                id: UUID().uuidString,
                title: "Global Music Industry Revenue Up 10%",
                content: "The global music industry has reported a 10% increase in revenue, driven by streaming and live performances.",
                source: "Industry Insights",
                url: URL(string: "https://example.com/news/4"),
                imageURL: URL(string: "https://example.com/images/news4.jpg"),
                publicationDate: Date().addingTimeInterval(-129600), // 1.5 days ago
                category: .global
            )
        ]
        
        newsItems = brazilNews + globalNews
        
        // In a real app, we would handle network errors
        // self.newsError = .networkError("Failed to fetch news")
        // errorService.reportError(self.newsError!)
    }
    
    /// Get news filtered by category
    func getNewsByCategory(category: NewsCategory) -> [NewsItem] {
        return newsItems.filter { $0.category == category }
    }
    
    /// Get the most recent news item
    func getMostRecentNews() -> NewsItem? {
        return newsItems.sorted(by: { $0.publicationDate > $1.publicationDate }).first
    }
} 