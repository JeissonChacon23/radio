//
//  PreviewSupport.swift
//  radio
//
//  Created by Foster Chacon on 23/10/26.
//

// radio/Core/Support/PreviewSupport.swift

import Foundation

enum RuntimeEnvironment {
    /// True when the code runs inside an Xcode canvas preview.
    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
