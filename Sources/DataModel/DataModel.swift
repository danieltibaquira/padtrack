import Foundation
import CoreData

/// DataModel module exports
/// 
/// This module provides Core Data entity definitions for the DigitonePad application.
/// All entities are manually created Swift classes with proper Core Data integration.
///
/// ## Core Entities
/// 
/// - `Project`: Top-level container for patterns, kits, and presets
/// - `Pattern`: Sequence containers with tracks and timing information
/// - `Track`: Individual instrument tracks within patterns
/// - `Kit`: Sample and instrument collections
/// - `Preset`: Parameter configurations for synthesis
/// - `Trig`: Individual trigger events within tracks
///
/// ## Usage
/// 
/// ```swift
/// import DataModel
/// 
/// let project = Project(context: context)
/// let pattern = Pattern(context: context)
/// project.addToPatterns(pattern)
/// ```

// Re-export all Core Data entities for easy access
@_exported import struct Foundation.Date
@_exported import struct Foundation.UUID
@_exported import class CoreData.NSManagedObject
@_exported import class CoreData.NSManagedObjectContext

// Entity classes are automatically available when importing DataModel
// No need to explicitly re-export as they're already public