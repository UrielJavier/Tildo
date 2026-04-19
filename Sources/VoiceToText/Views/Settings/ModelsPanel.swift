import SwiftUI
import Darwin

// Fast / Balanced / Precise — the three curated tiers shown in the 3-card grid
private struct ModelTier {
    let name: String
    let subtitle: String
    let speed: String
    let quality: String
    let model: WhisperModel
    let isRecommended: Bool
}

struct ModelsPanel: View {
    @Bindable var state: AppState
    var onDownloadModel: ((WhisperModel) -> Void)?
    var onLoadModel: ((WhisperModel) -> Void)?
    var onCancelDownload: (() -> Void)?

    @State private var showAllModels = false
    @State private var showCustomModel = false

    private let tiers: [ModelTier] = [
        ModelTier(name: "Fast",     subtitle: "Great for quick messages, notes, and live dictation.",
             speed: "Very fast", quality: "Good",      model: .baseQ5,         isRecommended: false),
        ModelTier(name: "Balanced", subtitle: "Strong accuracy without slowing things down.",
             speed: "Fast",      quality: "Very good", model: .smallQ5,        isRecommended: false),
        ModelTier(name: "Precise",  subtitle: "Near-max accuracy, much faster than Large.",
             speed: "Fast",      quality: "Excellent", model: .largeV3TurboQ5, isRecommended: true),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHero(
                icon: "cpu",
                title: "Models",
                subtitle: "Pick the Whisper model that fits your Mac. Everything runs locally — nothing leaves your device."
            )
            .padding(.horizontal, 28)
            .padding(.top, 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Hardware detect banner
                    hardwareBanner
                        .padding(.horizontal, 28)

                    // 3-card horizontal grid
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(tiers, id: \.name) { tier in
                            RecommendedModelCard(
                                tier: tier,
                                isLoaded: state.model == tier.model && state.isModelLoaded,
                                isDownloading: state.downloadingModel == tier.model,
                                downloadProgress: state.downloadProgress,
                                modelListVersion: state.modelListVersion,
                                onDownload: { onDownloadModel?(tier.model) },
                                onLoad: { onLoadModel?(tier.model) },
                                onCancel: { onCancelDownload?() }
                            )
                        }
                    }
                    .padding(.horizontal, 28)

                    // More models card
                    moreModelsCard
                        .padding(.horizontal, 28)

                    // Path footnote
                    footnote
                        .padding(.horizontal, 28)
                        .padding(.bottom, 28)
                }
                .padding(.top, 12)
            }
        }
        .sheet(isPresented: $showAllModels) {
            AllModelsSheet(
                state: state,
                onDownloadModel: onDownloadModel,
                onLoadModel: onLoadModel,
                onCancelDownload: onCancelDownload,
                onDismiss: { showAllModels = false }
            )
        }
        .sheet(isPresented: $showCustomModel) {
            CustomModelSheet(onDismiss: { showCustomModel = false })
        }
    }

    // MARK: - Hardware banner

    private var hardwareBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(DS.Colors.moss)
                .frame(width: 6, height: 6)
            Text("Your Mac is \(chipName) — you can run any model")
                .font(DS.Fonts.sans(11))
                .foregroundStyle(DS.Colors.ink2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(DS.Colors.panel)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(DS.Colors.line, lineWidth: 1))
    }

    private var chipName: String {
        var size = MemoryLayout<Int32>.size
        var arm64: Int32 = 0
        sysctlbyname("hw.optional.arm64", &arm64, &size, nil, 0)
        return arm64 == 1 ? "Apple Silicon" : "Intel"
    }

    // MARK: - More models card

    private var moreModelsCard: some View {
        VStack(spacing: 0) {
            MoreModelsRow(
                title: "See all models",
                subtitle: "21 Whisper models from ggerganov/whisper.cpp"
            ) { showAllModels = true }

            Rectangle().fill(DS.Colors.line).frame(height: 1)

            MoreModelsRow(
                title: "Use a custom GGML",
                subtitle: "Load any fine-tuned .bin compatible with whisper.cpp"
            ) { showCustomModel = true }
        }
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
    }

    // MARK: - Footnote

    private var footnote: some View {
        HStack(spacing: 4) {
            Text("Source:")
                .font(DS.Fonts.sans(11))
                .foregroundStyle(DS.Colors.ink4)
            Text("huggingface.co/ggerganov/whisper.cpp")
                .font(DS.Fonts.mono(10.5))
                .foregroundStyle(DS.Colors.ink4)
            Text("· stored at")
                .font(DS.Fonts.sans(11))
                .foregroundStyle(DS.Colors.ink4)
            Text("~/.voicetotext/models")
                .font(DS.Fonts.mono(10.5))
                .foregroundStyle(DS.Colors.ink4)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - MoreModelsRow

private struct MoreModelsRow: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Fonts.sans(13, weight: .semibold))
                        .foregroundStyle(DS.Colors.ink)
                    Text(subtitle)
                        .font(DS.Fonts.sans(11))
                        .foregroundStyle(DS.Colors.ink3)
                }
                Spacer()
                Text("→")
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.ink3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isHovered ? DS.Colors.panel : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Recommended model card

