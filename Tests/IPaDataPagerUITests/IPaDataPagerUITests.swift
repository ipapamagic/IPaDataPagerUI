import XCTest
import UIKit
@testable import IPaDataPagerUI

/// Mirrors the item type real callers use: the loading item has one fixed identity,
/// independent of the section it is appended to.
private struct TestItem: Hashable, IPaDataPagerItemType, Sendable {
    typealias SectionType = Int
    static let loadingSection = 99
    var section: Int
    var index: Int
    var isLoadingType: Bool {
        return self.section == TestItem.loadingSection
    }
    static func createLoadingItem(for section: Int) -> TestItem {
        return TestItem(section: TestItem.loadingSection, index: 0)
    }
}

/// Stands in for a pager bound to a diffable data source, with the data source's snapshot
/// kept in memory so tests can read and change it the way UIKit would.
private class MockPager: IPaDataPagerUI<Int, TestItem, AnyObject, AnyObject> {
    var dataSourceSnapshot = NSDiffableDataSourceSnapshot<Int, TestItem>()
    var applyCount = 0
    var loadHandler: (@MainActor (Int, MockPager) async -> PageInfo)!

    override func createCurrentSnapshot() -> NSDiffableDataSourceSnapshot<Int, TestItem> {
        return self.dataSourceSnapshot
    }
    override func applySnapshot() {
        self.applyCount += 1
        self.dataSourceSnapshot = self.currentSnapshot
    }
    @MainActor
    override func loadData(_ page: Int) async -> PageInfo {
        return await self.loadHandler(page, self)
    }
}

/// Lets a test hold a `loadData(_:)` call open and release it at a chosen moment.
@MainActor
private final class LoadGate {
    var callCount = 0
    var continuations: [Int: CheckedContinuation<Void, Never>] = [:]
}

final class IPaDataPagerUITests: XCTestCase {

    @MainActor
    private func makePager(section: Int, sections: [Int]) -> MockPager {
        let pager = MockPager(section)
        var snapshot = NSDiffableDataSourceSnapshot<Int, TestItem>()
        snapshot.appendSections(sections)
        pager.dataSourceSnapshot = snapshot
        pager.currentSnapshot = snapshot
        return pager
    }

    /// Puts a loading item in place the way `resetLoading()` does, so `loadNextPage()` starts
    /// from the state a real caller reaches.
    @MainActor
    private func primeLoadingItem(_ pager: MockPager) {
        let loadingItem = pager.createLoadingItem()
        pager.appendItems([loadingItem], toSection: pager.section)
        pager.applySnapshot()
        pager.applyCount = 0
    }

    /// A `loadData(_:)` that rebuilds every section itself and only reports the paged section,
    /// which is how the search screen in Hakka uses the pager.
    @MainActor
    private func rebuildAllSections(_ pager: MockPager, djCount: Int, programCount: Int, audioCount: Int, totalPage: Int) -> MockPager.PageInfo {
        pager.deleteAllItems()
        pager.appendSections([0, 1, 2])
        pager.appendItems((0..<djCount).map { TestItem(section: 0, index: $0) }, toSection: 0)
        pager.appendItems((0..<programCount).map { TestItem(section: 1, index: $0) }, toSection: 1)
        pager.reloadSections([0, 1, 2])
        return MockPager.PageInfo(currentPage: 1,
                                  totalPage: totalPage,
                                  datas: (0..<audioCount).map { TestItem(section: 2, index: $0) })
    }

    // MARK: -

    /// The regression from 2.0.1: sections that `loadData(_:)` rebuilt were wiped out because
    /// `loadNextPage()` re-read the data source after loading.
    @MainActor
    func testSectionsRebuiltByLoadDataAreKept() async {
        let pager = makePager(section: 2, sections: [0, 1, 2])
        primeLoadingItem(pager)
        pager.loadHandler = { _, pager in
            return self.rebuildAllSections(pager, djCount: 2, programCount: 3, audioCount: 4, totalPage: 2)
        }

        await pager.loadNextPage()

        let snapshot = pager.dataSourceSnapshot
        XCTAssertEqual(snapshot.sectionIdentifiers, [0, 1, 2])
        XCTAssertEqual(snapshot.numberOfItems(inSection: 0), 2, "DJ section must survive loadData(_:)")
        XCTAssertEqual(snapshot.numberOfItems(inSection: 1), 3, "Program section must survive loadData(_:)")
        // 4 audio rows plus the loading item for page 2.
        XCTAssertEqual(snapshot.numberOfItems(inSection: 2), 5)
        XCTAssertEqual(pager.applyCount, 1)
    }

    /// Keeps the fix 2.0.1 was made for: deleting the loading item must not be attempted when
    /// the snapshot no longer holds it, which is the "snapshot invalid" crash.
    @MainActor
    func testLoadingItemAlreadyClearedByLoadDataIsNotDeletedTwice() async {
        let pager = makePager(section: 2, sections: [0, 1, 2])
        primeLoadingItem(pager)
        XCTAssertNotNil(pager.loadingIdentifier)
        // deleteAllItems() inside loadData(_:) drops the loading item the pager still tracks.
        pager.loadHandler = { _, pager in
            return self.rebuildAllSections(pager, djCount: 1, programCount: 1, audioCount: 1, totalPage: 1)
        }

        await pager.loadNextPage()

        let snapshot = pager.dataSourceSnapshot
        XCTAssertNil(pager.loadingIdentifier)
        XCTAssertFalse(snapshot.itemIdentifiers.contains(where: { $0.isLoadingType }))
        XCTAssertEqual(snapshot.numberOfItems(inSection: 2), 1)
    }

