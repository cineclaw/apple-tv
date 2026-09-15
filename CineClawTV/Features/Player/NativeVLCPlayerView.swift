import UIKit
import SwiftUI

// MARK: - Interactive Apple TV Scrubber Control
final class TvScrubberControl: UIControl {
    weak var viewModel: PlayerViewModel?
    var onUserInteraction: (() -> Void)?
    var onNavigateToButtons: (() -> Void)?

    private let trackRail = UIView()
    private let trackFill = UIView()
    private let thumbView = UIView()
    private let currentTimeLabel = UILabel()
    private let remainingTimeLabel = UILabel()
    private let scrubDeltaLabel = UILabel()

    private var fillWidthConstraint: NSLayoutConstraint?
    private var thumbCenterConstraint: NSLayoutConstraint?
    private var panRecognizer: UIPanGestureRecognizer?

    private(set) var isScrubbing: Bool = false
    private var scrubTargetSeconds: Double = 0.0
    private var basePlaybackTime: Double = 0.0
    private var activationTimestamp: TimeInterval = 0
    private var settlingTargetSeconds: Double?
    private var settlingDeadline: TimeInterval = 0

    var duration: Double = 0.0
    var currentTime: Double = 0.0

    override var canBecomeFocused: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        clipsToBounds = false

        // 1. Rail (Background track)
        trackRail.translatesAutoresizingMaskIntoConstraints = false
        trackRail.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        trackRail.layer.cornerRadius = 3
        trackRail.clipsToBounds = true
        addSubview(trackRail)

        // 2. Fill (Progress track)
        trackFill.translatesAutoresizingMaskIntoConstraints = false
        trackFill.backgroundColor = .white
        trackFill.layer.cornerRadius = 3
        trackFill.clipsToBounds = true
        addSubview(trackFill)

        // 3. Thumb dot
        thumbView.translatesAutoresizingMaskIntoConstraints = false
        thumbView.backgroundColor = .white
        thumbView.layer.cornerRadius = 7
        thumbView.layer.shadowColor = UIColor.white.cgColor
        thumbView.layer.shadowRadius = 4
        thumbView.layer.shadowOpacity = 0.5
        thumbView.layer.shadowOffset = .zero
        addSubview(thumbView)

        // 4. Current Time Label (Left)
        let timeFont = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        currentTimeLabel.font = timeFont
        currentTimeLabel.textColor = .white
        currentTimeLabel.text = "00:00"
        addSubview(currentTimeLabel)

