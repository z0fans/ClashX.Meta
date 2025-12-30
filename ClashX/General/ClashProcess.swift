//
//  ClashProcess.swift
//  ClashX
//
//  Copyright © 2024 west2online. All rights reserved.
//

import Cocoa
import PromiseKit

protocol ClashProcessDelegate {
	func clashLaunchPathNotFound(_ msg: String)
	func clashApiUpdated(_ server: MetaServer)
	func clashConfigUpdated()
	func clashStartError(_ error: Error)
}

enum StartMetaError: Error {
	case configMissing
	case remoteConfigMissing
	case startMetaFailed(String)
	case helperNotFound
	case pushConfigFailed(String)
	case launchPathMissing
}

class ClashProcess: NSObject {
	
	enum CoreState: Int {
		case stopped, startFailed, checkingHelper, helperReady, starting, running
	}
	
	
	private let md5: String
	private var retryTimes = 0
	
	private var _coreState: CoreState = .stopped
	
	var coreState: CoreState {
		return _coreState
	}
	
	var delegate: ClashProcessDelegate?
	
	init(_ md5: String) {
		self.md5 = md5
	}
	
	lazy var launchPath: (path: String?, err: String?) = {
		Logger.log("Get launchPath")
		
		guard let alphaCorePath = Paths.alphaCorePath(),
			  let corePath = Paths.defaultCorePath() else {
			return (nil, "Paths error")
		}
		
		// alpha core
		if let _ = verifyCoreFile(alphaCorePath.path) {
			if ConfigManager.useAlphaCore {
				return (alphaCorePath.path, nil)
			}
		}
		
		let fm = FileManager.default
		Logger.log("[CORE] Checking core at: \(corePath.path)")

		// unzip internal core
		if !fm.fileExists(atPath: corePath.path) {
			Logger.log("[CORE] Core file does not exist, unzipping...")
			if let msg = unzipMetaCore() {
				Logger.log("[CORE] Unzip failed: \(msg)")
				return (nil, msg)
			}
			Logger.log("[CORE] Unzip succeeded")
		} else if !validateDefaultCore(md5) {
			Logger.log("[CORE] Core exists but MD5 validation failed, re-extracting...")
			try? fm.removeItem(at: corePath)
			if let msg = unzipMetaCore() {
				Logger.log("[CORE] Re-extraction failed: \(msg)")
				return (nil, msg)
			}
			Logger.log("[CORE] Re-extraction succeeded")
		} else {
			Logger.log("[CORE] Core file exists and MD5 is valid")
		}

		if let msg = verifyCoreFile(corePath.path) {
			Logger.log("[CORE] Core version: \(msg.version)")
		} else {
			Logger.log("[CORE] WARNING: verifyCoreFile() returned nil")
		}

		// validate md5
		Logger.log("[CORE] Final MD5 validation...")
		if validateDefaultCore(md5) {
			Logger.log("[CORE] SUCCESS: Core validation passed")
			return (corePath.path, nil)
		} else {
			Logger.log("[CORE] FAILURE: Final MD5 validation failed")
			Logger.log("[CORE] Path: \(corePath.path)")
			return (nil, "Failure to verify the internal Meta Core.\nDo NOT replace core file in the resources folder.")
		}
	}()
	
	
// MARK: start core
	
	func start() {
		let paths = launchPath
		
		guard let _ = paths.path else {
			let msg = paths.err ?? "Load internal Meta Core failed."
			delegate?.clashLaunchPathNotFound(msg)
			return
		}
		
		checkHelperVersion().then { _ in
			self.startProxy()
		}.done {
			self.retryTimes = 0
			Logger.log("Init config file success.")
			
			self.showUpdateNotification("ClashX_Meta_1.3.0_UpdateTips", info: "Config Floder migrated from\n~/.config/clash to\n~/.config/clash.meta")
		}.catch { error in
			Logger.log("\(error)", level: .error)

			switch error {
			case StartMetaError.helperNotFound:
				self._coreState = .checkingHelper
				let delay: DispatchTimeInterval = {
					switch self.retryTimes {
					case 0..<10:
						return .milliseconds(500)
					case 10..<20:
						return .seconds(2)
					case 20..<30:
						return .seconds(8)
					case 30..<40:
						return .seconds(15)
					default:
						return .seconds(60)
					}
				}()
				self.retryTimes += 1
				after(delay).done {
					self.start()
				}
			default:
				self._coreState = .startFailed
				self.delegate?.clashStartError(error)
			}
		}
	}
	
