import Foundation
import JWTKit

struct ShapeTreeJWTPayload: JWTPayload {
  var sub: SubjectClaim
  var iat: IssuedAtClaim
  var exp: ExpirationClaim
  var jti: IDClaim?

  init(
    sub: SubjectClaim,
    iat: IssuedAtClaim,
    exp: ExpirationClaim,
    jti: IDClaim? = nil
  ) {
    self.sub = sub
    self.iat = iat
    self.exp = exp
    self.jti = jti
  }

  func verify(using key: some JWTAlgorithm) throws {
    try exp.verifyNotExpired()
  }
}
