//
//  JoinLinkParserTests.swift
//  MomentoTests
//
//  Tests for the URL/code parser used by both the Universal Link handler
//  (in MomentoApp) and the in-sheet clipboard/QR/manual entry flow. A bug
//  here means a join URL silently fails — the user pastes a link, nothing
//  happens, no error message. Worth solid coverage.
//

import XCTest
@testable import Momento

final class JoinLinkParserTests: XCTestCase {

    // MARK: - Universal Link (https) URLs

    func test_universalLink_extractsUppercasedCode() {
        XCTAssertEqual(JoinLinkParser.extractCode(from: "https://10shots.app/join/abc123"), "ABC123")
    }

    func test_universalLink_alreadyUppercase_passesThrough() {
        XCTAssertEqual(JoinLinkParser.extractCode(from: "https://10shots.app/join/ABC123"), "ABC123")
    }

    func test_universalLink_withQueryString_stripsQuery() {
        XCTAssertEqual(JoinLinkParser.extractCode(from: "https://10shots.app/join/ABC123?utm_source=imessage"), "ABC123")
    }

    func test_universalLink_withFragment_stripsFragment() {
        XCTAssertEqual(JoinLinkParser.extractCode(from: "https://10shots.app/join/ABC123#preview"), "ABC123")
    }

    func test_universalLink_withTrailingSlash_stripsIt() {
        XCTAssertEqual(JoinLinkParser.extractCode(from: "https://10shots.app/join/ABC123/"), "ABC123")
    }

    func test_universalLink_acceptsAnyHost() {
        // The parser doesn't host-check — that's an explicit decision: any
        // /join/CODE link, regardless of where it came from, should work.
        // (The Universal Link entitlement gates which hosts actually deep-link
        // into the app; the parser is permissive.)
        XCTAssertEqual(JoinLinkParser.extractCode(from: "https://yourmomento.app/join/ABC123"), "ABC123")
    }

    // MARK: - momento:// URL scheme (legacy)

    func test_momentoScheme_extractsCode() {
        XCTAssertEqual(JoinLinkParser.extractCode(from: "momento://join/ABC123"), "ABC123")
    }

    func test_momentoScheme_lowercaseSuffix_uppercases() {
        XCTAssertEqual(JoinLinkParser.extractCode(from: "momento://join/abc123"), "ABC123")
    }

    // MARK: - Raw codes

    func test_rawCode_uppercasedReturned() {
        XCTAssertEqual(JoinLinkParser.extractCode(from: "abc123"), "ABC123")
    }

    func test_rawCode_alreadyUppercase_passesThrough() {
        XCTAssertEqual(JoinLinkParser.extractCode(from: "ABC123"), "ABC123")
    }

    func test_rawCode_withSurroundingWhitespace_trimmed() {
        XCTAssertEqual(JoinLinkParser.extractCode(from: "  abc123  \n"), "ABC123")
    }

    // MARK: - Rejection cases (return nil)

    func test_codeWithFewerThanSixChars_isRejected() {
        XCTAssertNil(JoinLinkParser.extractCode(from: "abc12"))
    }

    func test_codeWithMoreThanSixChars_isRejected() {
        XCTAssertNil(JoinLinkParser.extractCode(from: "abc1234"))
    }

    func test_emptyInput_isRejected() {
        XCTAssertNil(JoinLinkParser.extractCode(from: ""))
    }

    func test_whitespaceOnly_isRejected() {
        XCTAssertNil(JoinLinkParser.extractCode(from: "   "))
    }

    func test_universalLinkWithoutCodeSegment_isRejected() {
        XCTAssertNil(JoinLinkParser.extractCode(from: "https://10shots.app/"))
    }

    func test_universalLinkWithBadCode_isRejected() {
        // /join/ABC12 is only 5 chars — not a valid code.
        XCTAssertNil(JoinLinkParser.extractCode(from: "https://10shots.app/join/ABC12"))
    }

    func test_codeWithPunctuation_stripsPunctuationButFails() {
        // The parser strips non-alphanumerics before length-checking. An
        // input like "ABC-123" becomes "ABC123" (6 chars) and is accepted.
        // An input like "ABC!" becomes "ABC" (3 chars) and is rejected.
        XCTAssertEqual(JoinLinkParser.extractCode(from: "ABC-123"), "ABC123")
        XCTAssertNil(JoinLinkParser.extractCode(from: "ABC!"))
    }
}