	func checkHelperVersion() -> Promise<String?> {
		guard coreState.rawValue < CoreState.helperReady.rawValue else {
			return .value(nil)
		}
		_coreState = .checkingHelper
		return Promise { resolver in
			PrivilegedHelperManager.shared.helper {
				Logger.log("Helper, check status failed, will try again")
				resolver.reject(StartMetaError.helperNotFound)
			}?.getVersion {
				Logger.log("Helper, check status success \($0)")
				self._coreState = .helperReady
				resolver.fulfill($0)
			}
		}
	}
	
	private func startProxy() -> Promise<()> {
		guard coreState.rawValue < CoreState.starting.rawValue else {
			return .value(())
		}
		_coreState = .starting
		
		Logger.log("Trying start meta core")
		
		return prepareConfigFile().then {
			self.generateInitConfig()
		}.then {
			self.startMeta($0)
		}.get { res in
			if res.log != "" {
				Logger.log("""
\n########  Clash Meta Start Log  #########
\(res.log)
########  END  #########
""", level: .info)
			}
			self._coreState = .running
			self.delegate?.clashApiUpdated(res)
		}.then { _ in
			self.pushInitConfig()
		}
	}
	

	func prepareConfigFile() -> Promise<()> {
		.init { resolver in
			let configName = ConfigManager.selectConfigName
			ApiRequest.findConfigPath(configName: configName) { path in
				guard let path = path else {
					resolver.reject(StartMetaError.configMissing)
					return
				}
				
				if FileManager.default.fileExists(atPath: path) {
					resolver.fulfill_()
					return
				}
				
				Logger.log("\(configName) not exists")
				if let config = RemoteConfigManager.shared.configs.first(where: { $0.name == configName }) {
					Logger.log("Try to download remote config \(configName)")
					RemoteConfigManager.updateConfig(config: config) {
						if let error = $0 {
							Logger.log("Download remote config failed, \(error)")
							resolver.reject(StartMetaError.remoteConfigMissing)
						} else {
							Logger.log("Download remote config success")
							resolver.fulfill_()
						}
					}
				} else {
					if configName != "config" {
						ConfigManager.selectConfigName = "config"
					}

					Logger.log("Try to copy default config")
					ICloudManager.shared.setup()
					ConfigFileManager.copySampleConfigIfNeed()
					resolver.fulfill_()
				}
			}
		}
	}

	func generateInitConfig() -> Promise<ClashMetaConfig.Config> {
        safePaths().then { paths in
            Promise { resolver in
                ClashMetaConfig.generateInitConfig {
                    var config = $0
                    config.safePaths = paths.joined(separator: ":")
                    PrivilegedHelperManager.shared.helper {
    //                    resolver.reject(StartMetaError.helperNotFound)
                        Logger.log("helperNotFound, getUsedPorts failed", level: .error)
                        resolver.fulfill(config)
                    }?.getUsedPorts {
                        config.updatePorts($0 ?? "")
                        resolver.fulfill(config)
                    }
                }
            }
        }
	}
    
    func safePaths() -> Promise<[String]> {
        .init { resolver in
            guard let resourcePath = Bundle.main.resourcePath else {
                resolver.reject(StartMetaError.startMetaFailed("resourcePath"))
                return
            }
            var paths = [String]()
            paths.append(resourcePath + "/dashboard")
            
            if ICloudManager.shared.useiCloud.value {
                ICloudManager.shared.getUrl { url in
                    if let p = url?.path {
                        paths.append(p)
                        resolver.fulfill(paths)
                    } else {
                        resolver.fulfill(paths)
                    }
                }
            } else {
                resolver.fulfill(paths)
            }
        }
    }

	func startMeta(_ config: ClashMetaConfig.Config) -> Promise<MetaServer> {
		.init { resolver in
			guard let path = launchPath.path else {
				Logger.log("[START] ERROR: launchPath is nil", level: .error)
				resolver.reject(StartMetaError.launchPathMissing)
				return
			}

			Logger.log("[START] Core path: \(path)")
			Logger.log("[START] Config path: \(config.path)")
			Logger.log("[START] Conf folder: \(kConfigFolderPath)")

            let confJSON = MetaServer(
                externalController: config.externalController,
                secret: config.secret ?? "",
                safePaths: config.safePaths ?? ""
            ).jsonString()

			Logger.log("[START] Calling PrivilegedHelper.startMeta...")
			PrivilegedHelperManager.shared.helper {
				Logger.log("[START] ERROR: PrivilegedHelper not found", level: .error)
				resolver.reject(StartMetaError.helperNotFound)
			}?.startMeta(path: path,
						 confPath: kConfigFolderPath,
						 confFilePath: config.path,
						 confJSON: confJSON) { response in
				Logger.log("[START] PrivilegedHelper response received")
				if let string = response {
					Logger.log("[START] Response string: '\(string)'")
					if string.isEmpty {
						Logger.log("[START] ERROR: Response is empty string", level: .error)
						Logger.log("[START] This usually means the core binary failed to execute", level: .error)
						Logger.log("[START] Check if macOS Gatekeeper is blocking the executable", level: .error)
						resolver.reject(StartMetaError.startMetaFailed("Core execution failed - response empty"))
						return
					}
					guard let jsonData = string.data(using: .utf8),
						  let res = try? JSONDecoder().decode(MetaServer.self, from: jsonData) else {
						Logger.log("[START] ERROR: Failed to decode JSON response: \(string)", level: .error)
						resolver.reject(StartMetaError.startMetaFailed(string))
						return
					}

					Logger.log("[START] SUCCESS: Core started successfully")
					resolver.fulfill(res)
				} else {
					Logger.log("[START] ERROR: Response is nil", level: .error)
					resolver.reject(StartMetaError.startMetaFailed("Response is nil"))
				}
			}
		}
	}

