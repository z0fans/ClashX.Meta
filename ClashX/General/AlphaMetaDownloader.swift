//
//  AlphaMetaDownloader.swift
//  ClashX Meta
//
//  Copyright © 2023 west2online. All rights reserved.
//

import Cocoa
import Alamofire
import CryptoKit

class AlphaMetaDownloader: NSObject {

	// MARK: - Proxy-aware Session
	// Route downloads through mihomo's local proxy port (like FlClash)
	// so GitHub downloads work behind GFW.

	private static func proxySession() -> Session {
		let configuration = URLSessionConfiguration.default
		configuration.timeoutIntervalForRequest = 120
		configuration.timeoutIntervalForResource = 300

		if ConfigManager.shared.isRunning,
		   let httpPort = ConfigManager.shared.currentConfig?.usedHttpPort,
		   httpPort > 0 {
			Logger.log("AlphaMetaDownloader: using proxy 127.0.0.1:\(httpPort)")
			configuration.connectionProxyDictionary = [
				kCFNetworkProxiesHTTPEnable: true,
				kCFNetworkProxiesHTTPProxy: "127.0.0.1",
				kCFNetworkProxiesHTTPPort: httpPort,
				"HTTPSEnable": true,
				"HTTPSProxy": "127.0.0.1",
				"HTTPSPort": httpPort,
			]
		} else {
			Logger.log("AlphaMetaDownloader: proxy not available, using direct")
		}

		return Session(configuration: configuration)
	}

	enum errors: Error {
		case decodeReleaseInfoFailed
		case notFoundUpdate
		case downloadFailed
		case unknownError
		case testFailed
        case checksumFailed
        case downloadChecksumFailed

		func des() -> String {
			switch self {
			case .decodeReleaseInfoFailed:
				return NSLocalizedString("Decode alpha release info failed", comment: "")
			case .notFoundUpdate:
				return NSLocalizedString("Not found update", comment: "")
			case .downloadFailed:
				return NSLocalizedString("Download failed", comment: "")
			case .testFailed:
				return NSLocalizedString("Test downloaded file failed", comment: "")
            case .checksumFailed:
                return NSLocalizedString("Checksum failed", comment: "")
            case .downloadChecksumFailed:
                return NSLocalizedString("Download checksum failed", comment: "")
			case .unknownError:
				return NSLocalizedString("Unknown error", comment: "")
			}
		}
	}

	struct ReleasesResp: Decodable {
		let assets: [Asset]
		struct Asset: Decodable {
			let name: String
			let downloadUrl: String
			let contentType: String
			let state: String

			enum CodingKeys: String, CodingKey {
				case name,
					 state,
					 downloadUrl = "browser_download_url",
					 contentType = "content_type"
			}
		}
	}

	static func assetName() -> String? {
		switch GetMachineHardwareName() {
		case "x86_64":
			return "amd64"
		case "arm64":
			return "arm64"
		default:
			return nil
		}
	}

	static func GetMachineHardwareName() -> String? {
		var sysInfo = utsname()
		let retVal = uname(&sysInfo)

		guard retVal == EXIT_SUCCESS else { return nil }

		let machineMirror = Mirror(reflecting: sysInfo.machine)
		let identifier = machineMirror.children.reduce("") { identifier, element in
			guard let value = element.value as? Int8, value != 0 else { return identifier }
			return identifier + String(UnicodeScalar(UInt8(value)))
		}
		return identifier
	}

	static func alphaAssets() async throws -> [ReleasesResp.Asset] {
		let session = proxySession()
		let resp = try? await session.request("https://api.github.com/repos/MetaCubeX/mihomo/releases/tags/Prerelease-Alpha").serializingDecodable(ReleasesResp.self).value
		
		guard let resp else {
			throw errors.downloadFailed
		}
		
		return resp.assets
	}
    
    static func alphaCoreAsset(_ assets: [ReleasesResp.Asset]) async throws -> ReleasesResp.Asset {
        guard let assetName = assetName(),
              let asset = assets.first(where: {
                  guard $0.state == "uploaded", $0.contentType == "application/gzip" else { return false }
                  
                  let names = $0.name.split(separator: "-").map(String.init)
                  guard names.count > 4,
                        names[0] == "mihomo",
                        names[1] == "darwin",
                        names[2] == assetName,
                        names[3] == "alpha" else { return false }
                        
                  return true
              }) else {
            throw errors.decodeReleaseInfoFailed
        }
        
        return asset
    }
    
    static func checksumString(_ assets: [ReleasesResp.Asset], asset: ReleasesResp.Asset) async throws -> String {
        let session = proxySession()
        guard let checksumsAsset = assets.first(where: {
            $0.name == "checksums.txt"
        }),
              let resp = try? await session.request(checksumsAsset.downloadUrl).serializingString().value,
              let str = resp.split(separator: "\n").first(where: { $0.contains(asset.name) })?.split(separator: " ").first,
              str.count == 64
        else {
            throw errors.downloadChecksumFailed
        }
        
        return String(str)
    }
    
	static func checkVersion(_ asset: ReleasesResp.Asset) throws -> ReleasesResp.Asset {
		guard let path = Paths.alphaCorePath()?.path else {
			throw errors.unknownError
		}
		if let v = AppDelegate.shared.clashProcess.verifyCoreFile(path),
		   asset.name.contains(v.version) {
			throw errors.notFoundUpdate
		}
		return asset
	}

