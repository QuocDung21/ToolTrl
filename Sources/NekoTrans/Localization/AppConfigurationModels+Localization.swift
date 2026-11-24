import SwiftUI
import NekoCore

public extension TranslationDomain {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .general: return .domainGeneral
        case .technology: return .domainTechnology
        case .business: return .domainBusiness
        case .academic: return .domainAcademic
        case .medical: return .domainMedical
        case .daily: return .domainDaily
        }
    }
}

public extension TranslationEngine {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .auto: return .engineAuto
        case .directAI: return .engineDirectAI
        case .deepL: return .engineDeepL
        case .googleWeb: return .engineGoogleWeb
        case .appleOffline: return .engineAppleOffline
        }
    }
}

public extension DirectAIProvider {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .openAI: return .providerOpenAI
        case .anthropic: return .providerAnthropic
        case .googleGemini: return .providerGoogleGemini
        case .groq: return .providerGroq
        case .deepSeek: return .providerDeepSeek
        case .inProcessGGUF: return LocalizedStringResource("Mô hình GGUF Trực tiếp (Metal In-Process)")
        }
    }
}

public extension TranslationDisplayMode {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .standard: return .displayStandard
        case .onlyTarget: return .displayOnlyTarget
        }
    }

    var shortLocalizedTitle: LocalizedStringResource {
        switch self {
        case .standard: return .displayStandardShort
        case .onlyTarget: return .displayOnlyTargetShort
        }
    }
}

public extension QuitActionPreference {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .askEveryTime: return .quitAskEveryTime
        case .runInBackground: return .quitRunInBackground
        case .terminateImmediately: return .quitTerminateImmediately
        }
    }
}

public extension AppFontSize {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .small: return .fontSizeSmall
        case .medium: return .fontSizeMedium
        case .large: return .fontSizeLarge
        case .extraLarge: return .fontSizeExtraLarge
        }
    }
}

public extension MainWorkspaceTab {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .translate: return .tabTranslate
        case .notebook: return .tabNotebook
        case .flashcards: return .tabFlashcards
        case .deepAI: return .tabDeepAI
        case .stats: return .tabStats
        }
    }
}

public extension WorkspaceSidebarItem {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .translate: return .wsTranslate
        case .notebookAll: return .wsNotebookAll
        case .notebookVocab: return .wsNotebookVocab
        case .notebookGrammar: return .wsNotebookGrammar
        case .notebookFavorites: return .wsNotebookFavorites
        case .notebookMastered: return .wsNotebookMastered
        case .flashcards: return .wsFlashcards
        case .deepAI: return .wsDeepAI
        case .stats: return .wsStats
        }
    }
}

public extension UpdateChannel {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .stable:  return .updateChannelStable
        case .beta:    return .updateChannelBeta
        case .nightly: return .updateChannelNightly
        case .dev:     return .updateChannelDev
        }
    }

    var localizedDescription: LocalizedStringResource {
        switch self {
        case .stable:  return .updateChannelStableDesc
        case .beta:    return .updateChannelBetaDesc
        case .nightly: return .updateChannelNightlyDesc
        case .dev:     return .updateChannelDevDesc
        }
    }
}

public extension AppAppearanceMode {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .system: return LocalizedStringResource("theme.mode.system", defaultValue: "System")
        case .light:  return LocalizedStringResource("theme.mode.light", defaultValue: "Light")
        case .dark:   return LocalizedStringResource("theme.mode.dark", defaultValue: "Dark")
        }
    }
}

public extension AppAccentTheme {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .oceanBlue:   return LocalizedStringResource("theme.accent.ocean_blue", defaultValue: "Ocean Blue")
        case .nekoAmber:   return LocalizedStringResource("theme.accent.neko_amber", defaultValue: "Neko Amber")
        case .sakuraPink:  return LocalizedStringResource("theme.accent.sakura_pink", defaultValue: "Sakura Pink")
        case .emerald:     return LocalizedStringResource("theme.accent.emerald", defaultValue: "Emerald Green")
        case .royalIndigo: return LocalizedStringResource("theme.accent.royal_indigo", defaultValue: "Royal Indigo")
        case .graphite:    return LocalizedStringResource("theme.accent.graphite", defaultValue: "Graphite")
        }
    }
}

public extension HUDMaterialStyle {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .frostedPopover: return LocalizedStringResource("theme.hud.popover", defaultValue: "Frosted Light")
        case .deepHUDGlass:   return LocalizedStringResource("theme.hud.deep_glass", defaultValue: "Deep HUD Glass")
        case .ultraClean:     return LocalizedStringResource("theme.hud.ultra_clean", defaultValue: "Ultra Clean Matte")
        }
    }
}