private struct RecommendedModelCard: View {
    let tier: ModelTier
    let isLoaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let modelListVersion: Int
    let onDownload: () -> Void
    let onLoad: () -> Void
    let onCancel: () -> Void

    private var isInstalled: Bool {
        let _ = modelListVersion
        return tier.model.isDownloaded
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Top: name + size chip
                HStack {
                    Text(tier.name)
                        .font(DS.Fonts.sans(14, weight: .semibold))
                        .foregroundStyle(DS.Colors.ink)
                    Spacer()
                    Text(tier.model.ramUsage)
                        .font(DS.Fonts.mono(10.5))
                        .foregroundStyle(DS.Colors.ink4)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

                // Subtitle — min-height 32 to keep cards aligned
                Text(tier.subtitle)
                    .font(DS.Fonts.sans(11.5))
                    .foregroundStyle(DS.Colors.ink3)
                    .lineSpacing(tier.subtitle.count > 40 ? 1 : 0)
                    .frame(minHeight: 32, alignment: .top)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)

                // Separator
                Rectangle().fill(DS.Colors.line).frame(height: 1)

                // Stats
                VStack(alignment: .leading, spacing: 3) {
                    Text("Speed · \(tier.speed)")
                        .font(DS.Fonts.mono(10.5))
                        .foregroundStyle(DS.Colors.ink4)
                    Text("Quality · \(tier.quality)")
                        .font(DS.Fonts.mono(10.5))
                        .foregroundStyle(DS.Colors.ink4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Spacer()

                // Action pinned to bottom
                Group {
                    if isDownloading {
                        downloadingAction
                    } else if isInstalled && isLoaded {
                        inUseAction
                    } else if isInstalled {
                        useThisAction
                    } else {
                        downloadAction
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
            .background(DS.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(isLoaded ? DS.Colors.ink : DS.Colors.line, lineWidth: isLoaded ? 1.5 : 1)
            )

            // RECOMMENDED floating badge
            if tier.isRecommended {
                Text("RECOMMENDED")
                    .font(DS.Fonts.mono(9.5, weight: .medium))
                    .foregroundStyle(DS.Colors.paper)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(DS.Colors.moss)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .offset(x: -6, y: -6)
            }
        }
    }

    private var downloadingAction: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(DS.Colors.line).frame(height: 3)
                RoundedRectangle(cornerRadius: 2).fill(DS.Colors.moss)
                    .frame(width: CGFloat(downloadProgress) * 100, height: 3)
            }
            HStack {
                Text("\(Int(downloadProgress * 100))%")
                    .font(DS.Fonts.mono(11))
                    .foregroundStyle(DS.Colors.ink3)
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(.dsDestructive)
            }
        }
    }