        // 5. Delta Label (Next to current time)
        scrubDeltaLabel.translatesAutoresizingMaskIntoConstraints = false
        scrubDeltaLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        scrubDeltaLabel.textColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)
        scrubDeltaLabel.text = ""
        addSubview(scrubDeltaLabel)

        // 6. Remaining Time Label (Right)
        remainingTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        remainingTimeLabel.font = timeFont
        remainingTimeLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        remainingTimeLabel.text = "-00:00"
        remainingTimeLabel.textAlignment = .right
        addSubview(remainingTimeLabel)

        let fillWidth = trackFill.widthAnchor.constraint(equalToConstant: 4)
        self.fillWidthConstraint = fillWidth
        let thumbCenter = thumbView.centerXAnchor.constraint(equalTo: trackFill.trailingAnchor)
        self.thumbCenterConstraint = thumbCenter

        NSLayoutConstraint.activate([
            // Rail
            trackRail.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            trackRail.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackRail.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackRail.heightAnchor.constraint(equalToConstant: 6),

            // Fill
            trackFill.topAnchor.constraint(equalTo: trackRail.topAnchor),
            trackFill.bottomAnchor.constraint(equalTo: trackRail.bottomAnchor),
            trackFill.leadingAnchor.constraint(equalTo: trackRail.leadingAnchor),
            fillWidth,

            // Thumb
            thumbView.centerYAnchor.constraint(equalTo: trackRail.centerYAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: 14),
            thumbView.heightAnchor.constraint(equalToConstant: 14),
            thumbCenter,

            // Current Time
            currentTimeLabel.topAnchor.constraint(equalTo: trackRail.bottomAnchor, constant: 10),
            currentTimeLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            // Delta
            scrubDeltaLabel.centerYAnchor.constraint(equalTo: currentTimeLabel.centerYAnchor),
            scrubDeltaLabel.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 8),

            // Remaining Time
            remainingTimeLabel.topAnchor.constraint(equalTo: trackRail.bottomAnchor, constant: 10),
            remainingTimeLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        let focused = (context.nextFocusedView === self)
        coordinator.addCoordinatedAnimations {
            if focused {
                self.trackRail.backgroundColor = UIColor.white.withAlphaComponent(0.4)
                self.thumbView.transform = CGAffineTransform(scaleX: 1.7, y: 1.7)
                self.thumbView.layer.shadowOpacity = 0.95
                self.thumbView.layer.shadowRadius = 8
            } else {
                self.trackRail.backgroundColor = UIColor.white.withAlphaComponent(0.25)
                self.thumbView.transform = .identity
                self.thumbView.layer.shadowOpacity = 0.5
                self.thumbView.layer.shadowRadius = 4
            }
        }
        if !focused && isScrubbing {
            cancelScrubbing()
        }
    }

    override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
        if isScrubbing {
            return false
        }
        return super.shouldUpdateFocus(in: context)
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        pan.cancelsTouchesInView = true
        pan.isEnabled = false // Only enabled in active scrub mode
        addGestureRecognizer(pan)
        self.panRecognizer = pan
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let vm = viewModel, isScrubbing else { return }
        onUserInteraction?()

        switch recognizer.state {
        case .began:
            recognizer.setTranslation(.zero, in: self)

        case .changed:
            let translation = recognizer.translation(in: self)
            recognizer.setTranslation(.zero, in: self)
            let dx = Double(translation.x)
            guard abs(dx) > 0.001 else { return }

            let velocityX = Double(abs(recognizer.velocity(in: self).x))
            let dur = vm.duration > 0 ? vm.duration : 7200.0

            let scale: Double
            if velocityX < 300 {
                scale = 0.10
            } else if velocityX < 1000 {
                scale = 0.35
            } else if velocityX < 2500 {
                scale = 1.00
            } else {
                scale = 2.20
            }

            let delta = dx * scale
            scrubTargetSeconds = max(0.0, min(dur, scrubTargetSeconds + delta))
            vm.updateScrubTime(scrubTargetSeconds)
            updateUI(currentTime: scrubTargetSeconds, duration: dur)

        default:
            break
        }
    }

    func activateScrubbing() {
        guard !isScrubbing, let vm = viewModel else { return }
        isScrubbing = true
        panRecognizer?.isEnabled = true
        activationTimestamp = ProcessInfo.processInfo.systemUptime
        let cur = vm.engine.currentTime
        basePlaybackTime = cur
        scrubTargetSeconds = cur
        vm.startScrubbing(initialTime: cur)
        updateUI(currentTime: cur, duration: vm.duration)
        onUserInteraction?()
    }

    func commitScrubbing() {
        guard isScrubbing, let vm = viewModel else { return }
        isScrubbing = false
        panRecognizer?.isEnabled = false
        scrubDeltaLabel.text = ""
        settlingTargetSeconds = scrubTargetSeconds
        settlingDeadline = ProcessInfo.processInfo.systemUptime + 3.0
        vm.commitScrub(to: scrubTargetSeconds)
        updateUI(currentTime: scrubTargetSeconds, duration: vm.duration)
        onUserInteraction?()
    }

    func cancelScrubbing() {
        guard isScrubbing, let vm = viewModel else { return }
        isScrubbing = false
        panRecognizer?.isEnabled = false
        scrubDeltaLabel.text = ""
        settlingTargetSeconds = nil
        vm.cancelScrub()
        updateUI(currentTime: vm.engine.currentTime, duration: vm.duration)
        onUserInteraction?()
    }

    func adjustScrub(by delta: Double) {
        guard let vm = viewModel, isScrubbing else { return }
        onUserInteraction?()
        let dur = vm.duration > 0 ? vm.duration : 7200.0
        scrubTargetSeconds = max(0.0, min(dur, scrubTargetSeconds + delta))
        vm.updateScrubTime(scrubTargetSeconds)
        updateUI(currentTime: scrubTargetSeconds, duration: dur)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else {
            super.pressesBegan(presses, with: event)
            return
        }

        if isScrubbing {
            if press.type == .menu || press.type == .select || press.type == .playPause || press.type == .leftArrow || press.type == .rightArrow {
                return
            }
        }

        if press.type == .select || press.type == .downArrow || press.type == .rightArrow {
            return
        }

        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else {
            super.pressesEnded(presses, with: event)
            return
        }

        if isScrubbing {
            switch press.type {
            case .menu:
                cancelScrubbing()
                return
            case .select:
                if ProcessInfo.processInfo.systemUptime - activationTimestamp > 0.15 {
                    commitScrubbing()
                }
                return
            case .playPause:
                commitScrubbing()
                return
            case .leftArrow:
                adjustScrub(by: -10)
                return
            case .rightArrow:
                adjustScrub(by: 10)
                return
            default:
                return
            }
        }

        switch press.type {
        case .select:
            activateScrubbing()
            return
        case .downArrow, .rightArrow:
            onNavigateToButtons?()
            return
        default:
            super.pressesEnded(presses, with: event)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let t = isScrubbing ? scrubTargetSeconds : currentTime
        updateUI(currentTime: t, duration: duration)
    }

    func updateUI(currentTime: Double, duration: Double) {
        self.duration = duration
        if !isScrubbing {
            if let settling = settlingTargetSeconds {
                if ProcessInfo.processInfo.systemUptime < settlingDeadline && abs(currentTime - settling) > 2.0 {
                    self.currentTime = settling
                } else {
                    settlingTargetSeconds = nil
                    self.currentTime = currentTime
                }
            } else {
                self.currentTime = currentTime
            }
        }

        let displayTime = isScrubbing ? scrubTargetSeconds : self.currentTime
        let dur = duration > 0 ? duration : 1.0
        let clamped = max(0.0, min(1.0, displayTime / dur))
        let width = trackRail.bounds.width
        if width > 0 {
            let fillWidth = max(4.0, width * CGFloat(clamped))
            fillWidthConstraint?.constant = fillWidth
        }

        currentTimeLabel.text = formatSeconds(displayTime)
        let remaining = max(0, duration - displayTime)
        remainingTimeLabel.text = "-\(formatSeconds(remaining))"

        if isScrubbing {
            let delta = Int(displayTime - basePlaybackTime)
            if abs(delta) > 0 {
                let sign = delta >= 0 ? "+" : ""
                scrubDeltaLabel.text = "(\(sign)\(delta)с)"
            } else {
                scrubDeltaLabel.text = ""
            }
        } else {
            scrubDeltaLabel.text = ""
        }
    }

    func formatSeconds(_ sec: Double) -> String {
        guard !sec.isNaN && sec >= 0 else { return "00:00" }
        let total = Int(sec)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Cellular Signal Strength Badge for Apple TV
final class TvSignalStrengthView: UIView {
    private let barsStack = UIStackView()
    private var barViews: [UIView] = []
    private let speedLabel = UILabel()
    private let seedsLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = UIColor.black.withAlphaComponent(0.65)
        layer.cornerRadius = 14
        layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        layer.borderWidth = 1
        clipsToBounds = true

        let containerStack = UIStackView()
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        containerStack.axis = .horizontal
        containerStack.spacing = 8
        containerStack.alignment = .center
        addSubview(containerStack)

        // Stepped bars stack (4 bars)
        barsStack.translatesAutoresizingMaskIntoConstraints = false
        barsStack.axis = .horizontal
        barsStack.spacing = 2
        barsStack.alignment = .bottom

        let heights: [CGFloat] = [4, 7, 10, 13]
        for h in heights {
            let bar = UIView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.layer.cornerRadius = 1.5
            bar.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            NSLayoutConstraint.activate([
                bar.widthAnchor.constraint(equalToConstant: 3),
                bar.heightAnchor.constraint(equalToConstant: h)
            ])
            barsStack.addArrangedSubview(bar)
            barViews.append(bar)
        }
        containerStack.addArrangedSubview(barsStack)

        // Speed label
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        speedLabel.textColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)
        speedLabel.text = "0 КБ/с"
        containerStack.addArrangedSubview(speedLabel)

        // Seeds count label
        seedsLabel.translatesAutoresizingMaskIntoConstraints = false
        seedsLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        seedsLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        seedsLabel.text = ""
        seedsLabel.isHidden = true
        containerStack.addArrangedSubview(seedsLabel)

        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
    }

    func update(stats: StreamStatsResponse?) {
        guard let stats = stats else {
            for bar in barViews {
                bar.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            }
            speedLabel.text = "0 КБ/с"
            speedLabel.textColor = UIColor.white.withAlphaComponent(0.5)
            seedsLabel.isHidden = true
            return
        }

        let level = stats.signalLevel
        let activeColor: UIColor
        if level >= 3 {
            activeColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0) // Emerald green
        } else if level == 2 {
            activeColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0) // Amber
        } else if level == 1 {
            activeColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0) // Red
        } else {
            activeColor = UIColor.white.withAlphaComponent(0.25)
        }

        for (idx, bar) in barViews.enumerated() {
            if idx < level {
                bar.backgroundColor = activeColor
            } else {
                bar.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            }
        }

        speedLabel.text = stats.downloadSpeedFmt.isEmpty ? "0 КБ/с" : stats.downloadSpeedFmt
        speedLabel.textColor = level > 0 ? activeColor : UIColor.white.withAlphaComponent(0.6)

        if stats.connectedSeeders > 0 {
            seedsLabel.text = "🌱 \(stats.connectedSeeders)"
            seedsLabel.isHidden = false
        } else {
            seedsLabel.isHidden = true
        }
    }
}

