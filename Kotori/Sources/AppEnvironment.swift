import Observation
import KotoriKit

/// Composition root: everything the view tree needs, built once at launch.
@Observable @MainActor
final class AppEnvironment {
    let client = XClient()
}
