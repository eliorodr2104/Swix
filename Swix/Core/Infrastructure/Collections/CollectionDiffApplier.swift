//
//  CollectionDiffApplier.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import os

extension Array {

    /// Applies a batch of diffs in order, as one atomic update to the array.
    ///
    /// Indices from the SDK are always expected to be in range, but a stream can in principle
    /// race with a stale reset; rather than trap, an out of range index is logged and ignored so
    /// a bad diff degrades the list instead of crashing the app.
    mutating func applyDiffs(_ diffs: [CollectionDiff<Element>]) {
        for diff in diffs {
            apply(diff)
        }
    }

    private mutating func apply(_ diff: CollectionDiff<Element>) {
        // Read up front because a log interpolation is an escaping autoclosure, and that cannot
        // capture a mutating self to ask the array for its count.
        let currentCount = count

        switch diff {
        case .append(let elements)  : append(contentsOf: elements)
        case .clear                 : removeAll()
        case .pushFront(let element): insert(element, at: 0)
        case .pushBack(let element) : append(element)

        case .popFront:
            guard !isEmpty else {
                Log.infrastructure.warning(
                    "CollectionDiffApplier: popFront on empty array, ignored"
                )
                
                return
            }
            removeFirst()

        case .popBack:
            guard !isEmpty else {
                Log.infrastructure.warning(
                    "CollectionDiffApplier: popBack on empty array, ignored"
                )
                return
            }
            removeLast()

        case .insert(let index, let element):
            guard (0...count).contains(index) else {
                Log.infrastructure.warning("CollectionDiffApplier: insert index \(index) out of range (count \(currentCount)), ignored")
                return
            }
            insert(element, at: index)

        case .set(let index, let element):
            guard indices.contains(index) else {
                Log.infrastructure.warning("CollectionDiffApplier: set index \(index) out of range (count \(currentCount)), ignored")
                return
            }
            self[index] = element

        case .remove(let index):
            guard indices.contains(index) else {
                Log.infrastructure.warning("CollectionDiffApplier: remove index \(index) out of range (count \(currentCount)), ignored")
                return
            }
            remove(at: index)

        case .truncate(let length):
            guard length >= 0 else {
                Log.infrastructure.warning(
                    "CollectionDiffApplier: negative truncate length \(length), ignored"
                )
                return
            }
                
            if length < count {
                removeLast(count - length)
            }

        case .reset(let elements):
            self = elements
        }
    }
}
