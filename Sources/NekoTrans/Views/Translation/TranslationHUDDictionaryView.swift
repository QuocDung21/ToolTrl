import SwiftUI

public struct TranslationHUDDictionaryView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject var speechService = SpeechService.shared
    @ObservedObject var audioPlayerService = AudioPlayerService.shared
    @ObservedObject var settings = AppSettings.shared
    @EnvironmentObject private var l10n: Localization
    @State private var showAdvancedWordDetails: Bool = false
    @State private var showSynonymsAndNeighbors: Bool = false
    @State private var selectedPOS: String = "all"
    @State private var copiedMainTranslation: Bool = false

    public init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if settings.wordLookupMode == .quickTranslate {
                compactQuickTranslateView
            } else if let rich = viewModel.richEntry, rich.hasValidDefinitions {
                richDictionaryContent(entry: rich)
            } else if viewModel.isDictionaryLoading || viewModel.isLoading {
                dictionaryLoadingSkeleton
            } else {
                dictionaryFallbackView
            }
        }
    }

    // MARK: - Compact Quick Translate View (Dịch gọn)
    private var compactQuickTranslateView: some View {
        let entry = viewModel.richEntry
        let displayWord = entry?.word ?? viewModel.originalText.capitalized
        let resolvedTranslation: String = {
            if !viewModel.translatedText.isEmpty {
                return viewModel.translatedText
            }
            if let main = entry?.mainTranslation, !main.isEmpty {
                return main
            }
            return "—"
        }()

        return VStack(alignment: .leading, spacing: 8) {
            // Row 1: Word + IPA + UK/US Audio + Bookmark
            HStack(alignment: .center, spacing: 8) {
                LiveSpokenTextView(
                    text: displayWord,
                    speakerID: "original",
                    font: .system(size: 18, weight: .bold),
                    defaultColor: .primary
                )

                if settings.showPhonetics {
                    let ukPh = IPANormalizer.normalize(entry?.ukPhonetic)
                    let usPh = IPANormalizer.normalize(entry?.usPhonetic)
                    let mainPh = IPANormalizer.normalize(entry?.phonetic ?? DictionaryService.shared.extractPhonetic(for: viewModel.originalText))

                    if let ph = mainPh ?? usPh ?? ukPh, !ph.isEmpty {
                        Text(ph)
                            .font(.system(size: 11.5, design: .serif))
                            .foregroundColor(AppColors.phonetic)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.phoneticSubtle)
                            .cornerRadius(4.5)
                    }
                }

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    let wordKey = entry?.word ?? viewModel.originalText
                    let ukID = "uk_\(wordKey)"
                    let usID = "us_\(wordKey)"
                    let isUkPlaying = (audioPlayerService.isPlaying && audioPlayerService.currentSpeakerID == ukID) ||
                        (speechService.isSpeaking && speechService.currentSpeakerID == ukID)
                    let isUsPlaying = (audioPlayerService.isPlaying && audioPlayerService.currentSpeakerID == usID) ||
                        (speechService.isSpeaking && speechService.currentSpeakerID == usID)

                    NekoAudioButton(
                        label: "UK",
                        isPlaying: isUkPlaying,
                        activeColor: AppColors.accent,
                        action: {
                            if let ukUrl = entry?.ukAudioURL, !ukUrl.isEmpty {
                                audioPlayerService.playAudio(from: ukUrl, fallbackText: wordKey, fallbackVoiceCode: "en-GB", speakerID: ukID)
                            } else {
                                viewModel.speakCustom(text: wordKey, languageCode: "en-GB", speakerID: ukID)
                            }
                        }
                    )

                    NekoAudioButton(
                        label: "US",
                        isPlaying: isUsPlaying,
                        activeColor: AppColors.phonetic,
                        action: {
                            if let usUrl = entry?.usAudioURL, !usUrl.isEmpty {
                                audioPlayerService.playAudio(from: usUrl, fallbackText: wordKey, fallbackVoiceCode: "en-US", speakerID: usID)
                            } else {
                                viewModel.speakCustom(text: wordKey, languageCode: "en-US", speakerID: usID)
                            }
                        }
                    )
                }

                BookmarkBounceButton(isBookmarked: viewModel.isBookmarked) {
                    viewModel.toggleBookmark()
                }
                .help(viewModel.isBookmarked ? l10n[.dictUnbookmark] : l10n[.dictBookmark])
            }

            // Row 2: Direct Translation Card
            HStack(alignment: .center, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(AppColors.accent)
                    .frame(width: 3, height: 18)

                if viewModel.isLoading && viewModel.translatedText.isEmpty && entry == nil {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 140, height: 15)
                        .shimmering(active: true)
                } else {
                    LiveSpokenTextView(
                        text: resolvedTranslation,
                        speakerID: "translated",
                        font: .system(size: 14.5, weight: .semibold),
                        defaultColor: .primary
                    )
                }

                Spacer(minLength: 6)

                if resolvedTranslation != "—" {
                    NekoCopyButton(
                        textToCopy: resolvedTranslation,
                        iconOnly: true,
                        iconSize: 9.5,
                        horizontalPadding: 5,
                        verticalPadding: 3.5
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppColors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.cardBorder, lineWidth: 0.8)
            )
        }
    }

    private func filteredMeanings(for entry: RichWordEntry) -> [MeaningGroup] {
        let validGroups = entry.meanings.filter { !$0.definitions.isEmpty }
        if selectedPOS == "all" {
            return validGroups
        }
        return validGroups.filter { $0.partOfSpeech == selectedPOS }
    }

    // MARK: - Rich Dictionary View
    private func richDictionaryContent(entry: RichWordEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Hero Header: Word + IPA + Audio UK/US + Bookmark
            HStack(alignment: .center, spacing: 8) {
                LiveSpokenTextView(
                    text: entry.word,
                    speakerID: "original",
                    font: .system(size: 19, weight: .bold),
                    defaultColor: .primary
                )

                if settings.showPhonetics {
                    let ukPh = IPANormalizer.normalize(entry.ukPhonetic)
                    let usPh = IPANormalizer.normalize(entry.usPhonetic)
                    let mainPh = IPANormalizer.normalize(entry.phonetic ?? DictionaryService.shared.extractPhonetic(for: entry.word))

                    if let uk = ukPh, let us = usPh, uk != us {
                        HStack(spacing: 4) {
                            Text(verbatim: "🇬🇧 \(uk)")
                                .font(.system(size: 10.5, design: .serif))
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(AppColors.accent.opacity(0.1))
                                .cornerRadius(4)
                                .help("Phát âm Anh - Anh (UK)")

                            Text(verbatim: "🇺🇸 \(us)")
                                .font(.system(size: 10.5, design: .serif))
                                .foregroundColor(AppColors.phonetic)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(AppColors.phoneticSubtle)
                                .cornerRadius(4)
                                .help("Phát âm Anh - Mỹ (US)")
                        }
                    } else if let ph = mainPh ?? usPh ?? ukPh, !ph.isEmpty {
                        Text(ph)
                            .font(.system(size: 11.5, design: .serif))
                            .foregroundColor(AppColors.phonetic)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.phoneticSubtle)
                            .cornerRadius(4.5)
                    }
                }

                // Base Lemma badge for inflected forms (e.g. went -> go)
                if let lemma = entry.baseLemma, !lemma.isEmpty {
                    Button(action: {
                        viewModel.processNestedWord(lemma)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 8.5))
                            Text(.dictBaseLemma(lemma))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help(l10n[.dictLookupLemma(lemma)])
                }

                Spacer(minLength: 4)

                // Audio Waveform Pills: UK & US
                HStack(spacing: 5) {
                    let ukID = "uk_\(entry.word)"
                    let usID = "us_\(entry.word)"
                    let isUkPlaying = (audioPlayerService.isPlaying && audioPlayerService.currentSpeakerID == ukID) ||
                    (speechService.isSpeaking && speechService.currentSpeakerID == ukID)
                    let isUsPlaying = (audioPlayerService.isPlaying && audioPlayerService.currentSpeakerID == usID) ||
                    (speechService.isSpeaking && speechService.currentSpeakerID == usID)

                    NekoAudioButton(
                        label: "UK",
                        isPlaying: isUkPlaying,
                        activeColor: AppColors.accent,
                        action: {
                            if let ukUrl = entry.ukAudioURL, !ukUrl.isEmpty {
                                audioPlayerService.playAudio(from: ukUrl, fallbackText: entry.word, fallbackVoiceCode: "en-GB", speakerID: ukID)
                            } else {
                                viewModel.speakCustom(text: entry.word, languageCode: "en-GB", speakerID: ukID)
                            }
                        }
                    )

                    NekoAudioButton(
                        label: "US",
                        isPlaying: isUsPlaying,
                        activeColor: AppColors.phonetic,
                        action: {
                            if let usUrl = entry.usAudioURL, !usUrl.isEmpty {
                                audioPlayerService.playAudio(from: usUrl, fallbackText: entry.word, fallbackVoiceCode: "en-US", speakerID: usID)
                            } else {
                                viewModel.speakCustom(text: entry.word, languageCode: "en-US", speakerID: usID)
                            }
                        }
                    )
                }

                BookmarkBounceButton(isBookmarked: viewModel.isBookmarked) {
                    viewModel.toggleBookmark()
                }
                .help(viewModel.isBookmarked ? l10n[.dictUnbookmark] : l10n[.dictBookmark])
            }


            // 2. Clean Part-of-Speech Dictionary Layout (Laban / Oxford Anh-Việt Style)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(entry.conciseParts) { part in
                    VStack(alignment: .leading, spacing: 6) {
                        // POS Badge: "Danh từ", "Động từ", "Tính từ"
                        Text(part.partFullName)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.primary.opacity(0.85))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(4)

                        // Vertical bulleted meaning lines (▎ nghĩa 1, ▎ nghĩa 2)
                        VStack(alignment: .leading, spacing: 5) {
                            let cleanMeanings = part.meanings
                                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".;:,- ")) }
                                .filter { !$0.isEmpty }

                            ForEach(Array(cleanMeanings.enumerated()), id: \.offset) { idx, meaning in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(Color(red: 0.56, green: 0.78, blue: 0.12))
                                        .frame(width: 3.5, height: 13)
                                        .offset(y: 1.5)

                                    LiveSpokenTextView(
                                        text: meaning,
                                        speakerID: "part_\(part.part)_\(idx)",
                                        font: .system(size: 13.5, weight: .bold),
                                        defaultColor: .primary
                                    )

                                    Spacer(minLength: 4)
                                }
                                .padding(.leading, 8)
                            }

                            // Inline bilingual example for this POS (if available & enabled)
                            if settings.showExamples,
                               let matchingGroup = entry.meanings.first(where: { $0.partOfSpeechAbbr == part.part }),
                               let firstWithEx = matchingGroup.definitions.first(where: { ($0.exampleEn ?? "").isEmpty == false }),
                               let exEn = firstWithEx.exampleEn {
                                VStack(alignment: .leading, spacing: 2) {
                                    LiveSpokenTextView(
                                        text: exEn,
                                        speakerID: "ex_inline_\(part.part)",
                                        font: .system(size: 12.5, weight: .medium),
                                        defaultColor: Color.blue.opacity(0.85)
                                    )

                                    if let exVi = firstWithEx.exampleVi, !exVi.isEmpty {
                                        Text(exVi)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .textSelection(.enabled)
                                    }
                                }
                                .padding(.leading, 19.5)
                                .padding(.top, 2)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)

            // 3. Collapsible Detailed Definitions & Academic Explanations (On-demand)
            if entry.totalDefinitionsCount > 0 {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        showAdvancedWordDetails.toggle()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: showAdvancedWordDetails ? "chevron.up.circle.fill" : "chevron.down.circle")
                            .font(.system(size: 11))
                        if showAdvancedWordDetails {
                            Text("Thu gọn định nghĩa chi tiết")
                                .font(.system(size: 11, weight: .medium))
                        } else {
                            Text("Xem định nghĩa học thuật & ví dụ (\(entry.totalDefinitionsCount))")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)

                if showAdvancedWordDetails {
                    // Part of Speech Filter Tabs (When multiple parts of speech exist)
                    let validMeaningGroups = entry.meanings.filter { !$0.definitions.isEmpty }
                    if validMeaningGroups.count > 1 {
                        HStack(spacing: 4) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.12)) { selectedPOS = "all" }
                            }) {
                                let total = validMeaningGroups.reduce(0) { $0 + $1.definitions.count }
                                Text(.dictAllDefinitions(total))
                                    .font(.system(size: 10, weight: selectedPOS == "all" ? .bold : .medium))
                                    .foregroundColor(selectedPOS == "all" ? .white : .secondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2.5)
                                    .background(selectedPOS == "all" ? AppColors.accent : Color.primary.opacity(0.04))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            ForEach(validMeaningGroups) { group in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.12)) { selectedPOS = group.partOfSpeech }
                                }) {
                                    Text(verbatim: "\(group.partOfSpeechDisplay) (\(group.definitions.count))")
                                        .font(.system(size: 10, weight: selectedPOS == group.partOfSpeech ? .bold : .medium))
                                        .foregroundColor(selectedPOS == group.partOfSpeech ? .white : .secondary)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2.5)
                                        .background(selectedPOS == group.partOfSpeech ? AppColors.accent : Color.primary.opacity(0.04))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 1)
                    }

                    // Detailed Meaning Groups
                    ForEach(filteredMeanings(for: entry)) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(group.partOfSpeechDisplay)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.accent)
                                    .cornerRadius(4)

                                Spacer()

                                Text(.dictDefinitionsCount(group.definitions.count))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }

                            Divider()
                                .opacity(0.15)

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(group.definitions.enumerated()), id: \.offset) { index, item in
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(alignment: .top, spacing: 4) {
                                            Text(verbatim: "\(index + 1).")
                                                .font(.system(size: 11.5, weight: .bold))
                                                .foregroundColor(.secondary.opacity(0.8))

                                            LiveSpokenTextView(
                                                text: item.definitionEn,
                                                speakerID: "def_\(group.partOfSpeech)_\(index)",
                                                font: .system(size: 12, weight: .medium),
                                                defaultColor: .primary.opacity(0.9)
                                            )

                                            Button(action: {
                                                viewModel.speakCustom(text: item.definitionEn, languageCode: "en-US", speakerID: "def_\(group.partOfSpeech)_\(index)")
                                            }) {
                                                Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "def_\(group.partOfSpeech)_\(index)") ? "speaker.wave.3.fill" : "speaker.wave.1")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(AppColors.accent.opacity(0.8))
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        if let vi = item.definitionVi, !vi.isEmpty {
                                            HStack(alignment: .top, spacing: 4) {
                                                Image(systemName: "arrow.turn.down.right")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(AppColors.accent.opacity(0.7))
                                                    .padding(.top, 2)
                                                LiveSpokenTextView(
                                                    text: vi,
                                                    speakerID: "def_vi_\(group.partOfSpeech)_\(index)",
                                                    font: .system(size: 12, weight: .semibold),
                                                    defaultColor: AppColors.accent
                                                )
                                            }
                                            .padding(.leading, 10)
                                        }

                                        if settings.showExamples {
                                            if let exEn = item.exampleEn, !exEn.isEmpty {
                                                HStack(alignment: .top, spacing: 6) {
                                                    RoundedRectangle(cornerRadius: 1)
                                                        .fill(Color.blue.opacity(0.35))
                                                        .frame(width: 2)

                                                    VStack(alignment: .leading, spacing: 2) {
                                                        HStack(alignment: .top, spacing: 4) {
                                                            LiveSpokenTextView(
                                                                text: exEn,
                                                                speakerID: "ex_\(group.partOfSpeech)_\(index)",
                                                                font: .system(size: 11, design: .serif),
                                                                defaultColor: .secondary
                                                            )
                                                            .italic()

                                                            Button(action: {
                                                                viewModel.speakCustom(text: exEn, languageCode: "en-US", speakerID: "ex_\(group.partOfSpeech)_\(index)")
                                                            }) {
                                                                Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "ex_\(group.partOfSpeech)_\(index)") ? "speaker.wave.3.fill" : "speaker.wave.1")
                                                                    .font(.system(size: 8.5))
                                                                    .foregroundColor(.secondary)
                                                            }
                                                            .buttonStyle(.plain)
                                                        }

                                                        if let exVi = item.exampleVi, !exVi.isEmpty {
                                                            Text(exVi)
                                                                .font(.system(size: 10.5))
                                                                .foregroundColor(.secondary.opacity(0.75))
                                                                .textSelection(.enabled)
                                                        }
                                                    }
                                                }
                                                .padding(.leading, 10)
                                                .padding(.top, 1)
                                            }
                                        }
                                    }
                                }
                            }

                            if settings.showSynonyms && !group.synonyms.isEmpty {
                                synonymTagSection(title: .dictSynonyms, tags: group.synonyms)
                            }
                        }
                        .padding(9)
                        .background(AppColors.cardBackground)
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(AppColors.cardBorder, lineWidth: 0.8)
                        )
                    }
                }
            }

            let hasExtraTags = (settings.showSynonyms && (!entry.allSynonyms.isEmpty || !entry.allAntonyms.isEmpty)) || !entry.semanticNeighbors.isEmpty
            if hasExtraTags {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        showSynonymsAndNeighbors.toggle()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: showSynonymsAndNeighbors ? "chevron.up.circle.fill" : "chevron.down.circle")
                            .font(.system(size: 11))
                        Text(.dictSynonymsAndMore(entry.allSynonyms.count + entry.semanticNeighbors.count))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)

                if showSynonymsAndNeighbors {
                    VStack(alignment: .leading, spacing: 6) {
                        if settings.showSynonyms && !entry.allSynonyms.isEmpty {
                            synonymTagSection(title: .dictSynonymsExpanded, tags: entry.allSynonyms)
                        }

                        if settings.showSynonyms && !entry.allAntonyms.isEmpty {
                            synonymTagSection(title: .dictAntonymsExpanded, tags: entry.allAntonyms)
                        }

                        if !entry.semanticNeighbors.isEmpty {
                            synonymTagSection(title: .dictSemanticNeighbors, tags: entry.semanticNeighbors)
                        }
                    }
                    .padding(.top, 2)
                }
            }

        }
    }

    // MARK: - Dictionary Loading Skeleton (Matches Rich Content Layout)
    private var dictionaryLoadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Hero Header matching richDictionaryContent
            HStack(alignment: .center, spacing: 8) {
                Text(viewModel.originalText.capitalized)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.primary)

                let localPhonetic = IPANormalizer.normalize(DictionaryService.shared.extractPhonetic(for: viewModel.originalText))
                if let ph = localPhonetic, !ph.isEmpty {
                    Text(ph)
                        .font(.system(size: 11.5, design: .serif))
                        .foregroundColor(AppColors.phonetic)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.phoneticSubtle)
                        .cornerRadius(4.5)
                }

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    Text("UK")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(4)

                    Text("US")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(4)
                }
            }

            // Skeleton POS Summary Card (matching richDictionaryContent)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("n.")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.accent.opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.accent.opacity(0.08))
                        .cornerRadius(4)

                    if !viewModel.translatedText.isEmpty {
                        Text(viewModel.translatedText)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(.primary)
                    } else {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 140, height: 14)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    Text("v.")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.accent.opacity(0.4))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.accent.opacity(0.06))
                        .cornerRadius(4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 180, height: 14)
                    Spacer()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppColors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.cardBorder, lineWidth: 0.8)
            )
            .shimmering(active: true)
        }
    }

    // MARK: - Dictionary Fallback View
    private var dictionaryFallbackView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 7) {
                LiveSpokenTextView(
                    text: viewModel.originalText.capitalized,
                    speakerID: "original",
                    font: .appTitleMedium,
                    defaultColor: .primary
                )

                let phoneticString = DictionaryService.shared.extractPhonetic(for: viewModel.originalText)
                if settings.showPhonetics, let phonetic = phoneticString, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.appPhonetic)
                        .foregroundColor(AppColors.phonetic)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.phoneticSubtle)
                        .cornerRadius(4)
                }

                Spacer(minLength: 4)

                // Pronunciation Buttons: UK & US Audio / TTS
                HStack(spacing: 4.5) {
                    // UK Audio Button
                    Button(action: {
                        viewModel.speakCustom(text: viewModel.originalText, languageCode: "en-GB", speakerID: "uk_\(viewModel.originalText)")
                    }) {
                        HStack(spacing: 3) {
                            Text("🇬🇧")
                                .font(.appSubcaption)
                            Text("UK")
                                .font(.appSubcaptionBold)
                            EqualizerWaveView(
                                isActive: speechService.isSpeaking && speechService.currentSpeakerID == "uk_\(viewModel.originalText)",
                                barColor: AppColors.accent,
                                height: 9
                            )
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(AppColors.accentSubtle)
                        .foregroundColor(AppColors.accent)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help(l10n[.dictPronounceUk])

                    // US Audio Button
                    Button(action: {
                        viewModel.speakCustom(text: viewModel.originalText, languageCode: "en-US", speakerID: "us_\(viewModel.originalText)")
                    }) {
                        HStack(spacing: 3) {
                            Text("🇺🇸")
                                .font(.appSubcaption)
                            Text("US")
                                .font(.appSubcaptionBold)
                            EqualizerWaveView(
                                isActive: speechService.isSpeaking && speechService.currentSpeakerID == "us_\(viewModel.originalText)",
                                barColor: AppColors.phonetic,
                                height: 9
                            )
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(AppColors.phoneticSubtle)
                        .foregroundColor(AppColors.phonetic)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help(l10n[.dictPronounceUs])
                }

                BookmarkBounceButton(isBookmarked: viewModel.isBookmarked) {
                    viewModel.toggleBookmark()
                }
                .help(viewModel.isBookmarked ? l10n[.dictUnbookmark] : l10n[.dictBookmark])
            }

            HStack(alignment: .center, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(AppColors.accent)
                    .frame(width: 3, height: 16)

                LiveSpokenTextView(
                    text: viewModel.translatedText.isEmpty ? "—" : viewModel.translatedText,
                    speakerID: "translated",
                    font: .system(size: 14.5, weight: .bold),
                    defaultColor: AppColors.accent
                )

                Spacer()

                if !viewModel.translatedText.isEmpty {
                    NekoCopyButton(textToCopy: viewModel.translatedText)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.025))
            .cornerRadius(6)

            if let def = viewModel.definition, !def.isEmpty {
                DisclosureGroup {
                    Text(def)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 9.5))
                            .foregroundColor(AppColors.phonetic)
                        Text(.dictMacosDictionary)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(AppColors.phonetic)
                    }
                }
                .font(.system(size: 11))
                .accentColor(.secondary)
                .padding(8)
                .background(AppColors.cardBackground)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppColors.cardBorder, lineWidth: 0.8)
                )
            }
        }
    }

    // MARK: - Tag Section
    private func synonymTagSection(title: LocalizedStringResource, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appCaptionBold)
                .foregroundColor(.secondary)

            WrappingHStack(models: tags) { tag in
                Button(action: {
                    viewModel.processNestedWord(tag)
                }) {
                    Text(tag)
                        .font(.appCaptionMedium)
                        .foregroundColor(.primary.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(AppColors.tagBackground)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppColors.tagBorder, lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Previews

#Preview("Dictionary — Từ điển chi tiết (Rich Entry)") {
    let vm = TranslationViewModel()
    vm.originalText = "serendipity"
    vm.translatedText = "sự tình cờ may mắn"
    vm.detectedLanguage = "en"
    vm.richEntry = RichWordEntry(
        word: "serendipity",
        phonetic: "/ˌser.ənˈdɪp.ə.ti/",
        ukAudioURL: nil,
        usAudioURL: nil,
        mainTranslation: "sự tình cờ may mắn",
        meanings: [
            MeaningGroup(
                partOfSpeech: "noun",
                definitions: [
                    DefinitionItem(
                        definitionEn: "The occurrence and development of events by chance in a happy or beneficial way.",
                        definitionVi: "Khả năng tình cờ tìm thấy những điều bất ngờ thú vị và may mắn.",
                        exampleEn: "A fortunate stroke of serendipity brought them together.",
                        exampleVi: "Một cơ duyên may mắn đầy bất ngờ đã đưa họ đến với nhau."
                    )
                ],
                synonyms: ["chance", "happy accident", "fluke"],
                antonyms: ["misfortune"]
            )
        ],
        allSynonyms: ["chance", "happy accident", "fluke"],
        allAntonyms: ["misfortune"],
        semanticNeighbors: ["destiny", "coincidence", "fortune"]
    )
    return LocalizedRootView {
        ScrollView {
            TranslationHUDDictionaryView(viewModel: vm)
                .padding(16)
        }
        .frame(width: 515, height: 350)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("Dictionary — Đa từ loại (Multi-POS)") {
    let vm = TranslationViewModel()
    vm.originalText = "book"
    vm.translatedText = "quyển sách, đặt vé/phòng"
    vm.detectedLanguage = "en"
    vm.richEntry = RichWordEntry(
        word: "book",
        phonetic: "/bʊk/",
        ukAudioURL: nil,
        usAudioURL: nil,
        mainTranslation: "quyển sách, đặt vé/phòng",
        meanings: [
            MeaningGroup(
                partOfSpeech: "noun",
                definitions: [
                    DefinitionItem(
                        definitionEn: "A written or printed work consisting of pages bound together.",
                        definitionVi: "Cuốn sách, tác phẩm viết hoặc in gồm nhiều trang ghép lại.",
                        exampleEn: "She read a whole book in one afternoon.",
                        exampleVi: "Cô ấy đã đọc xong cả cuốn sách trong một buổi chiều."
                    )
                ],
                synonyms: ["volume", "tome", "publication"],
                antonyms: []
            ),
            MeaningGroup(
                partOfSpeech: "verb",
                definitions: [
                    DefinitionItem(
                        definitionEn: "Reserve accommodations, a place, or tickets to an event.",
                        definitionVi: "Đặt trước phòng, chỗ ngồi hoặc vé tham dự.",
                        exampleEn: "I booked a flight to Tokyo for next month.",
                        exampleVi: "Tôi đã đặt vé máy bay đi Tokyo cho tháng sau."
                    )
                ],
                synonyms: ["reserve", "order", "schedule"],
                antonyms: ["cancel"]
            )
        ],
        allSynonyms: ["volume", "reserve", "tome"],
        allAntonyms: ["cancel"],
        semanticNeighbors: ["author", "reading", "library", "ticket"]
    )
    return LocalizedRootView {
        ScrollView {
            TranslationHUDDictionaryView(viewModel: vm)
                .padding(16)
        }
        .frame(width: 515, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("Dictionary — Từ điển mặc định (Fallback)") {
    let vm = TranslationViewModel()
    vm.originalText = "resilience"
    vm.translatedText = "sự kiên cường, khả năng phục hồi"
    vm.definition = "The capacity to recover quickly from difficulties; toughness."
    vm.detectedLanguage = "en"
    return LocalizedRootView {
        ScrollView {
            TranslationHUDDictionaryView(viewModel: vm)
                .padding(16)
        }
        .frame(width: 515, height: 240)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("Dictionary — Đang tải (Loading Skeleton)") {
    let vm = TranslationViewModel()
    vm.originalText = "ephemeral"
    vm.isLoading = true
    return LocalizedRootView {
        ScrollView {
            TranslationHUDDictionaryView(viewModel: vm)
                .padding(16)
        }
        .frame(width: 515, height: 200)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("Dictionary — Chế độ tối (Dark Mode)") {
    let vm = TranslationViewModel()
    vm.originalText = "serendipity"
    vm.translatedText = "sự tình cờ may mắn"
    vm.detectedLanguage = "en"
    vm.richEntry = RichWordEntry(
        word: "serendipity",
        phonetic: "/ˌser.ənˈdɪp.ə.ti/",
        ukAudioURL: nil,
        usAudioURL: nil,
        mainTranslation: "sự tình cờ may mắn",
        meanings: [
            MeaningGroup(
                partOfSpeech: "noun",
                definitions: [
                    DefinitionItem(
                        definitionEn: "The occurrence and development of events by chance in a happy or beneficial way.",
                        definitionVi: "Khả năng tình cờ tìm thấy những điều bất ngờ thú vị và may mắn.",
                        exampleEn: "A fortunate stroke of serendipity brought them together.",
                        exampleVi: "Một cơ duyên may mắn đầy bất ngờ đã đưa họ đến với nhau."
                    )
                ],
                synonyms: ["chance", "happy accident", "fluke"],
                antonyms: ["misfortune"]
            )
        ],
        allSynonyms: ["chance", "happy accident", "fluke"],
        allAntonyms: ["misfortune"],
        semanticNeighbors: ["destiny", "coincidence", "fortune"]
    )
    return LocalizedRootView {
        ScrollView {
            TranslationHUDDictionaryView(viewModel: vm)
                .padding(16)
        }
        .frame(width: 515, height: 350)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    .preferredColorScheme(.dark)
}

