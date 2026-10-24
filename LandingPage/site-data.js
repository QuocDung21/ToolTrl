/* ============================================================================
   NekoTrans — site data & runtime metrics
   Nguồn thông số kỹ thuật duy nhất cho Landing Page.
   Mọi số liệu, phiên bản, phím tắt và đường dẫn được quản lý tại đây.
   ========================================================================= */
window.SITE_DATA = {
  version: "1.0.0",
  minimumMacOS: "15.0",
  releaseSize: "14 MB",
  localDataPercentage: "100%",

  shortcuts: {
    translate: "⌥D",
    ocr: "⌥S",
    ai: "⌥A",
    notebook: "⌥V",
    silentOCR: "⌥⇧S",
    translateAndReplace: "⌥⇧T",
    polishAndReplace: "⌥⇧P"
  },

  aiProviders: [
    { id: "openai", name: "OpenAI" },
    { id: "anthropic", name: "Claude" },
    { id: "gemini", name: "Gemini" },
    { id: "deepseek", name: "DeepSeek" },
    { id: "groq", name: "Groq" },
    { id: "gguf", name: "GGUF Metal" }
  ],
  aiProviderNames: "OpenAI · Claude · Gemini · DeepSeek · Groq · GGUF Metal",

  analysisSections: [
    { id: "pos_senses", name: "Từ loại & Tầng nghĩa" },
    { id: "word_family", name: "Họ từ" },
    { id: "collocations", name: "Collocations" },
    { id: "nuances", name: "Phân biệt sắc thái" },
    { id: "examples", name: "Ví dụ song ngữ" },
    { id: "mnemonic", name: "Mẹo ghi nhớ" }
  ],
  analysisNames: {
    vi: "từ loại · họ từ · collocation · sắc thái · ví dụ · mẹo nhớ",
    en: "POS & senses · word family · collocations · nuances · examples · mnemonic"
  },

  links: {
    download: "https://github.com/QuocDung21/ToolTrl/releases/latest",
    source: "https://github.com/QuocDung21/ToolTrl",
    changelog: "https://github.com/QuocDung21/ToolTrl/releases",
    support: "https://github.com/QuocDung21/ToolTrl/issues",
    privacy: "#rieng-tu"
  }
};
