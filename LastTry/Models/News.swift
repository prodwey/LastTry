import Foundation
import CoreData

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

class NewsManager: ObservableObject {
    @Published var newsItems: [NewsItem] = []
    
    // Reference to CoreData manager
    private let coreDataManager = CoreDataManager.shared
    
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
    }
    
    func getNewsByCategory(category: NewsCategory) -> [NewsItem] {
        return newsItems.filter { $0.category == category }
            .sorted(by: { $0.publicationDate > $1.publicationDate })
    }
    
    func getLatestNews(limit: Int = 5) -> [NewsItem] {
        return newsItems.sorted(by: { $0.publicationDate > $1.publicationDate })
            .prefix(limit)
            .map { $0 }
    }
} 