    private var inUseAction: some View {
        HStack(spacing: 5) {
            Circle().fill(DS.Colors.moss).frame(width: 6, height: 6)
            Text("In use")
                .font(DS.Fonts.sans(12, weight: .medium))
                .foregroundStyle(DS.Colors.moss)
        }
    }

    private var useThisAction: some View {
        Button("Use this", action: onLoad)
            .buttonStyle(.dsSecondary)
    }

    private var downloadAction: some View {
        Button {
            onDownload()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.down.circle.fill").font(.system(size: 12))
                Text("Download")
            }
        }
        .buttonStyle(.dsPrimary)
    }
}

// MARK: - AllModelsSheet

struct AllModelsSheet: View {
    @Bindable var state: AppState
    var onDownloadModel: ((WhisperModel) -> Void)?
    var onLoadModel: ((WhisperModel) -> Void)?
    var onCancelDownload: (() -> Void)?
    let onDismiss: () -> Void

    @State private var familyFilter: WhisperModel.Family? = nil

    private var filtered: [WhisperModel] {
        guard let fam = familyFilter else { return WhisperModel.allCases }
        return WhisperModel.allCases.filter { $0.family == fam }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("All models")
                        .font(DS.Fonts.sans(15, weight: .semibold))
                        .foregroundStyle(DS.Colors.ink)
                    Text("Official ggerganov/whisper.cpp repository · \(WhisperModel.allCases.count) models")
                        .font(DS.Fonts.sans(11.5))
                        .foregroundStyle(DS.Colors.ink3)
                }
                Spacer()
                Button(action: onDismiss) {
                    Text("×")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(DS.Colors.ink3)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)

            DSDivider()

            // Family filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FamilyChip(label: "All", isActive: familyFilter == nil) { familyFilter = nil }
                    ForEach(WhisperModel.Family.allCases, id: \.self) { fam in
                        FamilyChip(label: fam.rawValue, isActive: familyFilter == fam) { familyFilter = fam }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
            }

            DSDivider()

            // Table header
            HStack {
                Text("MODEL").frame(maxWidth: .infinity, alignment: .leading)
                Text("SIZE").frame(width: 100, alignment: .trailing)
                Text("STATUS").frame(width: 100, alignment: .trailing)
            }
            .font(DS.Fonts.mono(10.5, weight: .medium))
            .foregroundStyle(DS.Colors.ink4)
            .tracking(0.6)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(DS.Colors.panel)

            // Model rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element) { idx, model in
                        AllModelRow(
                            model: model,
                            isLoaded: state.model == model && state.isModelLoaded,
                            isDownloading: state.downloadingModel == model,
                            downloadProgress: state.downloadProgress,
                            modelListVersion: state.modelListVersion,
                            onDownload: { onDownloadModel?(model) },
                            onLoad: { onLoadModel?(model) },
                            onCancel: { onCancelDownload?() }
                        )
                        if idx < filtered.count - 1 {
                            Rectangle().fill(DS.Colors.lineSoft).frame(height: 1)
                                .padding(.leading, 24)
                        }
                    }
                }
            }

            DSDivider()

            // Footer
            HStack {
                Text("\(filtered.count) of \(WhisperModel.allCases.count) models")
                    .font(DS.Fonts.mono(10.5))
                    .foregroundStyle(DS.Colors.ink4)
                Spacer()
                Text("SHA-256 verified on download")
                    .font(DS.Fonts.mono(10.5))
                    .foregroundStyle(DS.Colors.ink4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(DS.Colors.panel)
        }
        .frame(minWidth: 600, maxWidth: 820, minHeight: 400, maxHeight: 560)
        .background(DS.Colors.card)
        .preferredColorScheme(.light)
    }
}

