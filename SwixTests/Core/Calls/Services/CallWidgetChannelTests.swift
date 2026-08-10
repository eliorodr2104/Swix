//
//  CallWidgetChannelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


@Suite("CallWidgetChannel")
struct CallWidgetChannelTests {

    @Test("start() pumps every message the driver receives into messagesToWebView, in order")
    func pumpsIncomingMessagesInOrder() async {
        let handle = MockWidgetDriverHandle(messagesToDeliver: ["{\"a\":1}", "{\"b\":2}"])
        let channel = Self.makeChannel(handle: handle)

        channel.start()

        let messages = await StreamProbe.collect(from: channel.messagesToWebView, count: 2)

        #expect(messages == [
            CallWidgetMessage(json: "{\"a\":1}"),
            CallWidgetMessage(json: "{\"b\":2}")
        ])
    }

    @Test("start() drops whatever the driver hands back that is not a valid CallWidgetMessage")
    func dropsInvalidMessages() async {
        let handle = MockWidgetDriverHandle(messagesToDeliver: ["", "{\"ok\":true}"])
        let channel = Self.makeChannel(handle: handle)

        channel.start()

        let messages = await StreamProbe.collect(from: channel.messagesToWebView, count: 1)

        #expect(messages == [CallWidgetMessage(json: "{\"ok\":true}")])
    }

    @Test("start() runs the widget driver's own long running task")
    func startsTheDriver() async {
        let driver = MockWidgetDriver()
        let channel = Self.makeChannel(driver: driver)

        channel.start()

        await Eventually.isTrue { driver.runCallCount == 1 }

        #expect(driver.runCallCount == 1)
    }

    @Test("onDriverStopped fires exactly once when recv() returns nil")
    func onDriverStoppedFiresOnce() async {
        let handle = MockWidgetDriverHandle(messagesToDeliver: ["{\"x\":1}"])
        let channel = Self.makeChannel(handle: handle)

        var stopCount = 0
        channel.onDriverStopped = { stopCount += 1 }

        channel.start()

        await Eventually.isTrue { stopCount == 1 }

        #expect(stopCount == 1)
    }

    @Test("post(fromWebView:) forwards the message to the driver handle and returns its answer")
    func postForwardsToTheHandle() async {
        let handle = MockWidgetDriverHandle()
        let channel = Self.makeChannel(handle: handle)

        let accepted = await channel.post(fromWebView: CallWidgetMessage(json: "{\"out\":1}")!)

        #expect(accepted)
        #expect(handle.sentMessages == ["{\"out\":1}"])
    }

    @Test("post(fromWebView:) returns false once the driver handle reports it stopped")
    func postReturnsFalseWhenHandleStopped() async {
        let handle = MockWidgetDriverHandle()
        handle.sendReturnValue = false

        let channel = Self.makeChannel(handle: handle)

        let accepted = await channel.post(fromWebView: CallWidgetMessage(json: "{\"out\":1}")!)

        #expect(!accepted)
    }

    @Test("stop() finishes messagesToWebView even while the driver is still running")
    func stopFinishesTheOutgoingStreamWhileRunning() async {
        let handle = MockWidgetDriverHandle(blocksForever: true)
        let channel = Self.makeChannel(handle: handle)

        channel.start()
        channel.stop()

        let messages = await StreamProbe.collect(from: channel.messagesToWebView, count: 1, timeout: .milliseconds(200))

        #expect(messages.isEmpty)
    }

    // MARK: Fixtures

    private static func makeChannel(
        driver: MockWidgetDriver = MockWidgetDriver(),
        handle: MockWidgetDriverHandle = MockWidgetDriverHandle()
    ) -> CallWidgetChannel {

        CallWidgetChannel(
            driver              : driver,
            handle              : handle,
            room                : Room(noHandle: Room.NoHandle()),
            capabilitiesProvider: SDKWidgetCapabilitiesProvider(
                ownUserID  : "@alice:example.org",
                ownDeviceID: "DEVICE1"
            )
        )
    }
}