    /// When `loadData(_:)` does not touch the snapshot, the data source is still re-read after
    /// loading, so changes made elsewhere while the page was in flight are not dropped.
    @MainActor
    func testDataSourceIsRereadWhenLoadDataLeavesSnapshotAlone() async {
        let pager = makePager(section: 0, sections: [0])
        primeLoadingItem(pager)
        pager.loadHandler = { _, pager in
            // Something outside the pager changes the data source during the load.
            var changed = pager.dataSourceSnapshot
            changed.appendSections([7])
            changed.appendItems([TestItem(section: 7, index: 0)], toSection: 7)
            pager.dataSourceSnapshot = changed
            return MockPager.PageInfo(currentPage: 1, totalPage: 1, datas: [TestItem(section: 0, index: 0)])
        }

        await pager.loadNextPage()

        let snapshot = pager.dataSourceSnapshot
        XCTAssertTrue(snapshot.sectionIdentifiers.contains(7), "concurrent data source change must not be lost")
        XCTAssertEqual(snapshot.numberOfItems(inSection: 0), 1)
        XCTAssertFalse(snapshot.itemIdentifiers.contains(where: { $0.isLoadingType }))
    }

    /// Loading page 2 must not duplicate sections or leave a second loading item behind.
    @MainActor
    func testSecondPageDoesNotDuplicateSectionsOrLoadingItem() async {
        let pager = makePager(section: 2, sections: [0, 1, 2])
        primeLoadingItem(pager)
        pager.loadHandler = { page, pager in
            if page == 1 {
                return self.rebuildAllSections(pager, djCount: 2, programCount: 2, audioCount: 3, totalPage: 2)
            }
            // Page 2 only reports new rows, offset past what is already shown.
            let shown = pager.numberOfItems(inSection: 2)
            return MockPager.PageInfo(currentPage: 2,
                                      totalPage: 2,
                                      datas: (0..<3).map { TestItem(section: 2, index: $0 + shown) })
        }

        await pager.loadNextPage()
        XCTAssertEqual(pager.dataSourceSnapshot.sectionIdentifiers, [0, 1, 2])
        await pager.loadNextPage()

        let snapshot = pager.dataSourceSnapshot
        XCTAssertEqual(snapshot.sectionIdentifiers, [0, 1, 2], "sections must not be duplicated by page 2")
        XCTAssertEqual(snapshot.numberOfItems(inSection: 0), 2)
        XCTAssertEqual(snapshot.numberOfItems(inSection: 1), 2)
        // 3 rows from page 1 and 3 from page 2, with the loading item gone on the last page.
        XCTAssertEqual(snapshot.numberOfItems(inSection: 2), 6)
        XCTAssertFalse(snapshot.itemIdentifiers.contains(where: { $0.isLoadingType }))
        XCTAssertNil(pager.loadingIdentifier)
    }

    /// Re-searching while a page is in flight must drop the earlier result, instead of merging
    /// it into the new search and appending identifiers the new search already added.
    @MainActor
    func testResultFromPreviousLoadingSessionIsDiscarded() async {
        let pager = makePager(section: 2, sections: [0, 1, 2])
        let gate = LoadGate()
        pager.loadHandler = { _, pager in
            gate.callCount += 1
            let call = gate.callCount
            await withCheckedContinuation { continuation in
                gate.continuations[call] = continuation
            }
            return MockPager.PageInfo(currentPage: 1, totalPage: 1, datas: [TestItem(section: 2, index: 0)])
        }

        let first = Task { @MainActor in await pager.loadNextPage() }
        while gate.continuations[1] == nil { await Task.yield() }

        // A new search starts before the first one came back.
        pager.resetLoading(false)
        let second = Task { @MainActor in await pager.loadNextPage() }
        while gate.continuations[2] == nil { await Task.yield() }

        // The stale page arrives while the new session is still loading the same page number.
        gate.continuations[1]!.resume()
        await first.value
        XCTAssertEqual(pager.applyCount, 0, "a result from the previous session must not be applied")
        XCTAssertEqual(pager.dataSourceSnapshot.numberOfItems(inSection: 2), 0)

        gate.continuations[2]!.resume()
        await second.value
        XCTAssertEqual(pager.applyCount, 1)
        XCTAssertEqual(pager.dataSourceSnapshot.numberOfItems(inSection: 2), 1)
    }

    /// `resetLoading(false)` keeps the snapshot usable, so `loadData(_:)` never sees a nil one.
    @MainActor
    func testResetLoadingWithoutInitialLoadKeepsSnapshot() {
        let pager = makePager(section: 2, sections: [0, 1, 2])
        pager.currentSnapshot = nil
        pager.resetLoading(false)
        XCTAssertNotNil(pager.currentSnapshot)
        XCTAssertEqual(pager.sectionIdentifiers, [0, 1, 2])
        XCTAssertEqual(pager.applyCount, 0)
    }
}