private struct FamilyChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DS.Fonts.sans(12, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? DS.Colors.paper : DS.Colors.ink2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(isActive ? DS.Colors.ink : Color.clear))
                .overlay(Capsule().strokeBorder(isActive ? Color.clear : DS.Colors.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct AllModelRow: View {
    let model: WhisperModel
    let isLoaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let modelListVersion: Int
    let onDownload: () -> Void
    let onLoad: () -> Void
    let onCancel: () -> Void

    @State private var isHovered = false

    private var isInstalled: Bool {
        let _ = modelListVersion
        return model.isDownloaded
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.rawValue)
                    .font(DS.Fonts.mono(11.5))
                    .foregroundStyle(DS.Colors.ink)
                if let note = model.quantizationNote {
                    Text(note)
                        .font(DS.Fonts.mono(10.5))
                        .foregroundStyle(DS.Colors.ink4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(model.ramUsage)
                .font(DS.Fonts.mono(12))
                .foregroundStyle(DS.Colors.ink2)
                .frame(width: 100, alignment: .trailing)

            Group {
                if isDownloading {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Button("Cancel", action: onCancel).buttonStyle(.dsDestructive)
                    }
                } else if isInstalled && isLoaded {
                    Text("In use")
                        .font(DS.Fonts.sans(11))
                        .foregroundStyle(DS.Colors.ink4)
                } else if isInstalled {
                    Button("Load", action: onLoad).buttonStyle(.dsSecondary)
                } else {
                    Button("Download", action: onDownload).buttonStyle(.dsPrimary)
                }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(isHovered ? DS.Colors.panel : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - CustomModelSheet

struct CustomModelSheet: View {
    let onDismiss: () -> Void

    @State private var urlText = ""
    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use a custom GGML")
                        .font(DS.Fonts.sans(15, weight: .semibold))
                        .foregroundStyle(DS.Colors.ink)
                    Text("Load any fine-tuned .bin compatible with whisper.cpp")
                        .font(DS.Fonts.sans(12))
                        .foregroundStyle(DS.Colors.ink3)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            DSDivider()

            VStack(alignment: .leading, spacing: 20) {
                // URL section
                VStack(alignment: .leading, spacing: 8) {
                    Text("FROM URL")
                        .font(DS.Fonts.mono(10.5, weight: .medium))
                        .foregroundStyle(DS.Colors.ink4)
                        .tracking(0.6)
                    TextField("https://…", text: $urlText)
                        .font(DS.Fonts.mono(12))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(DS.Colors.panel)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .strokeBorder(DS.Colors.line, lineWidth: 1)
                        )
                }

                // Or separator
                HStack {
                    Spacer()
                    Text("or")
                        .font(DS.Fonts.sans(11))
                        .foregroundStyle(DS.Colors.ink4)
                    Spacer()
                }

                // Drop zone
                Button {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = []
                    panel.allowsOtherFileTypes = true
                    panel.message = "Select a .bin model file"
                    panel.prompt = "Load"
                    panel.begin { _ in }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 22))
                            .foregroundStyle(isDragging ? DS.Colors.moss : DS.Colors.ink3)
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Text("Drag a")
                                    .font(DS.Fonts.sans(13))
                                    .foregroundStyle(DS.Colors.ink3)
                                Text(".bin")
                                    .font(DS.Fonts.mono(13))
                                    .foregroundStyle(DS.Colors.ink2)
                                Text("here")
                                    .font(DS.Fonts.sans(13))
                                    .foregroundStyle(DS.Colors.ink3)
                            }
                            Text("or click to select")
                                .font(DS.Fonts.sans(12))
                                .foregroundStyle(DS.Colors.ink4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(isDragging ? DS.Colors.mossSoft : DS.Colors.panel)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(
                                isDragging ? DS.Colors.moss : DS.Colors.line,
                                style: StrokeStyle(lineWidth: 1.5, dash: [6])
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Spacer()

            DSDivider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel", action: onDismiss).buttonStyle(.dsSecondary)
                Button {
                    // Load from URL if set
                    onDismiss()
                } label: {
                    Text("Load model")
                }
                .buttonStyle(.dsPrimary)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(DS.Colors.panel)
        }
        .frame(width: 520, height: 440)
        .background(DS.Colors.card)
        .preferredColorScheme(.light)
    }
}
