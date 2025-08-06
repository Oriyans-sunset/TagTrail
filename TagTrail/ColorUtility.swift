//
//  ColorUtility.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-08-05.
//

import SwiftUI
import UIKit


extension Color {
    func toHex() -> String? {
        let uiColor = UIColor(self)

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) == false {
            // convert to sRGB first, then extract
            guard
                let cg = uiColor.cgColor.converted(
                    to: CGColorSpace(name: CGColorSpace.sRGB)!,
                    intent: .defaultIntent,
                    options: nil
                ),
                let comps = cg.components, comps.count >= 3
            else { return nil }

            r = comps[0]; g = comps[1]; b = comps[2]
        }

        // Clamp & round to 0…255 so we always get 2-digit hex
        let r8 = max(0, min(255, Int(round(r * 255))))
        let g8 = max(0, min(255, Int(round(g * 255))))
        let b8 = max(0, min(255, Int(round(b * 255))))

        return String(format: "#%02X%02X%02X", r8, g8, b8)
    }
}

extension Color {
    init?(hex: String) {
        var hex = hex
        if hex.hasPrefix("#") { hex.removeFirst() }

        guard hex.count == 6,
              let rgb = Int(hex, radix: 16) else { return nil }

        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double(rgb         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
