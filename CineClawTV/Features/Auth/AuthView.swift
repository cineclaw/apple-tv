import SwiftUI
import CoreImage.CIFilterBuiltins

struct AuthView: View {
    @State private var apiConfig = APIConfig.shared
    @State private var session = SessionManager.shared

    @State private var serverUrlInput: String = APIConfig.shared.baseURL
    @State private var usernameInput: String = "admin"
    @State private var passwordInput: String = "wavemp3"
    @State private var isLoggingIn: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isServerOnline: Bool? = nil
    @State private var isCheckingServer: Bool = false

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
        ZStack {
            Color.obsidianBackground.ignoresSafeArea()

            // Subtle emerald background ambient glow
            RadialGradient(
                colors: [Color.emeraldPrimary.opacity(0.12), Color.clear],
                center: .topLeading,
                startRadius: 80,
                endRadius: 900
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 36) {
                    // Header Branding
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.emeraldPrimary)
                                .frame(width: 54, height: 54)
                                .overlay(
                                    Image(systemName: "film.stack.fill")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.black)
                                )

                            Text("CineClaw TV")
                                .font(.system(size: 46, weight: .black))
                                .foregroundColor(.textPrimary)
                        }

                        Text("Подключение к домашнему кинотеатру")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 40)

                    // 2-Column Content Layout
                    HStack(alignment: .top, spacing: 60) {
                        // Left Column: Server URL & Direct Credentials
                        VStack(alignment: .leading, spacing: 24) {
                            Text("Вход по логину и паролю")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.textPrimary)

                            // Server Address Block
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Адрес сервера CineClaw")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.textSecondary)

                                    Spacer()

                                    // Server online indicator
                                    if isCheckingServer {
                                        HStack(spacing: 6) {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                            Text("Проверка...")
                                                .font(.system(size: 15))
                                                .foregroundColor(.textMuted)
                                        }
                                    } else if let online = isServerOnline {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(online ? Color.emeraldPrimary : Color.red)
                                                .frame(width: 8, height: 8)
                                            Text(online ? "В сети" : "Недоступен")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(online ? .emeraldPrimary : .red)
                                        }
                                    }
                                }

                                TextField("http://192.168.88.19:3000", text: $serverUrlInput)
                                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                                    .padding(14)
                                    .background(Color.obsidianCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onChange(of: serverUrlInput) { _, newVal in
                                        apiConfig.setCleanBaseURL(newVal)
                                        Task { await checkServerStatus() }
                                    }

                                // Quick presets
                                HStack(spacing: 12) {
                                    Text("Быстрый выбор:")
                                        .font(.system(size: 15))
                                        .foregroundColor(.textMuted)

                                    Button("NAS (192.168.88.19)") {
                                        serverUrlInput = "http://192.168.88.19:3000"
                                        apiConfig.setCleanBaseURL(serverUrlInput)
                                        Task { await checkServerStatus() }
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 15, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.obsidianCard))

                                    Button("Local (127.0.0.1)") {
                                        serverUrlInput = "http://127.0.0.1:3000"
                                        apiConfig.setCleanBaseURL(serverUrlInput)
                                        Task { await checkServerStatus() }
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 15, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.obsidianCard))
                                }
                            }

                            // Username
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Логин")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.textSecondary)

                                TextField("admin", text: $usernameInput)
                                    .font(.system(size: 20))
                                    .padding(14)
                                    .background(Color.obsidianCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Пароль")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.textSecondary)

                                SecureField("••••••••", text: $passwordInput)
                                    .font(.system(size: 20))
                                    .padding(14)
                                    .background(Color.obsidianCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Error message banner
                            if let error = errorMessage {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.ratingGold)
                                    Text(error)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.textPrimary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.red.opacity(0.15))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
                                )
                            }

                            // Login Action Button
                            Button {
                                Task { await performLogin() }
                            } label: {
                                HStack(spacing: 12) {
                                    if isLoggingIn {
                                        ProgressView()
                                            .scaleEffect(0.9)
                                        Text("Авторизация...")
                                    } else {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.system(size: 22))
                                        Text("Войти в CineClaw")
                                    }
                                }
                                .font(.system(size: 22, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(EmeraldButtonStyle(isPrimary: true))
                            .disabled(isLoggingIn)
                        }
                        .frame(maxWidth: 620)

                        // Divider
                        Rectangle()
                            .fill(Color.obsidianBorder)
                            .frame(width: 1, height: 480)

                        // Right Column: Quick Pairing via QR Code
                        VStack(spacing: 20) {
                            Text("Быстрое сопряжение")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.textPrimary)

                            Text("Отсканируйте камерой смартфона в веб-приложении CineClaw")
                                .font(.system(size: 16))
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)

                            let pairURL = "\(apiConfig.baseURL)/pair?code=\(pairingCode)"
                            if let qr = generateQRCode(from: pairURL) {
                                Image(uiImage: qr)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 220, height: 220)
                                    .padding(16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .shadow(color: .black.opacity(0.4), radius: 12)
                            }

                            VStack(spacing: 6) {
                                Text("Код подтверждения:")
                                    .font(.system(size: 15))
                                    .foregroundColor(.textMuted)

                                Text(pairingCode)
                                    .font(.system(size: 32, weight: .black, design: .monospaced))
                                    .foregroundColor(.emeraldPrimary)
                                    .tracking(4)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.obsidianCard))

                            Text(pairingStatus)
                                .font(.system(size: 15))
                                .foregroundColor(.textMuted)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.obsidianCard.opacity(0.8))
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.obsidianBorder, lineWidth: 1))
                        )
                        .frame(maxWidth: 440)
                    }
                    .padding(.horizontal, 60)

                    Spacer(minLength: 60)
                }
            }
        }
        .task {
            await checkServerStatus()
            await pollPairingStatus()
        }
    }

    private func checkServerStatus() async {
        isCheckingServer = true
        isServerOnline = await CineClawClient.shared.pingServer(baseURL: serverUrlInput)
        isCheckingServer = false
    }

    private func performLogin() async {
        isLoggingIn = true
        errorMessage = nil

        // Clean and store server URL
        apiConfig.setCleanBaseURL(serverUrlInput)

        do {
            let res = try await CineClawClient.shared.login(
                username: usernameInput.trimmingCharacters(in: .whitespacesAndNewlines),
                password: passwordInput,
                customBaseURL: apiConfig.baseURL
            )

            session.setSession(token: res.token, username: res.username)
            isLoggingIn = false
        } catch {
            isLoggingIn = false
            errorMessage = error.localizedDescription
        }
    }

    private func pollPairingStatus() async {
        while !Task.isCancelled && !session.isPaired {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
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