final class NativeVLCPlayerViewController: UIViewController, UIGestureRecognizerDelegate {
    let viewModel: PlayerViewModel
    var onDismiss: (() -> Void)?

    private var videoSurfaceView: UIView?

    // UI Scrim & Controls
    private let scrimView = UIView()
    private let controlsContainer = UIView()
    private let titleLabel = UILabel()
    private let scrubberControl = TvScrubberControl()

    // Top Right Header Bar (Signal Speed & Quality Badges)
    private let topBarContainer = UIStackView()
    private let signalStrengthView = TvSignalStrengthView()
    private let qualityBadge = UILabel()
    private let modeBadge = UILabel()

    private let buttonsStack = UIStackView()
    private let subtitlesButton = UIButton(type: .system)
    private let audioButton = UIButton(type: .system)
    private let qualityButton = UIButton(type: .system)

    // HUD Toast for ±10s skips
    private let hudToastContainer = UIView()
    private let hudToastIcon = UIImageView()
    private let hudToastLabel = UILabel()
    private var hudTimer: Timer?

    private var controlsHideTimer: Timer?
    private var periodicTimer: Timer?

    private(set) var areControlsVisible: Bool = false
    private var programmaticallyTargetedView: UIView?

    private var leftGesture: UITapGestureRecognizer?
    private var rightGesture: UITapGestureRecognizer?
    private var selectGesture: UITapGestureRecognizer?
    private var playPauseGesture: UITapGestureRecognizer?
    private var menuGesture: UITapGestureRecognizer?

