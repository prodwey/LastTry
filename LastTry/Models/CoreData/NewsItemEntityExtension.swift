import Foundation
import CoreData

extension NewsItemEntity {
    
    // Convert from NewsItemEntity (CoreData) to NewsItem (Model)
    func toModel() -> NewsItem {
        return NewsItem(
            id: self.id ?? UUID().uuidString,
            title: self.title ?? "",
            content: self.content ?? "",
            source: self.source ?? "",
            url: self.url,
            imageURL: self.imageURL,
            publicationDate: self.publicationDate ?? Date(),
            category: NewsCategory(rawValue: self.category ?? NewsCategory.global.rawValue) ?? .global
        )
    }
    
    // Create or update NewsItemEntity from NewsItem model
    static func createOrUpdate(from model: NewsItem, in context: NSManagedObjectContext) -> NewsItemEntity {
        // Try to find existing entity with matching ID
        let fetchRequest: NSFetchRequest<NewsItemEntity> = NewsItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", model.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            // Use existing entity or create new one
            let entity = results.first ?? NewsItemEntity(context: context)
            
            // Update properties
            entity.id = model.id
            entity.title = model.title
            entity.content = model.content
            entity.source = model.source
            entity.url = model.url
            entity.imageURL = model.imageURL
            entity.publicationDate = model.publicationDate
            entity.category = model.category.rawValue
            
            return entity
        } catch {
            print("Error fetching NewsItemEntity: \(error)")
            // If fetch fails, create new entity
            let entity = NewsItemEntity(context: context)
            entity.id = model.id
            entity.title = model.title
            entity.content = model.content
            entity.source = model.source
            entity.url = model.url
            entity.imageURL = model.imageURL
            entity.publicationDate = model.publicationDate
            entity.category = model.category.rawValue
            
            return entity
        }
    }
} 