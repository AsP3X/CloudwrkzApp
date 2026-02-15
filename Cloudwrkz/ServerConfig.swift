//
//  ServerConfig.swift
//  Cloudwrkz
//
//  Tenant and server configuration (official Cloudwrkz, on‑prem).
//  Persisted in UserDefaults so API base URL can be built from tenant + domain + port.
//

import Foundation

enum TenantType: String, CaseIterable, Identifiable {
    case official = "Official Cloudwrkz"
    case onprem = "On‑prem"

    var id: String { rawValue }

    /// Default host for official tenant; ignored when onprem.
    static let officialDomain = "cloudwrkz.com"
    static let officialPort: Int? = nil
}

struct ServerConfig: Equatable {
    var tenant: TenantType
    var serverDomain: String
    var serverPort: Int?

    static let defaults = ServerConfig(
        tenant: .official,
        serverDomain: TenantType.officialDomain,
        serverPort: TenantType.officialPort
    )

    /// Base URL for API requests (e.g. https://cloudwrkz.com or https://mycompany.com:8443).
    var baseURL: URL? {
        let host = tenant == .official ? TenantType.officialDomain : serverDomain
        let scheme = "https"
        var components = URLComponents()
        components.scheme = scheme
        components.host = host.isEmpty ? nil : host
        components.port = (tenant != .official && (serverPort ?? 0) > 0) ? serverPort : nil
        return components.url
    }
}

// MARK: - UserDefaults persistence

private enum Keys {
    static let tenant = "cloudwrkz.serverConfig.tenant"
    static let serverDomain = "cloudwrkz.serverConfig.serverDomain"
    static let serverPort = "cloudwrkz.serverConfig.serverPort"
}

extension ServerConfig {
    static func load() -> ServerConfig {
        let raw = UserDefaults.standard.string(forKey: Keys.tenant)
        let tenant: TenantType = {
            if let r = raw, let t = TenantType(rawValue: r) { return t }
            if raw == "Self‑hosted" { return .onprem } // migrate removed option
            return .official
        }()
        let domain = UserDefaults.standard.string(forKey: Keys.serverDomain) ?? TenantType.officialDomain
        let port: Int? = {
            let v = UserDefaults.standard.object(forKey: Keys.serverPort)
            if let n = v as? Int { return n }
            if let n = v as? NSNumber { return n.intValue }
            return nil
        }()
        return ServerConfig(tenant: tenant, serverDomain: domain, serverPort: port)
    }

    func save() {
        UserDefaults.standard.set(tenant.rawValue, forKey: Keys.tenant)
        UserDefaults.standard.set(serverDomain, forKey: Keys.serverDomain)
        if let p = serverPort {
            UserDefaults.standard.set(p, forKey: Keys.serverPort)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.serverPort)
        }
    }
}