	static func downloadCore(_ asset: ReleasesResp.Asset) async throws -> Data {
		let session = proxySession()
		let data = try? await session.download(asset.downloadUrl).serializingData().value

		if let data {
			return data
		} else {
			throw errors.downloadFailed
		}
	}

    static func replaceCore(_ gzData: Data, checksum: String) throws -> String {
		let fm = FileManager.default
        
        guard SHA256.hash(data: gzData).compactMap({ String(format: "%02x", $0) }).joined() == checksum else {
            throw errors.checksumFailed
        }

		guard let helperURL = Paths.alphaCorePath() else {
			throw errors.unknownError
		}

		try fm.createDirectory(at: helperURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

		let cachePath = Paths.tempPath().appending("/\(UUID().uuidString).newcore")
		try gzData.gunzipped().write(to: .init(fileURLWithPath: cachePath))
		
		Logger.log("save alpha core in \(cachePath)")

		guard let version = AppDelegate.shared.clashProcess.verifyCoreFile(cachePath)?.version else {
			throw errors.testFailed
		}

		try? fm.removeItem(at: helperURL)
		try fm.moveItem(atPath: cachePath, toPath: helperURL.path)

		return version
	}
}

/// MARK: - Stable Release Auto Update Check
extension AlphaMetaDownloader {

	/// GitHub API for latest stable mihomo release
	private static let stableReleaseURL = "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"

	/// Check interval: 24 hours
	private static let checkIntervalSeconds: TimeInterval = 24 * 60 * 60
	private static let lastCheckKey = "stableCore_lastUpdateCheckTime"
	private static let skipVersionKey = "stableCore_skipVersion"

	struct StableRelease: Decodable {
		let tagName: String
		let assets: [ReleasesResp.Asset]

		enum CodingKeys: String, CodingKey {
			case tagName = "tag_name"
			case assets
		}
	}

	/// Called on app launch. Checks stable release once per 24h.
	static func autoCheckForUpdate() {
		let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
		let now = Date().timeIntervalSince1970
		guard now - lastCheck > checkIntervalSeconds else {
			Logger.log("CoreUpdateCheck: skip, last check \(Int((now - lastCheck) / 60))min ago")
			return
		}

		Task {
			// Wait 10s for core & proxy to be ready
			try? await Task.sleep(nanoseconds: 10_000_000_000)
			await performStableUpdateCheck()
		}
	}

	/// Fetch latest stable release info
	private static func fetchStableRelease() async throws -> StableRelease {
		let session = proxySession()
		guard let release = try? await session.request(stableReleaseURL)
			.serializingDecodable(StableRelease.self).value else {
			throw errors.downloadFailed
		}
		return release
	}

	/// Match the correct stable asset for current architecture
	/// Pattern: mihomo-darwin-{arm64|amd64}-v{x.y.z}.gz
	private static func stableCoreAsset(_ assets: [ReleasesResp.Asset]) throws -> ReleasesResp.Asset {
		guard let arch = assetName(),
			  let asset = assets.first(where: {
				  guard $0.state == "uploaded",
						$0.contentType == "application/gzip" else { return false }
				  // Match exact pattern: mihomo-darwin-arm64-v1.19.25.gz
				  // Exclude variants: -compatible, -go120, -v1-, -v2-
				  let name = $0.name
				  return name.hasPrefix("mihomo-darwin-\(arch)-v")
					  && name.hasSuffix(".gz")
					  && !name.contains("-compatible")
					  && !name.contains("-go1")
					  && !name.contains("-v1-")
					  && !name.contains("-v2-")
			  }) else {
			throw errors.decodeReleaseInfoFailed
		}
		return asset
	}

	/// Compare semantic versions: "1.19.25" > "1.19.17" → true
	private static func isNewer(_ remote: String, than current: String) -> Bool {
		let r = remote.replacingOccurrences(of: "v", with: "").split(separator: ".").compactMap { Int($0) }
		let c = current.replacingOccurrences(of: "v", with: "").split(separator: ".").compactMap { Int($0) }
		for i in 0..<max(r.count, c.count) {
			let rv = i < r.count ? r[i] : 0
			let cv = i < c.count ? c[i] : 0
			if rv > cv { return true }
			if rv < cv { return false }
		}
		return false
	}

	private static func performStableUpdateCheck() async {
		Logger.log("CoreUpdateCheck: checking latest stable release...")
		UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)

		do {
			let release = try await fetchStableRelease()
			let remoteVersion = release.tagName // e.g. "v1.19.25"
			let asset = try stableCoreAsset(release.assets)

			// Get current running core version via API
			let currentVersion: String = await withCheckedContinuation { continuation in
				ApiRequest.requestVersion { ver in
					continuation.resume(returning: ver?.version ?? "")
				}
			}

			// Compare versions
			guard isNewer(remoteVersion, than: currentVersion) else {
				Logger.log("CoreUpdateCheck: already on latest (\(currentVersion))")
				return
			}

			// Check if user skipped this version
			if let skipped = UserDefaults.standard.string(forKey: skipVersionKey),
			   skipped == remoteVersion {
				Logger.log("CoreUpdateCheck: user skipped \(skipped)")
				return
			}

			Logger.log("CoreUpdateCheck: update available \(currentVersion) → \(remoteVersion)")

			await MainActor.run {
				let info = "\(currentVersion) → \(remoteVersion) (Stable)"
				UserNotificationCenter.shared.post(
					title: NSLocalizedString("Core Update Available", comment: ""),
					info: info
				)
			}
		} catch {
			Logger.log("CoreUpdateCheck: failed - \(error.localizedDescription)")
		}
	}
}

