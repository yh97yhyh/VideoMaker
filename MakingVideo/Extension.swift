//
//  Extension.swift
//  MakingVideo
//
//  Created by MZ01-KYONGH on 2021/12/22.
//

import Foundation
import AppKit

extension NSImage {
    var cgImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)

        return cgImage(forProposedRect: &proposedRect,
                       context: nil,
                       hints: nil)
    }

    convenience init?(named name: String) {
        self.init(named: Name(name))
    }
}
