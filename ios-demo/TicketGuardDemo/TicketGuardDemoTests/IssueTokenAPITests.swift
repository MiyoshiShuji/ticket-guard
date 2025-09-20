import XCTest
@testable import TicketGuardDemo

final class IssueTokenAPITests: XCTestCase {
    func testDecodeIssueTokenResponse() throws {
        let json = """
        {
          "ticketId": "T1",
          "deviceId": "D1",
          "startAtEpochSec": 1700000000,
          "ttlSec": 8,
          "nonce": "abc123",
          "sig": "sigValue"
        }
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(IssueTokenResponse.self, from: data)
        XCTAssertEqual(decoded.ticketId, "T1")
        XCTAssertEqual(decoded.deviceId, "D1")
        XCTAssertEqual(decoded.ttlSec, 8)
        XCTAssertEqual(decoded.sig, "sigValue")
    }
}
