//
//  Command.swift
//  ClashX
//
//  Created by yicheng on 2023/10/13.
//  Copyright © 2023 west2online. All rights reserved.
//

import Foundation

struct Command {
    let cmd: String
    let args: [String]

    func run() -> String {
        var output = ""

        let task = Process()

        task.executableURL = URL(fileURLWithPath: cmd)
        task.arguments = args

        let outpipe = Pipe()
        task.standardOutput = outpipe

        do {
            try task.run()
            task.waitUntilExit()

            let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
            if let string = String(data: outdata, encoding: .utf8) {
                output = string.trimmingCharacters(in: .newlines)
            }
        } catch {
            print("Error running command: \(error)")
        }

        return output
    }
}
