import Flutter
import UIKit
import ObjectiveC
import WebKit
import XCTest
@testable import stratum_ui

/// Class methods with and without the C shape `matchesLookup` accepts.
final class LookupProbe: NSObject {
  @objc class func matching(_ id: Int64, _ source: AnyObject) -> AnyObject? { nil }
  @objc class func narrowId(_ id: Int32, _ source: AnyObject) -> AnyObject? { nil }
  @objc class func returnsNothing(_ id: Int64, _ source: AnyObject) {}
  @objc class func oneArgument(_ id: Int64) -> AnyObject? { nil }
}

/// Records nothing; the alias test only needs a handler to exist.
final class SilentHandler: NSObject, WKScriptMessageHandler {
  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {}
}

/// Fulfills an expectation when a navigation finishes.
final class FinishDelegate: NSObject, WKNavigationDelegate {
  private let finished: XCTestExpectation
  init(_ finished: XCTestExpectation) { self.finished = finished }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finished.fulfill() }
}

class RunnerTests: XCTestCase {
  private func classMethod(_ selector: Selector) -> Method {
    class_getClassMethod(LookupProbe.self, selector)!
  }

  func testS5MatchesOnlyTheLookupShape() {
    XCTAssertTrue(StratumUiPlugin.matchesLookup(classMethod(#selector(LookupProbe.matching(_:_:)))))
    XCTAssertFalse(StratumUiPlugin.matchesLookup(classMethod(#selector(LookupProbe.narrowId(_:_:)))))
    XCTAssertFalse(
      StratumUiPlugin.matchesLookup(classMethod(#selector(LookupProbe.returnsNothing(_:_:)))))
    XCTAssertFalse(StratumUiPlugin.matchesLookup(classMethod(#selector(LookupProbe.oneArgument(_:)))))
  }

  func testS4BracketsAnIPv6HostOnlyOnce() {
    XCTAssertEqual(
      BridgeMessageHandler.origin(scheme: "http", host: "::1", port: 8080), "http://[::1]:8080")
    XCTAssertEqual(
      BridgeMessageHandler.origin(scheme: "http", host: "[::1]", port: 8080), "http://[::1]:8080")
    XCTAssertEqual(
      BridgeMessageHandler.origin(scheme: "http", host: "127.0.0.1", port: 8080),
      "http://127.0.0.1:8080")
    XCTAssertEqual(
      BridgeMessageHandler.origin(scheme: "https", host: "example.com", port: 0),
      "https://example.com")
    XCTAssertNil(BridgeMessageHandler.origin(scheme: "file", host: "", port: 0))
  }

  func testAliasIsAddedOnceAtDocumentStartForEveryFrame() {
    let controller = WKUserContentController()
    StratumUiPlugin.installAlias(on: controller)
    StratumUiPlugin.installAlias(on: controller)
    let aliases = controller.userScripts.filter { $0.source == StratumUiPlugin.aliasSource }
    XCTAssertEqual(aliases.count, 1)
    XCTAssertEqual(aliases.first?.injectionTime, .atDocumentStart)
    XCTAssertEqual(aliases.first?.isForMainFrameOnly, false)
    XCTAssertEqual(
      StratumUiPlugin.aliasSource, "window.StratumBridge = webkit.messageHandlers.StratumBridge;")
  }

  func testAliasExposesTheMessageHandlerAsStratumBridge() {
    let configuration = WKWebViewConfiguration()
    configuration.userContentController.add(SilentHandler(), name: "StratumBridge")
    StratumUiPlugin.installAlias(on: configuration.userContentController)
    let webView = WKWebView(frame: .zero, configuration: configuration)
    let finished = expectation(description: "page finished")
    let delegate = FinishDelegate(finished)
    webView.navigationDelegate = delegate
    webView.loadHTMLString("<p>x</p>", baseURL: nil)
    wait(for: [finished], timeout: 10)
    let evaluated = expectation(description: "script evaluated")
    webView.evaluateJavaScript("typeof window.StratumBridge.postMessage") { value, _ in
      XCTAssertEqual(value as? String, "function")
      evaluated.fulfill()
    }
    wait(for: [evaluated], timeout: 10)
  }
}
