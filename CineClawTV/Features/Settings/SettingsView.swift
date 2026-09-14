import SwiftUI

struct SettingsView: View {
    @State private var apiConfig = APIConfig.shared
    @State private var session = SessionManager.shared

    @State private var isServerOnline: Bool? = nil
    @State private var isCheckingPing: Bool = false
    @State private var showChangeServerAlert: Bool = false
    @State private var showSignOutAlert: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.obsidianBackground.ignoresSafeArea()

                // Subtle emerald ambient background glow
                RadialGradient(
                    colors: [Color.emeraldPrimary.opacity(0.08), Color.clear],
                    center: .topTrailing,
                    startRadius: 60,
                    endRadius: 800
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 36) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Настройки")
                                .font(.system(size: 42, weight: .black))
                                .foregroundColor(.textPrimary)

                            Text("Управление подключением к серверу CineClaw и параметрами воспроизведения")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, 60)
                        .padding(.top, 24)

                        HStack(alignment: .top, spacing: 50) {
                            // Left Column: Server connection & Playback settings
                            VStack(alignment: .leading, spacing: 28) {
                                // Section: Server & Account
                                VStack(alignment: .leading, spacing: 18) {
                                    Text("Сервер и авторизация")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.textSecondary)

                                    VStack(alignment: .leading, spacing: 20) {
                                        // Server URL & Ping Row
                                        HStack(spacing: 16) {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.emeraldPrimary.opacity(0.15))
                                                .frame(width: 48, height: 48)
                                                .overlay(
                                                    Image(systemName: "server.rack")
                                                        .font(.system(size: 22, weight: .bold))
                                                        .foregroundColor(.emeraldPrimary)
                                                )

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Текущий адрес сервера")
                                                    .font(.system(size: 15))
                                                    .foregroundColor(.textMuted)

                                                Text(apiConfig.baseURL)
                                                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                                                    .foregroundColor(.textPrimary)
                                            }

                                            Spacer()

                                            // Online / Offline Status
                                            if isCheckingPing {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                            } else if let online = isServerOnline {
                                                HStack(spacing: 8) {
                                                    Circle()
                                                        .fill(online ? Color.emeraldPrimary : Color.red)
                                                        .frame(width: 10, height: 10)
                                                    Text(online ? "На связи" : "Не отвечает")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(online ? .emeraldPrimary : .red)
                                                }
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(online ? Color.emeraldPrimary.opacity(0.15) : Color.red.opacity(0.15))
                                                )
                                            }
                                        }

                                        Divider()
                                            .background(Color.obsidianBorder)

                                        // Account Row
                                        HStack(spacing: 16) {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.obsidianElevated)
                                                .frame(width: 48, height: 48)
                                                .overlay(
                                                    Image(systemName: "person.crop.circle.fill")
                                                        .font(.system(size: 22))
                                                        .foregroundColor(.textSecondary)
                                                )

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Активная учетная запись")
                                                    .font(.system(size: 15))
                                                    .foregroundColor(.textMuted)

                                                Text(session.username ?? "Пользователь")
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(.textPrimary)
                                            }

                                            Spacer()

                                            Text("● Авторизован")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.emeraldPrimary)
                                        }

                                        Divider()
                                            .background(Color.obsidianBorder)

                                        // Explicit Actions: Change Server & Sign Out
                                        HStack(spacing: 20) {
                                            Button {
                                                showChangeServerAlert = true
                                            } label: {
                                                HStack(spacing: 10) {
                                                    Image(systemName: "arrow.triangle.2.circlepath")
                                                        .font(.system(size: 20, weight: .bold))
                                                    Text("Сменить сервер")
                                                        .font(.system(size: 20, weight: .bold))
                                                }
                                                .padding(.horizontal, 24)
                                                .padding(.vertical, 14)
                                            }
                                            .buttonStyle(EmeraldButtonStyle(isPrimary: true))

                                            Button {
                                                showSignOutAlert = true
                                            } label: {
                                                HStack(spacing: 10) {
                                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                                        .font(.system(size: 20, weight: .bold))
                                                    Text("Выйти")
                                                        .font(.system(size: 20, weight: .bold))
                                                }
                                                .padding(.horizontal, 24)
                                                .padding(.vertical, 14)
                                            }
                                            .buttonStyle(EmeraldButtonStyle(isPrimary: false))
                                        }
                                        .padding(.top, 6)
                                    }
                                    .padding(24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18)
                                            .fill(Color.obsidianCard)
                                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.obsidianBorder, lineWidth: 1))
                                    )
                                }

                                // Section: Playback Quality
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("Качество видео по умолчанию")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.textSecondary)

                                    Text("Используется при быстром воспроизведении фильмов и эпизодов")
                                        .font(.system(size: 16))
                                        .foregroundColor(.textMuted)

                                    HStack(spacing: 16) {
                                        ForEach(["4K", "1080p", "720p"], id: \.self) { q in
                                            Button {
                                                apiConfig.defaultQuality = q
                                            } label: {
                                                Text(q)
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(apiConfig.defaultQuality == q ? .black : .white)
                                                    .padding(.horizontal, 28)
                                                    .padding(.vertical, 14)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(apiConfig.defaultQuality == q ? Color.emeraldPrimary : Color.obsidianCard)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.obsidianCard)
                                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.obsidianBorder, lineWidth: 1))
                                )

                                // Section: Transcoding & Hardware Compatibility
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Режим совместимости и транскодирования")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.textSecondary)

                                    Text(DeviceCapabilities.isLegacyAppleTV
                                        ? "Обнаружен Apple TV HD (A8) без аппаратной поддержки H.265. Рекомендуется режим «Всегда H.264» или «Авто»."
                                        : "Управление перекодированием тяжелых форматов (H.265, 4K) на сервере.")
                                        .font(.system(size: 16))
                                        .foregroundColor(.textMuted)

                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Режим воспроизведения:")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.textPrimary)

                                        HStack(spacing: 14) {
                                            ForEach(PlaybackMode.allCases) { mode in
                                                Button {
                                                    apiConfig.playbackMode = mode
                                                } label: {
                                                    Text(mode.title)
                                                        .font(.system(size: 18, weight: .semibold))
                                                        .foregroundColor(apiConfig.playbackMode == mode ? .black : .white)
                                                        .padding(.horizontal, 20)
                                                        .padding(.vertical, 12)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 10)
                                                                .fill(apiConfig.playbackMode == mode ? Color.emeraldPrimary : Color.obsidianCard)
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Качество транскодирования:")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.textPrimary)

                                        HStack(spacing: 14) {
                                            ForEach(["1080p", "720p", "480p"], id: \.self) { q in
                                                Button {
                                                    apiConfig.transcodeQuality = q
                                                } label: {
                                                    Text(q)
                                                        .font(.system(size: 18, weight: .semibold))
                                                        .foregroundColor(apiConfig.transcodeQuality == q ? .black : .white)
                                                        .padding(.horizontal, 22)
                                                        .padding(.vertical, 10)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 10)
                                                                .fill(apiConfig.transcodeQuality == q ? Color.emeraldPrimary : Color.obsidianCard)
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                                .padding(24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.obsidianCard)
                                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.obsidianBorder, lineWidth: 1))
                                )

                                // Section: Audio Passthrough
                                VStack(alignment: .leading, spacing: 14) {
                                    Toggle(isOn: $apiConfig.audioPassthrough) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Прямой вывод звука (Passthrough)")
                                                .font(.system(size: 22, weight: .bold))
                                                .foregroundColor(.textPrimary)
                                            Text("Передача DTS-HD / Dolby Atmos / AC3 напрямую на ресивер через HDMI eARC без преобразования в PCM")
                                                .font(.system(size: 16))
                                                .foregroundColor(.textSecondary)
                                        }
                                    }
                                    .tint(.emeraldPrimary)
                                }
                                .padding(24)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.obsidianCard)
                                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.obsidianBorder, lineWidth: 1))
                                )
                            }
                            .frame(maxWidth: 700)

                            // Right Column: System info & Help
                            VStack(alignment: .leading, spacing: 28) {
                                VStack(alignment: .leading, spacing: 18) {
                                    Text("О системе")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.textSecondary)

                                    VStack(alignment: .leading, spacing: 16) {
                                        InfoRow(label: "Клиент", value: "CineClaw TV for tvOS")
                                        InfoRow(label: "Версия", value: "v1.2.0 (tvOS 18+)")
                                        InfoRow(label: "Медиа-плеер", value: "KSPlayer (Metal + FFmpeg)")
                                        InfoRow(label: "Торрент-движок", value: "TorrServer Turbo (Порт 8092)")
                                        InfoRow(label: "Платформа", value: DeviceCapabilities.isLegacyAppleTV ? "Apple TV HD (A8)" : "Apple TV 4K")
                                        InfoRow(label: "Аппаратный H.265", value: DeviceCapabilities.supportsHardwareHEVC ? "Поддерживается" : "Серверный транскод (H.264)")
                                    }
                                    .padding(24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18)
                                            .fill(Color.obsidianCard)
                                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.obsidianBorder, lineWidth: 1))
                                    )
                                }

                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(.emeraldPrimary)
                                        Text("Как сменить сервер?")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.textPrimary)
                                    }

                                    Text("Нажмите кнопку «Сменить сервер» или «Выйти». Текущая сессия будет сброшена, и откроется экран входа, где можно выбрать пресет (домашний NAS 192.168.88.19 или локальный сервер), ввести новый адрес и авторизоваться с пульта или по QR-коду.")
                                        .font(.system(size: 16))
                                        .foregroundColor(.textSecondary)
                                        .lineSpacing(4)
                                }
                                .padding(24)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.obsidianCard.opacity(0.6))
                                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.obsidianBorder, lineWidth: 1))
                                )
                            }
                            .frame(maxWidth: 460)
                        }
                        .padding(.horizontal, 60)

                        Spacer(minLength: 80)
                    }
                }
            }
            .task {
                await checkPing()
            }
            .alert("Сменить сервер CineClaw?", isPresented: $showChangeServerAlert) {
                Button("Сменить сервер", role: .destructive) {
                    session.clearSession()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Текущая сессия будет завершена. Откроется стартовый экран с выбором сервера (NAS, Local или свой IP) и авторизацией.")
            }
            .alert("Выйти из аккаунта?", isPresented: $showSignOutAlert) {
                Button("Выйти", role: .destructive) {
                    session.clearSession()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Вы действительно хотите выйти из профиля «\(session.username ?? "admin")»?")
            }
        }
    }

    private func checkPing() async {
        isCheckingPing = true
        isServerOnline = await CineClawClient.shared.pingServer()
        isCheckingPing = false
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textPrimary)
        }
    }
}
