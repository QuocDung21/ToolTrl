//
//  AppLanguage.swift
//  NekoTrans
//
//  Created by Dũng Nguyễn Quốc on 4/10/26.
//

import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case vietnamese = "vi"
    case english    = "en"
    case system     = "system"

    public var id: String { rawValue }

    public var title: LocalizedStringKey {
        switch self {
        case .vietnamese: return "language.vi"
        case .english:    return "language.en"
        case .system:     return "language.system"
        }
    }

    public var flag: String {
        switch self {
        case .vietnamese: return "🇻🇳"
        case .english:    return "🇺🇸"
        case .system:     return "🌐"
        }
    }

    public var resolvedCode: String {
        switch self {
        case .vietnamese: return "vi"
        case .english:    return "en"
        case .system:
            return Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        }
    }
}
