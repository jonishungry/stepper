//
//  PersistenceController.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/22/25.
//

import CoreData
import Foundation

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "StepHistory")
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data error: \(error)")
            }
        }
    }
    
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            try? context.save()
        }
    }
}

// MARK: - Core Data Model Extensions
extension StepHistoryEntity {
    static func fetchOrCreate(for date: Date, in context: NSManagedObjectContext) -> StepHistoryEntity {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let request: NSFetchRequest<StepHistoryEntity> = StepHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)
        
        if let existing = try? context.fetch(request).first {
            return existing
        } else {
            let new = StepHistoryEntity(context: context)
            new.date = startOfDay
            new.steps = 0
            new.targetSteps = 10000
            return new
        }
    }
    
    static func averageStepsForWeekday(_ weekday: Int, in context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<StepHistoryEntity> = StepHistoryEntity.fetchRequest()
        
        // Get all records for this weekday (1=Sunday, 2=Monday, etc.)
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
        
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", thirtyDaysAgo as NSDate, now as NSDate)
        
        if let results = try? context.fetch(request) {
            let weekdaySteps = results.filter { entity in
                guard let date = entity.date else { return false }
                return calendar.component(.weekday, from: date) == weekday
            }.map { Int($0.steps) }
            
            if weekdaySteps.isEmpty { return 0 }
            return weekdaySteps.reduce(0, +) / weekdaySteps.count
        }
        
        return 0
    }
}
