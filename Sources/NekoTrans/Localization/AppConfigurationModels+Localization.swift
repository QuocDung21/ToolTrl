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
        case .ollama: return .providerOllama
        }
    }
}

public extension TranslationDisplayMode {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .wordByWord: return .displayWordByWord
        case .onlyTarget: return .displayOnlyTarget
        case .standard: return .displayStandard
        case .syntax: return .displaySyntax
        }
    }

    var shortLocalizedTitle: LocalizedStringResource {
        switch self {
        case .wordByWord: return .displayWordByWordShort
        case .onlyTarget: return .displayOnlyTargetShort
        case .standard: return .displayStandardShort
        case .syntax: return .displaySyntaxShort
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
