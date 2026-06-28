import Foundation
import Testing

@testable import ShapeTreeEmail

@Suite struct SMTPMessageEncodingTests {
  @Test func sanitizeHeaderValueStripsCRAndLF() {
    #expect(SMTPMessageEncoding.sanitizeHeaderValue("hello\r\nworld") == "helloworld")
  }

  @Test func sanitizeHeaderValuePreservesNormalText() {
    #expect(SMTPMessageEncoding.sanitizeHeaderValue("Hello World") == "Hello World")
  }

  @Test func dotStuffedBodyPrependsDotToLinesStartingWithDot() {
    let result = SMTPMessageEncoding.dotStuffedBody(".dot\nnormal\n..double")
    #expect(result == "..dot\r\nnormal\r\n...double")
  }

  @Test func dotStuffedBodyUsesCRLFLineSeparators() {
    #expect(SMTPMessageEncoding.dotStuffedBody("a\nb") == "a\r\nb")
  }

  @Test func dotStuffedBodyNormalizesCRLF() {
    #expect(SMTPMessageEncoding.dotStuffedBody("a\r\nb") == "a\r\nb")
  }

  @Test func rfc5322DateStringProducesGMTFormattedDate() {
    let date = Date(timeIntervalSince1970: 0)
    #expect(
      SMTPMessageEncoding.rfc5322DateString(from: date)
        == "Thu, 01 Jan 1970 00:00:00 +0000"
    )
  }
}
