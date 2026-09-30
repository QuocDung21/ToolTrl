//
//  Key.swift
//  NekoTrans
//
//  Created by Dũng Nguyễn Quốc on 25/9/26.
//

import Foundation

public enum KeyStore {
    // start - show_main_window_on_launch
    public static let showMainWindowOnLaunch = "show_main_window_on_launch"
    public static let defaultShowMainWindowOnLaunch: Bool = true
    // end - show_main_window_on_launch

    // MARK: - Secrets (stored in the Keychain, never in UserDefaults)

    /// Account names of every secret handled by `KeychainStore`.
    ///
    /// The raw values intentionally match the historical `UserDefaults` keys so a
    /// pre-Keychain install migrates without any extra mapping.
    public enum Secret {
        public static let openAI = "openai_api_key"
        public static let anthropic = "anthropic_api_key"
        public static let gemini = "gemini_api_key"
        public static let groq = "groq_api_key"
        public static let deepSeek = "deepseek_api_key"
        public static let deepL = "deepl_api_key"
        public static let githubPAT = "tooltrl_github_pat_token"

        public static let allAccounts: [String] = [
            openAI, anthropic, gemini, groq, deepSeek, deepL, githubPAT
        ]
    }
}
