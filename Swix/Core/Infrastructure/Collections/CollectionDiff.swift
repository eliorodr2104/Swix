//
//  CollectionDiff.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// A single incremental change to an ordered collection.
///
/// The SDK reports both the room list and every timeline as a stream of diffs shaped exactly
/// like this (eleven cases, same semantics), so one generic type and one applier serve both.
enum CollectionDiff<Element> {

    case append([Element])
    case clear
    case pushFront(Element)
    case pushBack(Element)
    case popFront
    case popBack
    case insert(index: Int, element: Element)
    case set(index: Int, element: Element)
    case remove(index: Int)
    case truncate(length: Int)
    case reset([Element])
}
