import SwiftUI
import CoreImage.CIFilterBuiltins

struct SettingsView: View {
    @State private var apiConfig = APIConfig.shared
    @State private var session = SessionManager.shared
    @State private var pairingCode: String = String(format: "%06d", Int.random(in: 100_000...999_999))
    @State private var pairingStatus: String = "Ожидание сопряжения..."

    private let filter = CIFilter.qrCodeGenerator()

    private func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        if let cg = context.createCGImage(scaled, from: scaled.extent) {
            return UIImage(cgImage: cg)
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.obsidianBackground.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 40) {
                        Text("Настройки")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 50)
                            .padding(.top, 20)

                        HStack(alignment: .top, spacing: 60) {
                            // Left Column: Server and Playback Preferences
                            VStack(alignment: .leading, spacing: 28) {
                                // Server URL
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Адрес сервера CineClaw")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.textSecondary)

                                    TextField("http://192.168.88.126:3000", text: $apiConfig.baseURL)
                                        .font(.system(size: 22))
                                        .padding(16)
                                        .background(Color.obsidianCard)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                // Quality Preference
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Качество по умолчанию")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.textSecondary)

                                    HStack(spacing: 16) {
                                        ForEach(["4K", "1080p", "720p"], id: \.self) { q in
                                            Button {
                                                apiConfig.defaultQuality = q
                                            } label: {
                                                Text(q)
                                                    .font(.system(size: 20, weight: .semibold))
                                                    .foregroundColor(apiConfig.defaultQuality == q ? .black : .white)
                                                    .padding(.horizontal, 24)
                                                    .padding(.vertical, 12)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .fill(apiConfig.defaultQuality == q ? Color.emeraldPrimary : Color.obsidianCard)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                // Audio Passthrough Toggle
                                Toggle(isOn: $apiConfig.audioPassthrough) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Прямой вывод звука (Passthrough)")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundColor(.textPrimary)
                                        Text("Передача DTS / Dolby Digital на AV-ресивер без преобразования")
                                            .font(.system(size: 16))
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                                .tint(.emeraldPrimary)

                                // Session info
                                if session.isPaired {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Статус подключения")
                                                .font(.system(size: 16))
                                                .foregroundColor(.textSecondary)
                                            Text("✓ Подключено: \(session.username ?? "Пользователь")")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.emeraldPrimary)
                                        }
                                        Spacer()
                                        Button("Выйти") {
                                            session.clearSession()
                                        }
                                        .buttonStyle(EmeraldButtonStyle(isPrimary: false))
                                    }
                                    .padding(20)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.obsidianCard))
                                }
                            }
                            .frame(maxWidth: 650)

                            // Right Column: QR Code Pairing
                            VStack(spacing: 16) {
                                Text("Быстрое сопряжение")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.textPrimary)

                                Text("Отсканируйте камерой смартфона в приложении CineClaw Web")
                                    .font(.system(size: 16))
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)

                                let pairURL = "\(apiConfig.baseURL)/pair?code=\(pairingCode)"
                                if let qr = generateQRCode(from: pairURL) {
                                    Image(uiImage: qr)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 220, height: 220)
                                        .padding(16)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }

                                Text("Код сопряжения: \(pairingCode)")
                                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                                    .foregroundColor(.emeraldPrimary)

                                Text(pairingStatus)
                                    .font(.system(size: 16))
                                    .foregroundColor(.textMuted)
                            }
                            .padding(28)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.obsidianCard)
                            )
                        }
                        .padding(.horizontal, 50)

                        Spacer(minLength: 80)
                    }
                }
            }
            .task {
                await pollPairingStatus()
            }
        }
    }

    private func pollPairingStatus() async {
        while !Task.isCancelled && !session.isPaired {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { break }

            if let resp = try? await CineClawClient.shared.checkPairingStatus(code: pairingCode), resp.paired {
                if let token = resp.token {
                    session.setSession(token: token, username: resp.username)
                    pairingStatus = "✓ Успешно сопряжено!"
                    break
                }
            }
        }
    }
}
