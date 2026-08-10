//
//  CollectionDiffApplierTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


/// Exercises every `CollectionDiff` case, plus the out of range paths `applyDiffs` is supposed to
/// log and ignore rather than trap on.
@Suite("CollectionDiffApplier")
struct CollectionDiffApplierTests {

    @Test("append adds every element at the end, in order")
    func append() {
        var array = [1, 2]

        array.applyDiffs([.append([3, 4])])

        #expect(array == [1, 2, 3, 4])
    }

    @Test("clear empties a non-empty array")
    func clear() {
        var array = [1, 2, 3]

        array.applyDiffs([.clear])

        #expect(array.isEmpty)
    }

    @Test("pushFront inserts the element at index 0")
    func pushFront() {
        var array = [2, 3]

        array.applyDiffs([.pushFront(1)])

        #expect(array == [1, 2, 3])
    }

    @Test("pushBack appends a single element")
    func pushBack() {
        var array = [1, 2]

        array.applyDiffs([.pushBack(3)])

        #expect(array == [1, 2, 3])
    }

    @Test("popFront removes the first element")
    func popFront() {
        var array = [1, 2, 3]

        array.applyDiffs([.popFront])

        #expect(array == [2, 3])
    }

    @Test("popFront on an empty array is ignored rather than trapping")
    func popFrontOnEmptyArrayIsIgnored() {
        var array: [Int] = []

        array.applyDiffs([.popFront])

        #expect(array.isEmpty)
    }

    @Test("popBack removes the last element")
    func popBack() {
        var array = [1, 2, 3]

        array.applyDiffs([.popBack])

        #expect(array == [1, 2])
    }

    @Test("popBack on an empty array is ignored rather than trapping")
    func popBackOnEmptyArrayIsIgnored() {
        var array: [Int] = []

        array.applyDiffs([.popBack])

        #expect(array.isEmpty)
    }

    @Test("insert places the element at the given index, shifting the rest right")
    func insert() {
        var array = [1, 3]

        array.applyDiffs([.insert(index: 1, element: 2)])

        #expect(array == [1, 2, 3])
    }

    @Test("insert at exactly the array's count appends, matching Array.insert semantics")
    func insertAtCountAppends() {
        var array = [1, 2]

        array.applyDiffs([.insert(index: 2, element: 3)])

        #expect(array == [1, 2, 3])
    }

    @Test("insert out of range is ignored rather than trapping")
    func insertOutOfRangeIsIgnored() {
        var array = [1, 2]

        array.applyDiffs([.insert(index: 5, element: 99)])

        #expect(array == [1, 2])
    }

    @Test("set replaces the element at the given index")
    func set() {
        var array = [1, 2, 3]

        array.applyDiffs([.set(index: 1, element: 99)])

        #expect(array == [1, 99, 3])
    }

    @Test("set out of range is ignored rather than trapping")
    func setOutOfRangeIsIgnored() {
        var array = [1, 2, 3]

        array.applyDiffs([.set(index: 5, element: 99)])

        #expect(array == [1, 2, 3])
    }

    @Test("remove drops the element at the given index, shifting the rest left")
    func remove() {
        var array = [1, 2, 3]

        array.applyDiffs([.remove(index: 1)])

        #expect(array == [1, 3])
    }

    @Test("remove out of range is ignored rather than trapping")
    func removeOutOfRangeIsIgnored() {
        var array = [1, 2, 3]

        array.applyDiffs([.remove(index: 5)])

        #expect(array == [1, 2, 3])
    }

    @Test("truncate drops every element from length onward")
    func truncate() {
        var array = [1, 2, 3, 4]

        array.applyDiffs([.truncate(length: 2)])

        #expect(array == [1, 2])
    }

    @Test("truncate to a length not shorter than the array is a no-op")
    func truncateNotShorterThanArrayIsNoOp() {
        var array = [1, 2]

        array.applyDiffs([.truncate(length: 5)])

        #expect(array == [1, 2])
    }

    @Test("truncate with a negative length is ignored rather than trapping")
    func truncateWithNegativeLengthIsIgnored() {
        var array = [1, 2, 3]

        array.applyDiffs([.truncate(length: -1)])

        #expect(array == [1, 2, 3])
    }

    @Test("reset replaces the whole array")
    func reset() {
        var array = [1, 2, 3]

        array.applyDiffs([.reset([9, 8])])

        #expect(array == [9, 8])
    }

    @Test("a batch of diffs applies in order, as one cumulative update")
    func batchAppliesInOrder() {
        var array = [1, 2, 3]

        array.applyDiffs([
            .pushBack(4),
            .remove(index: 0),
            .set(index: 0, element: 20)
        ])

        #expect(array == [20, 3, 4])
    }
}
