import Foundation

// MARK: - Device Auth Models

struct DeviceAuthResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

enum DeviceVerifyStatus: String, Codable {
    case pending
    case authorized
    case expired
}

struct DeviceVerifyResponse: Codable {
    let status: DeviceVerifyStatus
    let token: String?
    let user: AuthUser?
}

struct AuthUser: Codable {
    let id: String
    let email: String
    let name: String

    var displayName: String {
        if !name.isEmpty { return name }
        if !email.isEmpty { return email }
        return String(id.prefix(8))
    }
}

// MARK: - Stored Credentials

struct StoredCredentials: Codable {
    let token: String
    let user: AuthUser
}
