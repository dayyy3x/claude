import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            TunnelRecord.self,
            PeerRecord.self,
            DeviceRecord.self,
        ])
        let config = ModelConfiguration(
            "UltronStore",
            schema: schema,
            groupContainer: .identifier(SharedConstants.appGroupID)
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to construct ModelContainer: \(error)")
        }
    }
}
