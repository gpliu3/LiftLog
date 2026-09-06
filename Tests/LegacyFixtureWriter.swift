import Foundation
import SwiftData

@main
struct LegacyFixtureWriter {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let container = try StoreFixture.container(at: url)
        try StoreFixture.populate(container.mainContext)
        try StoreFixture.fingerprint(container.mainContext).write(to: url.appendingPathExtension("json"))
        print("Created 611-record fixture with the released model definitions.")
    }
}
