#!/usr/bin/env swift

import Foundation

private struct IconElement {
    let type: String
    let fileName: String
}

private let elements = [
    IconElement(type: "icp4", fileName: "icon_16x16.png"),
    IconElement(type: "icp5", fileName: "icon_32x32.png"),
    IconElement(type: "icp6", fileName: "icon_32x32@2x.png"),
    IconElement(type: "ic07", fileName: "icon_128x128.png"),
    IconElement(type: "ic08", fileName: "icon_256x256.png"),
    IconElement(type: "ic09", fileName: "icon_512x512.png"),
    IconElement(type: "ic10", fileName: "icon_512x512@2x.png"),
]

private func appendASCII(_ text: String, to data: inout Data) throws {
    guard let bytes = text.data(using: .ascii), bytes.count == 4 else {
        throw NSError(domain: "MakeICNS", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Invalid ICNS type: \(text)"])
    }
    data.append(bytes)
}

private func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { data.append(contentsOf: $0) }
}

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: make-icns.swift INPUT.iconset OUTPUT.icns\n", stderr)
    exit(2)
}

let inputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

do {
    var body = Data()
    for element in elements {
        let imageURL = inputDirectory.appendingPathComponent(element.fileName)
        let imageData = try Data(contentsOf: imageURL)
        try appendASCII(element.type, to: &body)
        appendBigEndian(UInt32(imageData.count + 8), to: &body)
        body.append(imageData)
    }

    var result = Data()
    try appendASCII("icns", to: &result)
    appendBigEndian(UInt32(body.count + 8), to: &result)
    result.append(body)
    try result.write(to: outputURL, options: .atomic)
} catch {
    fputs("make-icns: \(error.localizedDescription)\n", stderr)
    exit(1)
}
