import XCTest
@testable import ShimKit

final class PreviewCacheTests: XCTestCase {
    func testLastSnapshotRemainsAvailableWhileRefreshIsDue() {
        var cache = PreviewCache<Int, String>(capacity: 2)
        let date = Date(timeIntervalSince1970: 100)
        cache.insert("first frame", for: 1, now: date)
        XCTAssertTrue(cache.isFresh(1, maxAge: 3, now: date.addingTimeInterval(2)))
        XCTAssertFalse(cache.isFresh(1, maxAge: 3, now: date.addingTimeInterval(4)))
        XCTAssertEqual(cache.value(for: 1), "first frame", "Stale frames must remain immediately available during refresh")
        cache.insert("new frame", for: 1, now: date.addingTimeInterval(5))
        XCTAssertEqual(cache.value(for: 1), "new frame")
    }
    func testCapacityEvictionClosurePruningAndPrivacyClear() {
        var cache = PreviewCache<Int, String>(capacity: 2)
        for key in 1...3 { cache.insert("frame", for: key, now: Date(timeIntervalSince1970: Double(key))) }
        XCTAssertNil(cache.value(for: 1))
        XCTAssertNotNil(cache.value(for: 2))
        cache.prune(to: [3])
        XCTAssertNil(cache.value(for: 2))
        XCTAssertNotNil(cache.value(for: 3))
        cache.removeAll()
        XCTAssertNil(cache.value(for: 3))
    }
}
