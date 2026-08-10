//
//  FakeTimelineItem.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// A `TimelineItem` built with the SDK's own `noHandle` escape hatch, so `TimelineEntryMapper` can
/// be exercised without a live Rust timeline behind it.
///
/// The real class only exists as an opaque handle into the FFI, but the SDK ships this exact
/// constructor "for fakes in tests, mostly": with no handle, `deinit` skips the FFI free call, and
/// overriding the four `open` accessors is all `TimelineEntryMapper.makeEntry(from:ownUserID:)`
/// ever calls on it.
///
/// The class is `nonisolated` rather than left to the module's default MainActor isolation, because
/// every initializer and accessor below has to match `TimelineItem`'s own nonisolated ones.
nonisolated final class FakeTimelineItem: TimelineItem {

    private let event: EventTimelineItem?

    private let virtual: VirtualTimelineItem?

    private let uniqueID: String

    init(
        event: EventTimelineItem,
        id   : String
    ) {

        self.event = event
        self.virtual = nil
        self.uniqueID = id

        super.init(noHandle: TimelineItem.NoHandle())
    }

    init(
        virtual: VirtualTimelineItem,
        id     : String
    ) {

        self.event = nil
        self.virtual = virtual
        self.uniqueID = id

        super.init(noHandle: TimelineItem.NoHandle())
    }

    required init(unsafeFromHandle handle: UInt64) {
        fatalError("FakeTimelineItem is only ever built through init(event:id:) or init(virtual:id:)")
    }

    override func asEvent() -> EventTimelineItem? {
        event
    }

    override func asVirtual() -> VirtualTimelineItem? {
        virtual
    }

    override func fmtDebug() -> String {
        "FakeTimelineItem(\(uniqueID))"
    }

    override func uniqueId() -> TimelineUniqueId {
        TimelineUniqueId(id: uniqueID)
    }
}