	func pushInitConfig() -> Promise<()> {
		.init { resolver in
			ClashProxy.cleanCache()
			let configName = ConfigManager.selectConfigName
			Logger.log("Push init config file: \(configName)")
			ApiRequest.requestConfigUpdate(configName: configName) { err in
				if let error = err {
					resolver.reject(StartMetaError.pushConfigFailed(error))
				} else {
					self.delegate?.clashConfigUpdated()
					resolver.fulfill_()
				}
			}
		}
	}
	
	func showUpdateNotification(_ udString: String, info: String) {
		guard !UserDefaults.standard.bool(forKey: udString) else { return }
		
		UserDefaults.standard.set(true, forKey: udString)
		
		UserNotificationCenter.shared.postNotificationAlert(title: "Update Tips", info: info)
	}
	
// MARK: launch path
	
	private func unzipMetaCore() -> String? {
		guard let corePath = Paths.defaultCorePath(),
			  let gzPath = Paths.defaultCoreGzPath() else { return "Paths error" }
		let fm = FileManager.default
		do {
			Logger.log("[UNZIP] Extracting core from: \(gzPath)")
			let data = try Data(contentsOf: .init(fileURLWithPath: gzPath)).gunzipped()

			if !fm.fileExists(atPath: corePath.deletingLastPathComponent().path) {
				try fm.createDirectory(at: corePath.deletingLastPathComponent(), withIntermediateDirectories: true)
			}

			try data.write(to: corePath)
			Logger.log("[UNZIP] Core extracted to: \(corePath.path)")

			// Remove quarantine attribute to bypass Gatekeeper on macOS 10.14
			removeQuarantine(corePath.path)

			return nil
		} catch let error {
			let msg = "Unzip Meta failed: \(error)"
			Logger.log(msg, level: .error)
			return msg
		}
	}

	private func removeQuarantine(_ path: String) {
		Logger.log("[QUARANTINE] Removing quarantine attribute from: \(path)")
		let proc = Process()
		proc.executableURL = .init(fileURLWithPath: "/usr/bin/xattr")
		proc.arguments = ["-d", "com.apple.quarantine", path]
		do {
			try proc.run()
			proc.waitUntilExit()
			if proc.terminationStatus == 0 {
				Logger.log("[QUARANTINE] Successfully removed quarantine attribute")
			} else {
				Logger.log("[QUARANTINE] xattr exited with status \(proc.terminationStatus) (attribute may not exist)", level: .warning)
			}
		} catch {
			Logger.log("[QUARANTINE] Failed to run xattr: \(error.localizedDescription)", level: .warning)
		}
	}