    init(viewModel: PlayerViewModel, onDismiss: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupVideoSurface()
        setupScrim()
        setupTopBar()
        setupControls()
        setupHUDToast()
        setupGestures()
        setupTimers()

        // Sync NowPlayingService with RemoteCommandCenter
        setupRemoteCommandCenterCallbacks()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkResumePrompt()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        periodicTimer?.invalidate()
        controlsHideTimer?.invalidate()
        hudTimer?.invalidate()
    }

    // MARK: - Video Surface (KSPlayer Metal Hardware Output)
    private func setupVideoSurface() {
        viewModel.engine.onVideoViewReady = { [weak self] surface in
            self?.attachVideoSurface(surface)
        }
        if let surface = viewModel.engine.playerLayer?.player.view {
            attachVideoSurface(surface)
        }
    }

    private func attachVideoSurface(_ surface: UIView) {
        if videoSurfaceView === surface { return }
        videoSurfaceView?.removeFromSuperview()
        videoSurfaceView = surface
        surface.contentMode = .scaleAspectFit
        surface.layer.contentsScale = UIScreen.main.scale
        surface.contentScaleFactor = UIScreen.main.scale
        surface.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(surface, at: 0)

        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: view.topAnchor),
            surface.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            surface.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    // MARK: - Scrim Gradient
    private func setupScrim() {
        scrimView.translatesAutoresizingMaskIntoConstraints = false
        scrimView.backgroundColor = .clear
        scrimView.isUserInteractionEnabled = false

        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.6).cgColor,
            UIColor.black.withAlphaComponent(0.92).cgColor
        ]
        gradient.locations = [0.0, 0.5, 1.0]
        gradient.frame = CGRect(x: 0, y: 0, width: 1920, height: 280)
        scrimView.layer.addSublayer(gradient)

        view.addSubview(scrimView)
        NSLayoutConstraint.activate([
            scrimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrimView.heightAnchor.constraint(equalToConstant: 280)
        ])
    }

    // MARK: - Top Right Header Bar (Signal Strength & Quality/Mode Badges)
    private func setupTopBar() {
        topBarContainer.translatesAutoresizingMaskIntoConstraints = false
        topBarContainer.axis = .horizontal
        topBarContainer.spacing = 10
        topBarContainer.alignment = .center
        topBarContainer.alpha = 0.0
        view.addSubview(topBarContainer)

        signalStrengthView.translatesAutoresizingMaskIntoConstraints = false
        topBarContainer.addArrangedSubview(signalStrengthView)

        setupBadgeLabel(qualityBadge, text: viewModel.release.effectiveTier, isHighlight: true)
        topBarContainer.addArrangedSubview(qualityBadge)

        let modeText = viewModel.isTranscoding ? "H.264" : "DIRECT STREAM"
        setupBadgeLabel(modeBadge, text: modeText, isHighlight: false)
        topBarContainer.addArrangedSubview(modeBadge)

        NSLayoutConstraint.activate([
            topBarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            topBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            topBarContainer.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func setupBadgeLabel(_ label: UILabel, text: String, isHighlight: Bool) {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        label.textColor = isHighlight ? UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0) : UIColor.white.withAlphaComponent(0.8)
        label.backgroundColor = isHighlight ? UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.15) : UIColor.white.withAlphaComponent(0.12)
        label.layer.borderColor = isHighlight ? UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.4).cgColor : UIColor.white.withAlphaComponent(0.18).cgColor
        label.layer.borderWidth = 1
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        label.textAlignment = .center
        label.text = " \(text) "
    }

    // MARK: - Bottom Transport Controls Deck
    private func setupControls() {
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.alpha = 0.0 // Initially hidden
        view.addSubview(controlsContainer)

        NSLayoutConstraint.activate([
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            controlsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            controlsContainer.heightAnchor.constraint(equalToConstant: 130)
        ])

        // 1. Title Label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = viewModel.displayTitle
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail
        controlsContainer.addSubview(titleLabel)

        // 2. Action Buttons (Right side)
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 20
        buttonsStack.alignment = .center
        buttonsStack.clipsToBounds = false
        controlsContainer.addSubview(buttonsStack)

        setupActionButton(subtitlesButton, iconName: "captions.bubble", accessibility: "Субтитры")
        setupActionButton(audioButton, iconName: "waveform", accessibility: "Звук")
        setupActionButton(qualityButton, iconName: "slider.horizontal.3", accessibility: "Качество")

        updateMenus()

        buttonsStack.addArrangedSubview(subtitlesButton)
        buttonsStack.addArrangedSubview(audioButton)
        buttonsStack.addArrangedSubview(qualityButton)

        // 3. Interactive Scrubber Control
        scrubberControl.translatesAutoresizingMaskIntoConstraints = false
        scrubberControl.viewModel = viewModel
        scrubberControl.onUserInteraction = { [weak self] in
            self?.resetHideControlsTimer()
        }
        scrubberControl.onNavigateToButtons = { [weak self] in
            guard let self = self else { return }
            self.focusButton(self.subtitlesButton)
        }
        controlsContainer.addSubview(scrubberControl)

        // Layout Constraints
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: controlsContainer.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: buttonsStack.leadingAnchor, constant: -30),

            // Scrubber
            scrubberControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            scrubberControl.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            scrubberControl.trailingAnchor.constraint(equalTo: buttonsStack.leadingAnchor, constant: -30),
            scrubberControl.heightAnchor.constraint(equalToConstant: 46),

            // Buttons Stack
            buttonsStack.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            buttonsStack.centerYAnchor.constraint(equalTo: scrubberControl.centerYAnchor)
        ])

        // 4. Focus Guides for seamless Siri Remote D-Pad Navigation
        // Guide A: Down swipes on scrubber smoothly focus subtitles button
        let scrubberDownGuide = UIFocusGuide()
        controlsContainer.addLayoutGuide(scrubberDownGuide)
        NSLayoutConstraint.activate([
            scrubberDownGuide.topAnchor.constraint(equalTo: scrubberControl.bottomAnchor),
            scrubberDownGuide.leadingAnchor.constraint(equalTo: scrubberControl.leadingAnchor),
            scrubberDownGuide.trailingAnchor.constraint(equalTo: scrubberControl.trailingAnchor),
            scrubberDownGuide.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor)
        ])
        scrubberDownGuide.preferredFocusEnvironments = [subtitlesButton]

        // Guide B: Right swipes bridging the gap between scrubber and buttons
        let scrubberRightGuide = UIFocusGuide()
        controlsContainer.addLayoutGuide(scrubberRightGuide)
        NSLayoutConstraint.activate([
            scrubberRightGuide.topAnchor.constraint(equalTo: scrubberControl.topAnchor),
            scrubberRightGuide.bottomAnchor.constraint(equalTo: scrubberControl.bottomAnchor),
            scrubberRightGuide.leadingAnchor.constraint(equalTo: scrubberControl.trailingAnchor),
            scrubberRightGuide.trailingAnchor.constraint(equalTo: buttonsStack.leadingAnchor)
        ])
        scrubberRightGuide.preferredFocusEnvironments = [subtitlesButton]

        // Guide C: Up swipes on buttons smoothly return to scrubber
        let buttonsUpGuide = UIFocusGuide()
        controlsContainer.addLayoutGuide(buttonsUpGuide)
        NSLayoutConstraint.activate([
            buttonsUpGuide.bottomAnchor.constraint(equalTo: buttonsStack.topAnchor),
            buttonsUpGuide.leadingAnchor.constraint(equalTo: buttonsStack.leadingAnchor),
            buttonsUpGuide.trailingAnchor.constraint(equalTo: buttonsStack.trailingAnchor),
            buttonsUpGuide.topAnchor.constraint(equalTo: controlsContainer.topAnchor)
        ])
        buttonsUpGuide.preferredFocusEnvironments = [scrubberControl]
    }

    func focusButton(_ button: UIButton) {
        programmaticallyTargetedView = button
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        programmaticallyTargetedView = nil
    }

    private func setupActionButton(_ button: UIButton, iconName: String, accessibility: String) {
        button.translatesAutoresizingMaskIntoConstraints = false

        var config = UIButton.Configuration.plain()
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        config.image = UIImage(systemName: iconName, withConfiguration: symbolConfig)
        config.cornerStyle = .capsule
        config.baseForegroundColor = .white
        config.background.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        button.configuration = config

        button.configurationUpdateHandler = { btn in
            var updated = btn.configuration ?? UIButton.Configuration.plain()
            if btn.isFocused {
                updated.baseForegroundColor = .black
                updated.background.backgroundColor = .white
                btn.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
                btn.layer.shadowColor = UIColor.white.cgColor
                btn.layer.shadowRadius = 8
                btn.layer.shadowOpacity = 0.6
                btn.layer.shadowOffset = .zero
            } else {
                updated.baseForegroundColor = .white
                updated.background.backgroundColor = UIColor.white.withAlphaComponent(0.18)
                btn.transform = .identity
                btn.layer.shadowOpacity = 0
            }
            btn.configuration = updated
        }

        button.accessibilityLabel = accessibility
        button.showsMenuAsPrimaryAction = true

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 54),
            button.heightAnchor.constraint(equalToConstant: 54)
        ])
    }

    // MARK: - Native tvOS System Menus (UIMenu)
    func updateMenus() {
        updateAudioMenu()
        updateSubtitlesMenu()
        updateQualityMenu()
    }

    func updateAudioMenu() {
        let tracks = viewModel.audioTracks
        if tracks.isEmpty {
            audioButton.menu = UIMenu(title: "Звук", children: [
                UIAction(title: "Поиск аудиодорожек...", attributes: .disabled) { _ in }
            ])
            return
        }

        let currentId = viewModel.currentAudioTrackId
        let actions: [UIAction] = tracks.map { track in
            let isCurrent = track.id == currentId
            return UIAction(
                title: track.displayName,
                state: isCurrent ? .on : .off
            ) { [weak self] _ in
                self?.viewModel.selectAudio(trackId: track.id, title: track.title)
                self?.updateAudioMenu()
                self?.resetHideControlsTimer()
            }
        }
        audioButton.menu = UIMenu(title: "Звук", children: actions)
    }

    func updateSubtitlesMenu() {
        let tracks = viewModel.subtitleTracks
        let currentId = viewModel.currentSubtitleTrackId
        let actions: [UIAction] = tracks.map { track in
            let isCurrent = track.id == currentId
            return UIAction(
                title: track.displayName,
                state: isCurrent ? .on : .off
            ) { [weak self] _ in
                self?.viewModel.selectSubtitle(trackId: track.id)
                self?.updateSubtitlesMenu()
                self?.resetHideControlsTimer()
            }
        }
        subtitlesButton.menu = UIMenu(title: "Субтитры", children: actions)
    }

    func updateQualityMenu() {
        var elements: [UIMenuElement] = []

        // 1. Transcode & Stream Mode Group
        let directAction = UIAction(
            title: "⚡ Прямой поток (MKV)",
            state: !viewModel.isTranscoding ? .on : .off
        ) { [weak self] _ in
            self?.viewModel.switchTranscodeMode(enableTranscode: false)
            self?.updateMenus()
            self?.resetHideControlsTimer()
        }

        let transcode1080Action = UIAction(
            title: "⚙️ 1080p Full HD (Транскод H.264)",
            state: (viewModel.isTranscoding && viewModel.activeTranscodeProfile == "1080p") ? .on : .off
        ) { [weak self] _ in
            self?.viewModel.switchTranscodeMode(enableTranscode: true, profile: "1080p")
            self?.updateMenus()
            self?.resetHideControlsTimer()
        }

        let transcode720Action = UIAction(
            title: "⚙️ 720p HD (Транскод H.264)",
            state: (viewModel.isTranscoding && viewModel.activeTranscodeProfile == "720p") ? .on : .off
        ) { [weak self] _ in
            self?.viewModel.switchTranscodeMode(enableTranscode: true, profile: "720p")
            self?.updateMenus()
            self?.resetHideControlsTimer()
        }

        let transcode480Action = UIAction(
            title: "⚙️ 480p SD (Быстрый старт H.264)",
            state: (viewModel.isTranscoding && viewModel.activeTranscodeProfile == "480p") ? .on : .off
        ) { [weak self] _ in
            self?.viewModel.switchTranscodeMode(enableTranscode: true, profile: "480p")
            self?.updateMenus()
            self?.resetHideControlsTimer()
        }

        elements.append(UIMenu(
            title: "Режим воспроизведения",
            options: .displayInline,
            children: [directAction, transcode1080Action, transcode720Action, transcode480Action]
        ))

        // 2. Releases from trackers
        if !viewModel.qualityGroups.isEmpty {
            var releaseGroupElements: [UIMenuElement] = []
            for group in viewModel.qualityGroups {
                let releaseActions = group.releases.map { rel in
                    let isCurrent = rel.effectiveHash == viewModel.release.effectiveHash
                    return UIAction(
                        title: "\(group.tier) [\(rel.codecBadge)]: \(rel.sizeFormatted) • 🌱\(rel.seeds)",
                        state: isCurrent ? .on : .off
                    ) { [weak self] _ in
                        Task { @MainActor in
                            await self?.viewModel.switchQuality(to: rel)
                            self?.titleLabel.text = self?.viewModel.displayTitle
                            self?.updateMenus()
                            self?.resetHideControlsTimer()
                        }
                    }
                }

                if group.releases.count == 1, let single = releaseActions.first {
                    releaseGroupElements.append(single)
                } else {
                    releaseGroupElements.append(UIMenu(title: "\(group.title) (\(group.releases.count))", children: releaseActions))
                }
            }
            elements.append(UIMenu(title: "Раздачи трекеров", options: .displayInline, children: releaseGroupElements))
        }

        qualityButton.menu = UIMenu(title: "Качество и транскодирование", children: elements)
    }

    // MARK: - Floating HUD Toast (+10s / -10s)
    private func setupHUDToast() {
        hudToastContainer.translatesAutoresizingMaskIntoConstraints = false
        hudToastContainer.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        hudToastContainer.layer.cornerRadius = 20
        hudToastContainer.clipsToBounds = true
        hudToastContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        hudToastContainer.layer.borderWidth = 1
        hudToastContainer.alpha = 0.0

        hudToastIcon.translatesAutoresizingMaskIntoConstraints = false
        hudToastIcon.tintColor = .white
        hudToastContainer.addSubview(hudToastIcon)

        hudToastLabel.translatesAutoresizingMaskIntoConstraints = false
        hudToastLabel.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        hudToastLabel.textColor = .white
        hudToastContainer.addSubview(hudToastLabel)

        view.addSubview(hudToastContainer)

        NSLayoutConstraint.activate([
            hudToastContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hudToastContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            hudToastContainer.heightAnchor.constraint(equalToConstant: 64),

            hudToastIcon.leadingAnchor.constraint(equalTo: hudToastContainer.leadingAnchor, constant: 20),
            hudToastIcon.centerYAnchor.constraint(equalTo: hudToastContainer.centerYAnchor),
            hudToastIcon.widthAnchor.constraint(equalToConstant: 28),
            hudToastIcon.heightAnchor.constraint(equalToConstant: 28),

            hudToastLabel.leadingAnchor.constraint(equalTo: hudToastIcon.trailingAnchor, constant: 12),
            hudToastLabel.trailingAnchor.constraint(equalTo: hudToastContainer.trailingAnchor, constant: -24),
            hudToastLabel.centerYAnchor.constraint(equalTo: hudToastContainer.centerYAnchor)
        ])
    }

    func showHUDToast(isForward: Bool) {
        hudTimer?.invalidate()
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        hudToastIcon.image = UIImage(systemName: isForward ? "goforward.10" : "gobackward.10", withConfiguration: config)
        hudToastLabel.text = isForward ? "+10с" : "-10с"

        UIView.animate(withDuration: 0.15) {
            self.hudToastContainer.alpha = 1.0
        }

        hudTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            UIView.animate(withDuration: 0.2) {
                self?.hudToastContainer.alpha = 0.0
            }
        }
    }

    // MARK: - Siri Remote Gestures
    private func setupGestures() {
        // 1. Play/Pause Button
        let playPause = UITapGestureRecognizer(target: self, action: #selector(handlePlayPause(_:)))
        playPause.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        view.addGestureRecognizer(playPause)
        self.playPauseGesture = playPause

        // 2. Menu / Back Button
        let menu = UITapGestureRecognizer(target: self, action: #selector(handleMenu(_:)))
        menu.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(menu)
        self.menuGesture = menu

        // 3. Select Button (when controls are hidden, reveals controls)
        let select = UITapGestureRecognizer(target: self, action: #selector(handleSelect(_:)))
        select.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        select.delegate = self
        view.addGestureRecognizer(select)
        self.selectGesture = select

        // 4. Clickpad Left/Right Skips (-10s / +10s when controls are hidden)
        let left = UITapGestureRecognizer(target: self, action: #selector(handleLeftSkip(_:)))
        left.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        left.delegate = self
        view.addGestureRecognizer(left)
        self.leftGesture = left

        let right = UITapGestureRecognizer(target: self, action: #selector(handleRightSkip(_:)))
        right.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
        right.delegate = self
        view.addGestureRecognizer(right)
        self.rightGesture = right
    }

    // UIGestureRecognizerDelegate: Only intercept Left/Right/Select when controls are HIDDEN
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
        if gestureRecognizer === leftGesture || gestureRecognizer === rightGesture || gestureRecognizer === selectGesture {
            return !areControlsVisible
        }
        return true
    }

    @objc private func handlePlayPause(_ gesture: UITapGestureRecognizer) {
        if areControlsVisible && scrubberControl.isScrubbing {
            scrubberControl.commitScrubbing()
            viewModel.play()
            resetHideControlsTimer()
            return
        }

        viewModel.togglePlayPause()
        if !viewModel.engine.isPlaying {
            showControls()
        } else {
            resetHideControlsTimer()
        }
    }

    @objc private func handleMenu(_ gesture: UITapGestureRecognizer) {
        if areControlsVisible {
            if scrubberControl.isScrubbing {
                scrubberControl.cancelScrubbing()
            } else {
                hideControls()
            }
        } else {
            closePlayer()
        }
    }

    @objc private func handleSelect(_ gesture: UITapGestureRecognizer) {
        if !areControlsVisible {
            showControls()
        }
    }

    @objc private func handleLeftSkip(_ gesture: UITapGestureRecognizer) {
        viewModel.seekRelative(seconds: -10)
        showHUDToast(isForward: false)
    }

    @objc private func handleRightSkip(_ gesture: UITapGestureRecognizer) {
        viewModel.seekRelative(seconds: 10)
        showHUDToast(isForward: true)
    }

    // MARK: - Controls Visibility
    func showControls() {
        areControlsVisible = true
        updateMenus()
        UIView.animate(withDuration: 0.25) {
            self.controlsContainer.alpha = 1.0
            self.topBarContainer.alpha = 1.0
            self.scrimView.alpha = 1.0
        } completion: { _ in
            self.setNeedsFocusUpdate()
            self.updateFocusIfNeeded()
        }
        resetHideControlsTimer()
    }

    func hideControls() {
        controlsHideTimer?.invalidate()
        if scrubberControl.isScrubbing {
            scrubberControl.cancelScrubbing()
        }
        areControlsVisible = false
        UIView.animate(withDuration: 0.25) {
            self.controlsContainer.alpha = 0.0
            self.topBarContainer.alpha = 0.0
            self.scrimView.alpha = 0.0
        }
    }

    private func resetHideControlsTimer() {
        controlsHideTimer?.invalidate()
        guard viewModel.engine.isPlaying && !scrubberControl.isScrubbing else { return }

        controlsHideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.hideControls()
        }
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let target = programmaticallyTargetedView {
            return [target]
        }
        if areControlsVisible {
            return [scrubberControl, subtitlesButton, audioButton, qualityButton]
        }
        return []
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if areControlsVisible {
            resetHideControlsTimer()
        }
    }

    // MARK: - Periodic Timer (Updates Scrubber & Timecodes)
    private func setupTimers() {
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updatePlaybackProgress()
        }
    }

    private func updatePlaybackProgress() {
        let cur = viewModel.engine.currentTime
        let dur = viewModel.duration
        scrubberControl.updateUI(currentTime: cur, duration: dur)

        // Update real-time swarm throughput & cellular signal
        signalStrengthView.update(stats: viewModel.streamStats)
        qualityBadge.text = " \(viewModel.release.effectiveTier) "
        modeBadge.text = viewModel.isTranscoding ? " H.264 " : " DIRECT STREAM "

        // If audio tracks just loaded, refresh menu
        if (audioButton.menu?.children.count ?? 0) <= 1 && !viewModel.engine.audioTracks.isEmpty {
            updateAudioMenu()
        }
    }

    // MARK: - Native Resume Alert (1:1 with tvOS dialog)
    private func checkResumePrompt() {
        guard viewModel.showResumePrompt && viewModel.resumeSeconds > 60 else { return }
        viewModel.showResumePrompt = false

        let formattedTime = scrubberControl.formatSeconds(viewModel.resumeSeconds)
        let alert = UIAlertController(
            title: "Возобновить воспроизведение\nили начать проигрывание заново?",
            message: nil,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Возобновить (\(formattedTime))", style: .default) { [weak self] _ in
            Task { @MainActor in
                await self?.viewModel.confirmResume()
            }
        })

        alert.addAction(UIAlertAction(title: "Начать заново", style: .default) { [weak self] _ in
            Task { @MainActor in
                await self?.viewModel.startFromBeginning()
            }
        })

        present(alert, animated: true)
    }

    private func setupRemoteCommandCenterCallbacks() {
        viewModel.nowPlayingService.onTogglePlayPause = { [weak self] in
            self?.viewModel.togglePlayPause()
            if !(self?.viewModel.engine.isPlaying ?? false) {
                self?.showControls()
            }
        }
        viewModel.nowPlayingService.onPause = { [weak self] in
            self?.viewModel.pause()
            self?.showControls()
        }
        viewModel.nowPlayingService.onSkipForward = { [weak self] interval in
            self?.viewModel.seekRelative(seconds: interval)
            self?.showHUDToast(isForward: true)
        }
        viewModel.nowPlayingService.onSkipBackward = { [weak self] interval in
            self?.viewModel.seekRelative(seconds: -interval)
            self?.showHUDToast(isForward: false)
        }
    }

    private func closePlayer() {
        viewModel.stop()
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }
}

// MARK: - SwiftUI Representable Bridge
struct NativeVLCPlayerView: UIViewControllerRepresentable {
    let viewModel: PlayerViewModel
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> NativeVLCPlayerViewController {
        return NativeVLCPlayerViewController(viewModel: viewModel, onDismiss: onDismiss)
    }

    func updateUIViewController(_ uiViewController: NativeVLCPlayerViewController, context: Context) {
        // Driven by internal timers and callbacks
    }
}
