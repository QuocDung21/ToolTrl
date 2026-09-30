import SwiftUI

public struct WordDetailHeaderView: View {
    public let item: SavedWordItem
    public let richDictionaryEntry: RichWordEntry?
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var speechService = SpeechService.shared
    @ObservedObject var audioPlayerService = AudioPlayerService.shared
    @State private var showDeleteConfirmation: Bool = false
    @State private var showEditSheet: Bool = false
    
    public init(item: SavedWordItem, richDictionaryEntry: RichWordEntry?) {
        self.item = item
        self.richDictionaryEntry = richDictionaryEntry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // Title + Phonetic IPA + Human Audio Buttons inline
                HStack(alignment: .center, spacing: 8) {
                    Text(item.cleanTitle)
                        .font(.appTitleLarge)
                        .foregroundColor(.primary)
                    
                    if item.isGrammarFormula {
                        Text("CÔNG THỨC")
                            .font(.appSubcaptionBold)
                            .foregroundColor(AppColors.grammar)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.grammarSubtle)
                            .cornerRadius(4)
                    } else if let ph = item.phonetic, !ph.isEmpty {
                        Text(ph)
                            .font(.appPhonetic)
                            .foregroundColor(AppColors.phonetic)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.phoneticSubtle)
                            .cornerRadius(4)
                    }
                    
                    if !item.isGrammarFormula {
                        // UK & US Audio Buttons
                        HStack(spacing: 4) {
                            let ukID = "uk_\(item.id.uuidString)"
                            let usID = "us_\(item.id.uuidString)"
                            let isUkPlaying = (audioPlayerService.isPlaying && audioPlayerService.currentSpeakerID == ukID) ||
                                              (speechService.isSpeaking && speechService.currentSpeakerID == ukID)
                            let isUsPlaying = (audioPlayerService.isPlaying && audioPlayerService.currentSpeakerID == usID) ||
                                              (speechService.isSpeaking && speechService.currentSpeakerID == usID)
                            
                            Button(action: {
                                if let ukUrl = richDictionaryEntry?.ukAudioURL, !ukUrl.isEmpty {
                                    audioPlayerService.playAudio(from: ukUrl, fallbackText: item.word, fallbackVoiceCode: "en-GB", speakerID: ukID)
                                } else {
                                    speechService.speak(text: item.word, languageCode: "en-GB", speakerID: ukID)
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Text("🇬🇧")
                                        .font(.appSubcaption)
                                    Text("UK")
                                        .font(.appSubcaptionBold)
                                    EqualizerWaveView(isActive: isUkPlaying, barColor: AppColors.accent, height: 9)
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(isUkPlaying ? AppColors.accent.opacity(0.18) : AppColors.accentSubtle)
                                .foregroundColor(AppColors.accent)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help("Phát âm Anh - Anh (UK)")
                            
                            Button(action: {
                                if let usUrl = richDictionaryEntry?.usAudioURL, !usUrl.isEmpty {
                                    audioPlayerService.playAudio(from: usUrl, fallbackText: item.word, fallbackVoiceCode: "en-US", speakerID: usID)
                                } else {
                                    speechService.speak(text: item.word, languageCode: "en-US", speakerID: usID)
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Text("🇺🇸")
                                        .font(.appSubcaption)
                                    Text("US")
                                        .font(.appSubcaptionBold)
                                    EqualizerWaveView(isActive: isUsPlaying, barColor: AppColors.phonetic, height: 9)
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(isUsPlaying ? AppColors.phonetic.opacity(0.2) : AppColors.phoneticSubtle)
                                .foregroundColor(AppColors.phonetic)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help("Phát âm Anh - Mỹ (US)")
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons (Favorite & Mastered)
                HStack(spacing: 12) {
                    Button(action: {
                        vocabService.toggleFavorite(id: item.id)
                    }) {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundColor(item.isFavorite ? .yellow : .secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help(item.isFavorite ? "Bỏ yêu thích" : "Đánh dấu yêu thích")
                    
                    Button(action: {
                        vocabService.toggleMastered(id: item.id)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: item.isMastered ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13))
                            Text(item.isMastered ? "Đã thuộc" : "Chưa thuộc")
                                .font(.appCaptionMedium)
                        }
                        .foregroundColor(item.isMastered ? AppColors.success : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(item.isMastered ? AppColors.successSubtle : AppColors.cardBackground)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help(item.isMastered ? "Đánh dấu chưa thuộc" : "Đánh dấu đã thuộc")
                    
                    Button(action: {
                        showEditSheet = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Chỉnh sửa từ vựng...")
                    .sheet(isPresented: $showEditSheet) {
                        AddWordSheet(editingItem: item)
                    }
                    
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Xóa từ vựng này khỏi sổ tay")
                    .confirmationDialog(
                        "Xóa '\(item.cleanTitle)' khỏi sổ tay?",
                        isPresented: $showDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Xóa", role: .destructive) {
                            vocabService.removeWord(id: item.id)
                        }
                        Button("Hủy", role: .cancel) {}
                    } message: {
                        Text("Mục này sẽ bị xóa vĩnh viễn khỏi sổ tay của bạn.")
                    }
                }
                .padding(.top, 2)
            }
            
            // Smart Category & Genre Pills
            HStack(spacing: 6) {
                Label(item.aiPriority.rawValue, systemImage: "tag")
                    .font(.appSubcaptionBold)
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(AppColors.accentSubtle)
                    .cornerRadius(4)
                
                Label(item.aiThematicGenre.rawValue, systemImage: "folder")
                    .font(.appSubcaption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(AppColors.tagBackground)
                    .cornerRadius(4)
                
                Label(item.aiPartOfSpeech.rawValue, systemImage: "tag")
                    .font(.appSubcaption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(AppColors.tagBackground)
                    .cornerRadius(4)
            }
        }
    }
}
