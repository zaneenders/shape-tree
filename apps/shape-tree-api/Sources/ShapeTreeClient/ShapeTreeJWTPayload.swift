import JWTKit

/// Claim set for ShapeTree device JWTs (`sub` == RFC 7638 thumbprint == `kid`).
///
/// Shared by the server verifier and ``ShapeTreeTokenIssuer`` so mint and verify stay aligned.
public struct ShapeTreeJWTPayload: JWTPayload {
  public var sub: SubjectClaim
  public var iat: IssuedAtClaim
  public var exp: ExpirationClaim
  public var jti: IDClaim?

  public init(
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

  public func verify(using _: some JWTAlgorithm) throws {
    try exp.verifyNotExpired()
  }
}