	func verifyCoreFile(_ path: String) -> (version: String, date: Date?)? {
		Logger.log("[VERIFY] Verifying core file: \(path)")
		guard chmodX(path) else {
			Logger.log("[VERIFY] ERROR: chmod +x failed", level: .error)
			return nil
		}

		let proc = Process()
		proc.executableURL = .init(fileURLWithPath: path)
		proc.arguments = ["-v"]
		let pipe = Pipe()
		let errorPipe = Pipe()
		proc.standardOutput = pipe
		proc.standardError = errorPipe
		do {
			try proc.run()
		} catch let error {
			Logger.log("[VERIFY] ERROR: Failed to execute core: \(error.localizedDescription)", level: .error)
			Logger.log("[VERIFY] ERROR: This is likely due to macOS Gatekeeper blocking unsigned/unnotarized executable", level: .error)
			return nil
		}
		proc.waitUntilExit()
		let data = pipe.fileHandleForReading.readDataToEndOfFile()
		let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

		if let errorOut = String(data: errorData, encoding: .utf8), !errorOut.isEmpty {
			Logger.log("[VERIFY] stderr: \(errorOut)", level: .warning)
		}

		guard proc.terminationStatus == 0,
			  let out = String(data: data, encoding: .utf8) else {
			Logger.log("[VERIFY] ERROR: Core exited with status \(proc.terminationStatus)", level: .error)
			return nil
		}

		Logger.log("[VERIFY] Core executed successfully")
		Logger.log("[VERIFY] Output: \(out)")
		
		let outs = out
			.split(separator: "\n")
			.first {
				$0.starts(with: "Clash Meta") || $0.starts(with: "Mihomo Meta")
			}?.split(separator: " ")
			.map(String.init)

		guard let outs,
			  outs.count == 13,
			  (outs[0] == "Clash" || outs[0] == "Mihomo"),
			  outs[1] == "Meta",
			  outs[3] == "darwin" else {
			return nil
		}

		let version = outs[2]

		let dateString = [outs[7], outs[8], outs[9], outs[10], outs[12]].joined(separator: "-")
		let f = DateFormatter()
		f.dateFormat = "E-MMM-d-HH:mm:ss-yyyy"
		f.timeZone = .init(abbreviation: outs[11])
		let date = f.date(from: dateString)

		return (version: version, date: date)
	}

	private func validateDefaultCore(_ md5: String) -> Bool {
		Logger.log("[MD5] Starting core validation")
		guard let path = Paths.defaultCorePath()?.path else {
			Logger.log("[MD5] ERROR: defaultCorePath() returned nil")
			return false
		}
		Logger.log("[MD5] Core path: \(path)")

		guard chmodX(path) else {
			Logger.log("[MD5] ERROR: chmod +x failed on \(path)")
			return false
		}
		Logger.log("[MD5] chmod +x succeeded")

		#if DEBUG
			Logger.log("[MD5] DEBUG build - skipping MD5 check")
			return true
		#endif
		let proc = Process()
		proc.executableURL = .init(fileURLWithPath: "/sbin/md5")
		proc.arguments = ["-q", path]
		let pipe = Pipe()
		proc.standardOutput = pipe

		try? proc.run()
		proc.waitUntilExit()
		let data = pipe.fileHandleForReading.readDataToEndOfFile()
		guard proc.terminationStatus == 0,
			  let out = String(data: data, encoding: .utf8) else {
			Logger.log("[MD5] ERROR: md5 command failed with status \(proc.terminationStatus)")
			return false
		}

		let actualMD5 = out.replacingOccurrences(of: "\n", with: "")
		Logger.log("[MD5] Expected: \(md5)")
		Logger.log("[MD5] Actual:   \(actualMD5)")
		let result = md5 == actualMD5
		Logger.log("[MD5] Validation result: \(result ? "SUCCESS" : "FAILED")")
		return result
	}

	private func chmodX(_ path: String) -> Bool {
		let proc = Process()
		proc.executableURL = .init(fileURLWithPath: "/bin/chmod")
		proc.arguments = ["+x", path]
		do {
			try proc.run()
		} catch let error {
			Logger.log("chmod +x failed. \(error.localizedDescription)")
			return false
		}
		proc.waitUntilExit()
		return proc.terminationStatus == 0
	}
	
// MARK: verify config file
	
	@objc func verify(_ confPath: String, confFilePath: String) -> String? {
		do {
			guard let path = launchPath.path else { return nil }
			
			let proc = Process()
			proc.executableURL = .init(fileURLWithPath: path)
			var args = [
				"-t",
				"-d",
				confPath
			]
			if confFilePath != "" {
				args.append(contentsOf: [
					"-f",
					confFilePath
				])
			}
			let pipe = Pipe()
			proc.standardOutput = pipe
			
			proc.arguments = args
			try proc.run()
			proc.waitUntilExit()
			
			guard proc.terminationStatus == 0 else {
				return "Test failed, status \(proc.terminationStatus)"
			}
			
			let data = pipe.fileHandleForReading.readDataToEndOfFile()
			guard let string = String(data: data, encoding: String.Encoding.utf8) else {
				return "Test failed, no found output."
			}
			
			let task = MetaTask()
			
			let results = string.split(separator: "\n").map(String.init).map(task.formatMsg(_:))
			
			guard let re = results.last else {
				return "Test failed, no found output."
			}
			
			if re.hasPrefix("configuration file"),
			   re.hasSuffix("test is successful") {
				return nil
			} else if re.hasPrefix("configuration file"),
					  re.hasSuffix("test failed") {
				return results.count > 1
				? results[results.count - 2]
				: "Test failed, unknown result."
			} else {
				return re
			}
		} catch let error {
			return "\(error)"
		}
	}
}
