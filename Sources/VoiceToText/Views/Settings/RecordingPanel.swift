import SwiftUI

struct TranscriptionPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Audio")
                .font(DS.Fonts.display(22))
                .foregroundStyle(DS.Colors.ink)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 20)

            audioCard
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
        }
    }

    // MARK: - Audio card

    private var audioCard: some View {
        VStack(spacing: 0) {
            sliderRow(
                title: "Intervalo de chunk",
                desc: "Cada cuánto se envía audio a transcribir. Más corto = más rápido pero más CPU.",
                value: $state.liveChunkInterval,
                range: 1...5, step: 0.5,
                display: String(format: "%.1f s", state.liveChunkInterval)
            )

            Divider().padding(.leading, 16)

            sliderRow(
                title: "Solapamiento de audio",
                desc: "Audio heredado del chunk anterior para evitar cortar palabras en el límite.",
                value: Binding(
                    get: { Double(state.liveOverlapMs) },
                    set: { state.liveOverlapMs = Int($0); onSave() }
                ),
                range: 0...1000, step: 100,
                display: "\(state.liveOverlapMs) ms"
            )

            Divider().padding(.leading, 16)

            // Silence threshold with live meter
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Umbral de silencio")
                            .font(DS.Fonts.sans(13, weight: .medium))
                            .foregroundStyle(DS.Colors.ink)
                        Text("La barra muestra el nivel del micrófono en tiempo real.")
                            .font(DS.Fonts.sans(12))
                            .foregroundStyle(DS.Colors.ink3)
                    }
                    Spacer()
                    Text(String(format: "%.4f", state.liveSilenceThreshold))
                        .font(DS.Fonts.mono(12))
                        .foregroundStyle(DS.Colors.ink3)
                }

                AudioLevelMeter(level: state.audioLevel, threshold: state.liveSilenceThreshold)
                    .frame(height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

                Slider(value: $state.liveSilenceThreshold, in: 0.0005...0.01, step: 0.0005)
                    .tint(DS.Colors.moss)
                    .onChange(of: state.liveSilenceThreshold) { onSave() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.leading, 16)

            sliderRow(
                title: "Tiempo de silencio",
                desc: "Segundos de silencio continuo antes de detener automáticamente.",
                value: $state.liveSilenceTimeout,
                range: 4...60, step: 2,
                display: String(format: "%.0f s", state.liveSilenceTimeout)
            )
        }
        .background(DS.Colors.card)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Helpers

    private func sliderRow(
        title: String, desc: String,
        value: Binding<Double>,
        range: ClosedRange<Double>, step: Double,
        display: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Fonts.sans(13, weight: .medium))
                        .foregroundStyle(DS.Colors.ink)
                    Text(desc)
                        .font(DS.Fonts.sans(12))
                        .foregroundStyle(DS.Colors.ink3)
                }
                Spacer()
                Text(display)
                    .font(DS.Fonts.mono(12))
                    .foregroundStyle(DS.Colors.ink3)
            }
            Slider(value: value, in: range, step: step)
                .tint(DS.Colors.moss)
                .onChange(of: value.wrappedValue) { onSave() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
