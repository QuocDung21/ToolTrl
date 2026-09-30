import SwiftUI

public struct TranslationHUDDictionaryView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject var speechService = SpeechService.shared
    @ObservedObject var audioPlayerService = AudioPlayerService.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var showAdvancedWordDetails: Bool = false
    @State private var selectedPOS: String = "all"
    @State private var copiedMainTranslation: Bool = false
    
    public init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Group {
            if let rich = viewModel.richEntry {
                richDictionaryContent(entry: rich)
            } else if viewModel.isLoading {
                dictionaryLoadingSkeleton
            } else {
                dictionaryFallbackView
            }
        }
    }
    
    private func filteredMeanings(for entry: RichWordEntry) -> [MeaningGroup] {
        if selectedPOS == "all" {
            return entry.meanings
        }
        return entry.meanings.filter { $0.partOfSpeech == selectedPOS }
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
                
                let phoneticString = (entry.phonetic != nil && !entry.phonetic!.isEmpty) ? entry.phonetic : DictionaryService.shared.extractPhonetic(for: entry.word)
                if settings.showPhonetics, let phonetic = phoneticString, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.system(size: 11.5, design: .serif))
                        .foregroundColor(AppColors.phonetic)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.phoneticSubtle)
                        .cornerRadius(4.5)
                }
                
                // Base Lemma badge for inflected forms (e.g. went -> go)
                if let lemma = entry.baseLemma, !lemma.isEmpty {
                    Button(action: {
                        viewModel.processNestedWord(lemma)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 8.5))
                            Text("Gốc: \(lemma)")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Tra cứu từ nguyên thể '\(lemma)'")
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
                .help(viewModel.isBookmarked ? "Bỏ lưu từ này" : "Lưu vào sổ từ vựng")
            }
            
            // 2. Main Vietnamese Translation Card with 1-Click Copy
            HStack(alignment: .center, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(AppColors.accent)
                    .frame(width: 3, height: 16)
                
                LiveSpokenTextView(
                    text: entry.mainTranslation,
                    speakerID: "translated",
                    font: .system(size: 15, weight: .bold),
                    defaultColor: AppColors.accent
                )
                
                Spacer()
                
                NekoCopyButton(textToCopy: entry.mainTranslation)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.025))
            .cornerRadius(6)

            // 3. Part of Speech Filter Tabs (When multiple parts of speech exist)
            if entry.meanings.count > 1 {
                HStack(spacing: 4) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.12)) { selectedPOS = "all" }
                    }) {
                        let total = entry.meanings.reduce(0) { $0 + $1.definitions.count }
                        Text("Tất cả (\(total))")
                            .font(.system(size: 10, weight: selectedPOS == "all" ? .bold : .medium))
                            .foregroundColor(selectedPOS == "all" ? .white : .secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(selectedPOS == "all" ? AppColors.accent : Color.primary.opacity(0.04))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(entry.meanings) { group in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.12)) { selectedPOS = group.partOfSpeech }
                        }) {
                            Text("\(group.partOfSpeechDisplay) (\(group.definitions.count))")
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
            
            // 4. Meaning Groups
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
                        
                        Text("\(group.definitions.count) định nghĩa")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .opacity(0.15)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(group.definitions.enumerated()), id: \.offset) { index, item in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(alignment: .top, spacing: 4) {
                                    Text("\(index + 1).")
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
                        synonymTagSection(title: "Từ đồng nghĩa:", tags: group.synonyms)
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
            
            let hasExtraTags = (settings.showSynonyms && (!entry.allSynonyms.isEmpty || !entry.allAntonyms.isEmpty)) || !entry.semanticNeighbors.isEmpty
            if hasExtraTags {
                DisclosureGroup(isExpanded: $showAdvancedWordDetails) {
                    VStack(alignment: .leading, spacing: 6) {
                        if settings.showSynonyms && !entry.allSynonyms.isEmpty {
                            synonymTagSection(title: "Từ đồng nghĩa (Synonyms):", tags: entry.allSynonyms)
                        }
                        
                        if settings.showSynonyms && !entry.allAntonyms.isEmpty {
                            synonymTagSection(title: "Từ trái nghĩa (Antonyms):", tags: entry.allAntonyms)
                        }
                        
                        if !entry.semanticNeighbors.isEmpty {
                            synonymTagSection(title: "Từ liên quan ngữ nghĩa:", tags: entry.semanticNeighbors)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 9))
                        Text("Từ đồng nghĩa & Mở rộng (\(entry.allSynonyms.count + entry.semanticNeighbors.count))")
                            .font(.appSubcaptionBold)
                    }
                    .foregroundColor(.secondary)
                }
                .font(.appSubcaption)
                .accentColor(.secondary)
            }
        }
    }
    
    // MARK: - Dictionary Loading Skeleton
    private var dictionaryLoadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(viewModel.originalText.capitalized)
                    .font(.appTitleMedium)
                    .foregroundColor(.primary)
                
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                
                Spacer()
            }
            
            Text(viewModel.translatedText.isEmpty ? "Đang phân tích từ điển..." : viewModel.translatedText)
                .font(.appHeadline)
                .foregroundColor(viewModel.translatedText.isEmpty ? .secondary : AppColors.accent)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.07))
                    .frame(width: 100, height: 16)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.05))
                    .frame(maxWidth: .infinity, maxHeight: 12)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 200, height: 12)
            }
            .padding(10)
            .background(AppColors.cardBackground)
            .cornerRadius(6)
            .shimmering(active: viewModel.isLoading)
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
                    .help("Phát âm Anh - Anh (UK)")
                    
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
                    .help("Phát âm Anh - Mỹ (US)")
                }
                
                BookmarkBounceButton(isBookmarked: viewModel.isBookmarked) {
                    viewModel.toggleBookmark()
                }
                .help(viewModel.isBookmarked ? "Bỏ lưu từ này" : "Lưu vào sổ từ vựng")
            }
            
            LiveSpokenTextView(
                text: viewModel.translatedText.isEmpty ? "—" : viewModel.translatedText,
                speakerID: "translated",
                font: .appHeadlineBold,
                defaultColor: AppColors.accent
            )
            
            if let def = viewModel.definition, !def.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "book.fill")
                            .font(.system(size: 9.5))
                            .foregroundColor(AppColors.phonetic)
                        Text("TỪ ĐIỂN MACOS")
                            .font(.appSubcaptionBold)
                            .foregroundColor(AppColors.phonetic)
                    }
                    Text(def)
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .padding(8)
                .background(AppColors.cardBackground)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Tag Section
    private func synonymTagSection(title: String, tags: [String]) -> some View {
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
