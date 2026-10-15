//
//  SIGPlayController.swift
//  SIG
//
//

import QuartzCore
import UIKit
#if PREMIUM
import YUSPremium
#else
import YUSAd
#endif
import YUSKit

public final class SIGPlayController: YUSViewController, YUSTilesViewDelegate,
    YUSMiniMapViewDelegate, @preconcurrency SIGPlayBridgeUI
{
    private enum UnitActionDestination {
        case perform
        case inventory
        case production
        case weapon
    }

    private struct UnitActionMetadata {
        let action: SIGUnitAction
        let title: String
        let destination: UnitActionDestination
        let isSpecial: Bool
        let opensMenuOnTap: Bool
        let style: UIAlertAction.Style

        init(
            _ action: SIGUnitAction,
            _ title: String,
            destination: UnitActionDestination = .perform,
            isSpecial: Bool = false,
            opensMenuOnTap: Bool = false,
            style: UIAlertAction.Style = .default
        ) {
            self.action = action
            self.title = title
            self.destination = destination
            self.isSpecial = isSpecial
            self.opensMenuOnTap = opensMenuOnTap
            self.style = style
        }
    }

    private struct SpriteLayer {
        let layer: CALayer
        var image: CGImage
        var unzoomedFrame: CGRect
    }

    private var saveFile = ""

    public convenience init(savedURL: URL) {
        self.init(nibName: nil, bundle: nil)
        saveFile = savedURL.path
    }

    private let bridge = SIGPlayBridge()
    private let music = SIGMusicSession()
    private lazy var tileLayout: SIGTileLayout = {
        let layout = SIGTileLayout(bridge: bridge)
        layout.tileWidth = 56
        layout.tileHeight = 28
        layout.zoom = 1
        return layout
    }()
    private lazy var mapView = YUSTilesView(frame: .zero, collectionViewLayout: tileLayout)
    private let linesLayer = CALayer()
    private let spritesLayer = CALayer()
    private let topMenuView = YUSTopMenuView(frame: .zero)
    private let endTurnButton = YUSButton(style: .filled)
    private let creditsButton = YUSButton(style: .status)
    private let turnButton = YUSButton(style: .status)
    private let miniMapView = YUSMiniMapView(frame: .zero)
    private let miniMapViewportLayer = CAShapeLayer()
    private let unitInfoLabel = UILabel(frame: .zero)
    private let unitOrdersView = YUSTopMenuView(frame: .zero)
    private let weaponView = YUSTopMenuView(frame: .zero)
    private let specialView = YUSTopMenuView(frame: .zero)
    private let turnActivityIndicator = UIActivityIndicatorView(style: .large)
    private let notificationsButton = YUSAutoFadeButton(frame: .zero)
    private var notificationsMaxFrame = CGRect.zero
    private var notifications: [String] = []
    private var recentMessages: [String] = []
    private let maximumNotifications = 200
    private var miniImageGrid: CGFloat = 1
    private var maximumUnitInfoFrame = CGRect.zero
    private var spriteLayers: [SpriteLayer] = []
    private var spriteLayerZoom: CGFloat = 1
    private var stopped = false
    private var engineStarted = false
    private var pendingCenterTile: IndexPath?
    private var startupErrorPresented = false
    private let contextButtonSpacing: CGFloat = 4
    private static let unitActionMetadata: [UnitActionMetadata] = [
        UnitActionMetadata(.select, String(localized: "Select", bundle: frameworkBundle)),
        UnitActionMetadata(.selectAircraft, String(localized: "Select Aircraft", bundle: frameworkBundle)),
        UnitActionMetadata(.move, String(localized: "Move", bundle: frameworkBundle)),
        UnitActionMetadata(.moveAircraft, String(localized: "Fly", bundle: frameworkBundle)),
        UnitActionMetadata(.attack, String(localized: "Attack", bundle: frameworkBundle)),
        UnitActionMetadata(.attackField, String(localized: "Attack Ground", bundle: frameworkBundle)),
        UnitActionMetadata(
            .attackFriendly,
            String(localized: "Attack Friendly Unit", bundle: frameworkBundle)
        ),
        UnitActionMetadata(
            .attackAircraft,
            String(localized: "Attack Aircraft", bundle: frameworkBundle)
        ),
        UnitActionMetadata(
            .attackFriendlyAircraft,
            String(localized: "Attack Friendly Aircraft", bundle: frameworkBundle)
        ),
        UnitActionMetadata(
            .attackSubmarine,
            String(localized: "Attack Submarine", bundle: frameworkBundle)
        ),
        UnitActionMetadata(.support, String(localized: "Support", bundle: frameworkBundle)),
        UnitActionMetadata(
            .supportAircraft,
            String(localized: "Support Aircraft", bundle: frameworkBundle)
        ),
        UnitActionMetadata(.load, String(localized: "Load", bundle: frameworkBundle)),
        UnitActionMetadata(.occupy, String(localized: "Capture", bundle: frameworkBundle)),
        UnitActionMetadata(
            .landAtHeliport,
            String(localized: "Land at Heliport", bundle: frameworkBundle)
        ),
        UnitActionMetadata(
            .landAtAirport,
            String(localized: "Land at Airport", bundle: frameworkBundle)
        ),
        UnitActionMetadata(.build, String(localized: "Build", bundle: frameworkBundle)),
        UnitActionMetadata(
            .inventory,
            String(localized: "Inventory", bundle: frameworkBundle),
            destination: .inventory,
            isSpecial: true,
            opensMenuOnTap: true
        ),
        UnitActionMetadata(
            .production,
            String(localized: "Production", bundle: frameworkBundle),
            destination: .production,
            isSpecial: true,
            opensMenuOnTap: true
        ),
        UnitActionMetadata(
            .weapon,
            String(localized: "Weapon", bundle: frameworkBundle),
            destination: .weapon,
            opensMenuOnTap: true
        ),
        UnitActionMetadata(
            .land,
            String(localized: "Land", bundle: frameworkBundle),
            isSpecial: true,
            opensMenuOnTap: true
        ),
        UnitActionMetadata(
            .takeOff,
            String(localized: "Take Off", bundle: frameworkBundle),
            isSpecial: true,
            opensMenuOnTap: true
        ),
        UnitActionMetadata(
            .selfDestruct,
            String(localized: "Self-Destruct", bundle: frameworkBundle),
            isSpecial: true,
            style: .destructive
        ),
        UnitActionMetadata(
            .placeMine,
            String(localized: "Place Mine", bundle: frameworkBundle),
            isSpecial: true
        ),
        UnitActionMetadata(
            .removeMine,
            String(localized: "Remove Mine", bundle: frameworkBundle),
            isSpecial: true
        ),
        UnitActionMetadata(
            .raiseTurret,
            String(localized: "Raise Turret", bundle: frameworkBundle),
            isSpecial: true
        ),
        UnitActionMetadata(
            .lowerTurret,
            String(localized: "Lower Turret", bundle: frameworkBundle),
            isSpecial: true
        ),
        UnitActionMetadata(
            .startBombing,
            String(localized: "Start Bombing", bundle: frameworkBundle),
            isSpecial: true
        ),
        UnitActionMetadata(
            .stopBombing,
            String(localized: "Stop Bombing", bundle: frameworkBundle),
            isSpecial: true
        ),
    ]

    public override func viewDidLoad() {
        super.viewDidLoad()
        bridge.ui = self
        view.addSubview(mapView)
        mapView.register(SIGTileCell.self, forCellWithReuseIdentifier: YUSTilesViewCellReuseID)
        mapView.tileDelegate = self
        // The HUD insets below already include the safe area.
        mapView.contentInsetAdjustmentBehavior = .never
        mapView.layer.addSublayer(linesLayer)
        mapView.layer.addSublayer(spritesLayer)

        topMenuView.actions = [
            YUSAction(
                title: String(localized: "Game", bundle: frameworkBundle),
                image: YUSImages.menuImage,
                style: .default
            ) { [weak self] _ in self?.showGameMenu() },
            YUSAction(
                title: String(localized: "Overlay", bundle: frameworkBundle),
                image: YUSImages.configImage,
                style: .default
            ) { [weak self] _ in self?.showOverlayMenu() },
            YUSAction(
                title: String(localized: "Reserve", bundle: frameworkBundle),
                image: YUSImages.defendImage,
                style: .default
            ) { [weak self] _ in self?.showReserveMenu() },
        ]
        view.addSubview(topMenuView)

        endTurnButton.accessibilityLabel = String(localized: "End Turn", bundle: frameworkBundle)
        endTurnButton.setImage(YUSImages.endTurnImage, for: .normal)
        endTurnButton.tintColor = .white
        endTurnButton.addAction(UIAction { [weak self] _ in
            self?.endTurn()
        }, for: .touchUpInside)
        view.addSubview(endTurnButton)

        for button in [creditsButton, turnButton] {
            button.addAction(UIAction { [weak self] _ in
                self?.showMissionBriefing()
            }, for: .touchUpInside)
            view.addSubview(button)
        }

        miniMapView.delegate = self
        miniMapView.mapX = bridge.mapWidth
        miniMapView.mapY = bridge.mapHeight
        miniMapView.viewPortView.isHidden = true
        miniMapViewportLayer.fillColor = UIColor.clear.cgColor
        miniMapViewportLayer.strokeColor = UIColor.white.cgColor
        miniMapViewportLayer.lineWidth = 1
        miniMapView.imageView.layer.magnificationFilter = .nearest
        miniMapView.imageView.layer.addSublayer(miniMapViewportLayer)
        // A pictorial overview with no per-tile meaning for VoiceOver, as in SCT.
        miniMapView.accessibilityElementsHidden = true
        view.addSubview(miniMapView)

        YUSGame.setupInfoLabel(unitInfoLabel)
        view.addSubview(unitInfoLabel)

        unitOrdersView.actions = [
            YUSAction(
                title: String(localized: "Next", bundle: frameworkBundle),
                image: UIImage(systemName: "arrow.right"),
                style: .default
            ) { [weak self] _ in self?.selectNextUnit() },
            YUSAction(
                title: String(localized: "Center", bundle: frameworkBundle),
                image: UIImage(systemName: "viewfinder"),
                style: .default
            ) { [weak self] _ in self?.centerSelectedUnit() },
            YUSAction(
                title: String(localized: "Detail", bundle: frameworkBundle),
                image: YUSImages.infoImage,
                style: .default
            ) { [weak self] _ in self?.showSelectedUnit() },
        ]
        view.addSubview(unitOrdersView)

        weaponView.actions = [YUSAction(
            title: String(localized: "Weapon", bundle: frameworkBundle),
            image: UIImage(systemName: "scope"),
            style: .default
        ) { [weak self] _ in self?.showWeaponMenu() }]
        view.addSubview(weaponView)

        specialView.actions = [YUSAction(
            title: String(localized: "Special", bundle: frameworkBundle),
            image: UIImage(systemName: "ellipsis"),
            style: .default
        ) { [weak self] _ in self?.showSpecialMenu() }]
        view.addSubview(specialView)

        setupNotificationsButton()

        turnActivityIndicator.color = .white
        turnActivityIndicator.hidesWhenStopped = true
        view.addSubview(turnActivityIndicator)
        updateContextControls()

        NotificationCenter.default.addObserver(
            self, selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    /// Autosave When Leaving App (YUSFileService, app-wide, default on): iOS may terminate a suspended
    /// app at any time, so save into the game's own file as Exit Game does. Not while the worker thread
    /// owns the engine during a turn, and not once the mission has ended: like the end-of-turn autosave,
    /// keep the last playable turn instead of the final board.
    @objc private func applicationDidEnterBackground() {
        guard YUSFileService.autosaveWhenLeavingApp, engineStarted, !stopped,
              !bridge.turnInProgress, bridge.terminationStatus == 0 else { return }
        let task = UIApplication.shared.beginBackgroundTask(withName: "Save Game")
        defer { UIApplication.shared.endBackgroundTask(task) }
        _ = bridge.save(toFile: saveFile)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !engineStarted, !stopped else { return }
        guard bridge.start(withSaveFile: saveFile) else {
            stopped = true
            return
        }
        engineStarted = true
        tileLayout.mapX = bridge.mapWidth
        tileLayout.mapY = bridge.mapHeight
        miniMapView.mapX = bridge.mapWidth
        miniMapView.mapY = bridge.mapHeight
        tileLayout.invalidateLayout()
        view.setNeedsLayout()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard engineStarted else { return }
        let size = view.bounds.size
        let insets = view.safeAreaInsets
        let margins = YUSLayoutService.hudMargins(for: view)
        mapView.frame = view.bounds
        turnActivityIndicator.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let displayScale = traitCollection.displayScale
        linesLayer.contentsScale = displayScale
        miniMapViewportLayer.contentsScale = displayScale
        layoutMapLayers()

        let buttonSize = max(YUSLayoutService.squareButtonSize, 44)
        topMenuView.frame = CGRect(
            x: margins.left,
            y: insets.top,
            width: buttonSize * CGFloat(topMenuView.actions.count),
            height: buttonSize
        )
        endTurnButton.frame = CGRect(
            x: size.width - margins.right - buttonSize,
            y: insets.top,
            width: buttonSize,
            height: buttonSize
        )
        endTurnButton.layer.cornerRadius = buttonSize / 2
        // Status row between the top menu and End Turn, capped so it doesn't stretch on wide windows.
        let statusWidth = max(0, min(endTurnButton.frame.minX - topMenuView.frame.maxX, buttonSize * 6))
        let statusItemWidth = floor(statusWidth / 2)
        turnButton.frame = CGRect(
            x: endTurnButton.frame.minX - statusItemWidth,
            y: insets.top,
            width: statusItemWidth,
            height: buttonSize
        )
        creditsButton.frame = turnButton.frame.offsetBy(dx: -statusItemWidth, dy: 0)
        for button in [creditsButton, turnButton] {
            button.layer.cornerRadius = buttonSize / 2
        }
        endTurnButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: round(buttonSize * 0.4), weight: .semibold),
            forImageIn: .normal
        )

        var infoHeight = ceil(unitInfoLabel.font.lineHeight)
        if size.width < size.height { infoHeight = ceil(infoHeight * 1.5) }
        let miniMapTop = endTurnButton.frame.maxY
        var miniWidth = YUSLayoutService.miniMapWidth
        var miniHeight = max(
            1,
            floor(miniWidth * CGFloat(bridge.mapHeight) / CGFloat(bridge.mapWidth))
        )
        let maximumMiniHeight = size.height - insets.bottom - miniMapTop -
            2 * buttonSize - infoHeight - contextButtonSpacing - 4
        if miniHeight > maximumMiniHeight {
            miniHeight = max(1, maximumMiniHeight)
            miniWidth = max(
                1,
                floor(miniHeight * CGFloat(bridge.mapWidth) / CGFloat(bridge.mapHeight))
            )
        }
        miniImageGrid = min(
            miniWidth / CGFloat(bridge.mapWidth),
            miniHeight / CGFloat(bridge.mapHeight)
        )
        miniMapView.frame = CGRect(
            x: size.width - margins.right - miniWidth,
            y: miniMapTop,
            width: miniWidth,
            height: miniHeight
        )

        unitOrdersView.frame = CGRect(
            x: size.width - margins.right - buttonSize * CGFloat(unitOrdersView.actions.count),
            y: size.height - insets.bottom - infoHeight - buttonSize,
            width: buttonSize * CGFloat(unitOrdersView.actions.count),
            height: buttonSize
        )
        let contextButtonY = unitOrdersView.frame.minY - contextButtonSpacing - buttonSize
        specialView.frame = CGRect(
            x: unitOrdersView.frame.maxX - buttonSize,
            y: contextButtonY,
            width: buttonSize,
            height: buttonSize
        )
        weaponView.frame = CGRect(
            x: unitOrdersView.frame.maxX - 2 * buttonSize,
            y: contextButtonY,
            width: buttonSize,
            height: buttonSize
        )
        maximumUnitInfoFrame = CGRect(
            x: margins.left,
            y: size.height - insets.bottom - infoHeight,
            width: size.width - margins.left - margins.right,
            height: infoHeight
        )
        layoutUnitInfo()
        notificationsMaxFrame = CGRect(
            x: margins.left,
            y: topMenuView.frame.maxY,
            width: max(0, miniMapView.frame.minX - margins.left),
            height: max(0, contextButtonY - topMenuView.frame.maxY)
        )
        fitNotificationsButton()
        // Let every map edge scroll clear of the HUD (GAME_HUD_LAYOUT.md): the right column holds the
        // minimap and unit buttons, the bottom row the unit orders and info line.
        mapView.contentInset = UIEdgeInsets(
            top: miniMapView.frame.maxY,
            left: margins.left,
            bottom: size.height - min(unitOrdersView.frame.minY, maximumUnitInfoFrame.minY),
            right: size.width - min(miniMapView.frame.minX, unitOrdersView.frame.minX)
        )
        updateMiniMapViewport()
    }

    public override func viewLayoutMarginsDidChange() {
        super.viewLayoutMarginsDidChange()
        // Unfolding can change the margins after the size transition; relayout the HUD.
        view.setNeedsLayout()
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Folding, rotating, or resizing changes the map insets; keep the same tile centered.
        // Keep an earlier pending tile: while a full-screen controller covers the map, its bounds are stale.
        guard engineStarted else { return }
        pendingCenterTile = pendingCenterTile ?? mapView.centerTile()
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.restorePendingCenterTile()
        }
    }

    /// Re-centers once the map is on screen again, so layout uses the final bounds.
    private func restorePendingCenterTile() {
        guard engineStarted, view.window != nil, let centerTile = pendingCenterTile else { return }
        pendingCenterTile = nil
        view.layoutIfNeeded()
        // Pairs with centerTile(); scrollToItem disagrees when the HUD insets leave little map width.
        mapView.setContentOffset(mapView.centeredContentOffset(for: centerTile), animated: false)
        updateMiniMapViewport()
    }

    private func layoutMapLayers() {
        let mapLayerWidth = tileLayout.zoomedTileWidth *
            CGFloat(bridge.mapWidth + bridge.mapHeight + 1) / 2
        let tileDepthUpperBound = CGFloat(
            (bridge.mapWidth + bridge.mapHeight + 1) * max(bridge.mapWidth, 1)
        )
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        linesLayer.frame = CGRect(
            x: tileLayout.zoomedMapHorizontalInset,
            y: tileLayout.zoomedMapTopInset,
            width: mapLayerWidth,
            height: tileLayout.zoomedTileHeight * CGFloat(bridge.mapWidth + bridge.mapHeight) / 2
        )
        linesLayer.zPosition = tileDepthUpperBound
        spritesLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: mapLayerWidth + 2 * tileLayout.zoomedMapHorizontalInset,
            height: linesLayer.frame.maxY + tileLayout.zoomedMapBottomInset
        )
        spritesLayer.zPosition = tileDepthUpperBound + 1
        CATransaction.commit()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard engineStarted else {
            if stopped { presentStartupError() }
            return
        }
        music.startIfNeeded(.gameplay)
        refreshWorld()
        centerSelectedUnit()
        restorePendingCenterTile()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if sigIsLeaving {
            stopEngine()
        }
    }

    public func configCell(_ cell: UICollectionViewCell, at indexPath: IndexPath) {
        guard let cell = cell as? SIGTileCell else { return }
        cell.configure(
            with: bridge.tileSnapshot(atX: indexPath.row, y: indexPath.section),
            zoom: tileLayout.zoom
        )
    }

    public func tilesView(_ tilesView: YUSTilesView, didTap indexPath: IndexPath) {
        let actions = bridge.availableActions(atX: indexPath.row, y: indexPath.section)
        if Self.unitActionMetadata.contains(where: {
            $0.opensMenuOnTap && actions.contains($0.action)
        }) {
            showActionMenu(at: indexPath)
            return
        }
        guard !actions.isEmpty else { return }
        let previousSelection = bridge.selectedUnitIndexPath
        let worldChanged = bridge.handleTapAndReportWorldChange(
            atX: indexPath.row,
            y: indexPath.section
        )
        refreshAfterAction(worldChanged: worldChanged, previousSelection: previousSelection)
    }

    public func tilesView(_ tilesView: YUSTilesView, didLongPress indexPath: IndexPath) {
        showActionMenu(at: indexPath)
    }

    public func tilesViewDidEndScrolling(_ tilesView: YUSTilesView) {
        updateMiniMapViewport()
    }

    public func tilesViewDidEndZooming(_ tilesView: YUSTilesView) {
        layoutMapLayers()
        scaleSpriteLayersToCurrentZoom()
        redrawRanges()
        tilesViewDidEndScrolling(tilesView)
    }

    public func miniMapView(_ miniMapView: YUSMiniMapView, didTap indexPath: IndexPath) {
        navigateMiniMap(to: indexPath, animated: true)
    }

    public func miniMapView(_ miniMapView: YUSMiniMapView, didPanTo indexPath: IndexPath) {
        navigateMiniMap(to: indexPath, animated: false)
    }

    private func navigateMiniMap(to indexPath: IndexPath, animated: Bool) {
        bridge.updateMiniMapPosition(atX: indexPath.row, y: indexPath.section)
        mapView.scrollToItem(
            at: indexPath,
            at: [.centeredVertically, .centeredHorizontally],
            animated: animated
        )
        if !animated {
            updateMiniMapViewport()
        }
    }

    private func updateMiniMapViewport() {
        let mapSize = CGSize(width: CGFloat(bridge.mapWidth), height: CGFloat(bridge.mapHeight))
        let miniBounds = miniMapView.bounds
        guard let miniImage = miniMapView.imageView.image,
              mapSize.width > 0, mapSize.height > 0,
              miniImage.size.width > 0, miniImage.size.height > 0,
              miniBounds.width > 0, miniBounds.height > 0 else {
            miniMapViewportLayer.path = nil
            return
        }
        let miniScale = min(
            miniBounds.width / miniImage.size.width,
            miniBounds.height / miniImage.size.height
        )
        let miniImageSize = CGSize(
            width: miniImage.size.width * miniScale,
            height: miniImage.size.height * miniScale
        )
        let miniImageFrame = CGRect(
            x: miniBounds.midX - miniImageSize.width / 2,
            y: miniBounds.midY - miniImageSize.height / 2,
            width: miniImageSize.width,
            height: miniImageSize.height
        )

        let mapTopInset = tileLayout.zoomedMapTopInset
        let mapHorizontalInset = tileLayout.zoomedMapHorizontalInset
        let visibleMapCorners = [
            CGPoint(x: mapView.bounds.minX, y: mapView.bounds.minY),
            CGPoint(x: mapView.bounds.maxX, y: mapView.bounds.minY),
            CGPoint(x: mapView.bounds.maxX, y: mapView.bounds.maxY),
            CGPoint(x: mapView.bounds.minX, y: mapView.bounds.maxY),
        ].map { point in
            let difference = (point.x - mapHorizontalInset) * 2 /
                tileLayout.zoomedTileWidth - mapSize.height
            let sum = (point.y - mapTopInset) * 2 / tileLayout.zoomedTileHeight
            return CGPoint(
                x: min(max((difference + sum) / 2, 0), mapSize.width),
                y: min(max((sum - difference) / 2, 0), mapSize.height)
            )
        }

        let path = UIBezierPath()
        for (index, point) in visibleMapCorners.enumerated() {
            let miniPoint = CGPoint(
                x: miniImageFrame.minX + point.x / mapSize.width * miniImageFrame.width,
                y: miniImageFrame.minY + point.y / mapSize.height * miniImageFrame.height
            )
            if index == 0 { path.move(to: miniPoint) }
            else { path.addLine(to: miniPoint) }
        }
        path.close()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        miniMapViewportLayer.frame = miniBounds
        miniMapViewportLayer.path = path.cgPath
        CATransaction.commit()
    }

    public func playBridgePresentsMessage(_ message: String) {
        yus_showTitle(message: message)
    }

    /// Status lines repeat every turn, so they reach the HUD but not the history list.
    public func playBridgeUpdatesTurnStatus(_ status: String) {
        showRecentMessages([status])
        // Input is off during the enemy turn; tell VoiceOver users what the game is doing.
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: status)
        }
    }

    private func setupNotificationsButton() {
        view.addSubview(notificationsButton)
        if let titleLabel = notificationsButton.titleLabel {
            YUSGame.setupInfoLabel(titleLabel)
            titleLabel.backgroundColor = .clear
            titleLabel.textAlignment = .left
        }
        notificationsButton.contentHorizontalAlignment = .left
        notificationsButton.accessibilityLabel = String(localized: "Notifications", bundle: frameworkBundle)
        notificationsButton.isHidden = true
        notificationsButton.addAction(UIAction { [weak self] _ in
            self?.showNotifications()
        }, for: .touchUpInside)
    }

    private func addNotifications(_ messages: [String]) {
        guard !messages.isEmpty else { return }
        notifications.append(contentsOf: messages)
        notifications.removeFirst(max(0, notifications.count - maximumNotifications))
        showRecentMessages(messages)
    }

    private func showRecentMessages(_ messages: [String]) {
        recentMessages = Array((recentMessages + messages).suffix(3))
        notificationsButton.accessibilityValue = recentMessages.reversed().joined(separator: "\n")
        notificationsButton.showMessage(NSAttributedString(
            string: recentMessages.reversed().joined(separator: "\n"),
            attributes: [.foregroundColor: UIColor.white]
        ))
        fitNotificationsButton()
    }

    /// Showing a message restarts its fade, so layout only resizes the button.
    private func fitNotificationsButton() {
        let maximumSize = notificationsMaxFrame.size
        let fit = notificationsButton.sizeThatFits(maximumSize)
        notificationsButton.frame = CGRect(
            origin: notificationsMaxFrame.origin,
            size: CGSize(
                width: min(fit.width, maximumSize.width),
                height: min(fit.height, maximumSize.height)
            )
        )
    }

    private func showNotifications() {
        guard !notifications.isEmpty else { return }
        let controller = SIGNotificationsController(notifications: notifications)
        present(UINavigationController(rootViewController: controller), animated: true)
    }

    private func showGameMenu() {
        var actions = [
            YUSAction(title: String(localized: "Exit Game", bundle: frameworkBundle), style: .default) {
                [weak self] _ in self?.exitGame()
            },
            YUSAction(title: String(localized: "Mission Briefing", bundle: frameworkBundle), style: .default) {
                [weak self] _ in self?.showMissionBriefing()
            },
            YUSAction(title: String(localized: "Options", bundle: frameworkBundle), style: .default) {
                [weak self] _ in self?.showSettings()
            },
            makeCancelAction(),
        ]
        if let manaAction = YUSManaGate.makeAction(from: self) {
            actions.insert(manaAction, at: actions.count - 1)
        }
        yus_showMenu(
            String(localized: "Game Control", bundle: frameworkBundle),
            actions: actions,
            reportsBug: true,
            savedURL: saveFile.isEmpty ? nil : URL(fileURLWithPath: saveFile)
        )
    }

    private func showSettings() {
        present(UINavigationController(rootViewController: SIGSettingsController()), animated: true)
    }

    private func exitGame() {
        guard bridge.save(toFile: saveFile) else {
            yus_showTitle(
                message: String(localized: "Unable to save game.", bundle: frameworkBundle)
            )
            return
        }
        quitGame()
    }

    private func quitGame() {
        // The map keeps laying out during the animation, so the engine must outlive it.
        view.isUserInteractionEnabled = false
        dismiss(animated: true) { [weak self] in
            self?.stopEngine()
        }
    }

    private func stopEngine() {
        guard !stopped else { return }
        stopped = true
        engineStarted = false
        music.finish()
        bridge.stop()
    }

    private func presentStartupError() {
        guard !startupErrorPresented else { return }
        startupErrorPresented = true
        let alert = UIAlertController(
            title: nil,
            message: String(localized: "Unable to start game.", bundle: frameworkBundle),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: String(localized: "OK", bundle: frameworkBundle),
            style: .default
        ) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.dismiss(animated: true)
            }
        })
        present(alert, animated: true)
    }

    private func showMissionBriefing() {
        yus_showTitle(message: bridge.missionBriefing())
    }

    private func showActionMenu(at indexPath: IndexPath) {
        let availableActions = bridge.availableActions(atX: indexPath.row, y: indexPath.section)
        if let metadata = Self.unitActionMetadata.first(where: { $0.action == availableActions }) {
            switch metadata.destination {
            case .inventory, .production, .weapon:
                handleAction(metadata, at: indexPath)
                return
            case .perform:
                break
            }
        }
        let actions = Self.unitActionMetadata.compactMap { metadata -> YUSAction? in
            guard availableActions.contains(metadata.action) else { return nil }
            return YUSAction(title: metadata.title, style: metadata.style) { [weak self] _ in
                guard let self else { return }
                handleAction(metadata, at: indexPath)
            }
        }
        showCancellableMenu(String(localized: "Action", bundle: frameworkBundle), actions: actions)
    }

    private func showInventoryMenu() {
        showChoiceMenu(
            String(localized: "Unload Unit", bundle: frameworkBundle),
            choices: bridge.inventoryChoices()
        ) { [weak self] choice in
            guard let self else { return }
            bridge.unloadUnit(withIdentifier: choice.identifier)
            refreshWorld()
            revealSelectedUnit()
        }
    }

    private func showProductionMenu() {
        showChoiceMenu(
            String(localized: "Production", bundle: frameworkBundle),
            choices: bridge.productionChoices()
        ) { [weak self] choice in
            guard let self else { return }
            if !bridge.produceUnit(withIdentifier: choice.identifier) {
                yus_showTitle(message: String(localized: "Not enough credits.", bundle: frameworkBundle))
            }
            refreshWorld()
        }
    }

    private func showWeaponMenu() {
        showChoiceMenu(
            String(localized: "Weapon", bundle: frameworkBundle),
            choices: bridge.weaponChoices()
        ) { [weak self] choice in
            guard let self else { return }
            guard bridge.selectWeapon(withIdentifier: choice.identifier) else { return }
            refreshSelection(from: bridge.selectedUnitIndexPath)
        }
    }

    private func showChoiceMenu(
        _ title: String,
        choices: [SIGActionChoice],
        onSelect: @escaping @MainActor (SIGActionChoice) -> Void
    ) {
        showCancellableMenu(title, actions: choices.map { choice in
            YUSAction(title: choice.title, style: .default) { _ in onSelect(choice) }
        })
    }

    private func showCancellableMenu(_ title: String, actions: [YUSAction]) {
        guard !actions.isEmpty else { return }
        yus_showMenu(title, actions: actions + [makeCancelAction()])
    }

    private func showSpecialMenu() {
        guard let indexPath = bridge.selectedUnitIndexPath else { return }
        let availableActions = bridge.availableActions(
            atX: indexPath.row,
            y: indexPath.section
        )
        let metadata = Self.unitActionMetadata.filter {
            $0.isSpecial && availableActions.contains($0.action)
        }
        let canRepair = bridge.canRepairSelectedUnit
        if !canRepair, metadata.count == 1, metadata[0].destination != .perform {
            handleAction(metadata[0], at: indexPath)
            return
        }

        var actions = metadata.map { metadata in
            YUSAction(title: metadata.title, style: metadata.style) { [weak self] _ in
                guard let self else { return }
                handleAction(metadata, at: indexPath)
            }
        }
        if canRepair {
            actions.append(YUSAction(
                title: String(localized: "Repair", bundle: frameworkBundle),
                style: .default
            ) { [weak self] _ in self?.repairSelectedUnit() })
        }
        showCancellableMenu(String(localized: "Special", bundle: frameworkBundle), actions: actions)
    }

    private func repairSelectedUnit() {
        // Charges one mana with no free Continue when empty; Premium repairs for free.
        YUSManaGate.spend(from: self) { [weak self] in
            // The ad build's mana prompt runs this later; the game may have been stopped meanwhile.
            guard let self, engineStarted, !stopped, bridge.repairSelectedUnit() else { return }
            refreshWorld()
        }
    }

    private func handleAction(_ metadata: UnitActionMetadata, at indexPath: IndexPath) {
        switch metadata.destination {
        case .perform:
            performAction(metadata, at: indexPath)
        case .inventory:
            showInventoryMenu()
        case .production:
            showProductionMenu()
        case .weapon:
            showWeaponMenu()
        }
    }

    private func performAction(_ metadata: UnitActionMetadata, at indexPath: IndexPath) {
        if metadata.action == .selfDestruct {
            confirmSelfDestruct(metadata, at: indexPath)
            return
        }
        let previousSelection = bridge.selectedUnitIndexPath
        let worldChanged = bridge.performActionAndReportWorldChange(
            metadata.action,
            atX: indexPath.row,
            y: indexPath.section
        )
        refreshAfterAction(worldChanged: worldChanged, previousSelection: previousSelection)
    }

    private func refreshAfterAction(worldChanged: Bool, previousSelection: IndexPath?) {
        if worldChanged {
            refreshWorld()
        } else {
            refreshSelection(from: previousSelection)
        }
        revealSelectedUnit()
    }

    private func confirmSelfDestruct(
        _ metadata: UnitActionMetadata,
        at indexPath: IndexPath
    ) {
        yus_showMenu(metadata.title, actions: [
            YUSAction(title: metadata.title, style: metadata.style) { [weak self] _ in
                guard let self else { return }
                bridge.performActionAndReportWorldChange(
                    metadata.action,
                    atX: indexPath.row,
                    y: indexPath.section
                )
                refreshWorld()
                revealSelectedUnit()
            },
            makeCancelAction(),
        ])
    }

    private func showOverlayMenu() {
        let settings: [(SIGOverlaySetting, String)] = [
            (.damage, String(localized: "Damage Bar", bundle: frameworkBundle)),
            (.shootRange, String(localized: "Shoot Range", bundle: frameworkBundle)),
            (.moveRange, String(localized: "Move Range", bundle: frameworkBundle)),
            (.visibilityRange, String(localized: "Visibility Range", bundle: frameworkBundle)),
        ]
        let enabled = String(localized: "On", bundle: frameworkBundle)
        let disabled = String(localized: "Off", bundle: frameworkBundle)
        let actions = settings.map { setting, label in
            let state = bridge.isOverlaySettingEnabled(setting) ? enabled : disabled
            return YUSAction(title: "\(label):    \(state)", style: .default) { [weak self] _ in
                guard let self else { return }
                bridge.toggleOverlaySetting(setting)
                switch setting {
                case .damage:
                    redrawSprites()
                case .shootRange, .moveRange, .visibilityRange:
                    redrawRanges()
                @unknown default:
                    break
                }
            }
        }
        showCancellableMenu(String(localized: "Overlay Settings", bundle: frameworkBundle), actions: actions)
    }

    private func showReserveMenu() {
        let titles = [
            String(localized: "1 Shot", bundle: frameworkBundle),
            String(localized: "2 Shots", bundle: frameworkBundle),
            String(localized: "3 Shots", bundle: frameworkBundle),
        ]
        let actions = titles.enumerated().map { index, title in
            let reserve = index + 1
            let selected = bridge.timeReserve == reserve ? " ✅" : ""
            return YUSAction(title: title + selected, style: .default) { [weak self] _ in
                guard let self else { return }
                bridge.setTimeReserve(reserve)
                if bridge.selectedUnitSelectionMayChangeWorld() {
                    refreshWorld()
                } else {
                    redrawRanges()
                }
            }
        }
        showCancellableMenu(String(localized: "Reserve Time Settings", bundle: frameworkBundle), actions: actions)
    }

    private func makeCancelAction() -> YUSAction {
        YUSAction(
            title: String(localized: "Cancel", bundle: frameworkBundle),
            style: .cancel,
            handler: nil
        )
    }

    private func redrawRanges() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        linesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        bridge.drawRanges(
            in: linesLayer,
            tileWidth: tileLayout.tileWidth,
            tileHeight: tileLayout.tileHeight
        )
        // Native range geometry contains fixed-point offsets, so scale the finished paths.
        var zoomTransform = CGAffineTransform(scaleX: tileLayout.zoom, y: tileLayout.zoom)
        linesLayer.sublayers?.forEach { layer in
            guard let shapeLayer = layer as? CAShapeLayer, let path = shapeLayer.path else { return }
            shapeLayer.path = path.copy(using: &zoomTransform)
        }
        CATransaction.commit()
    }

    private func redrawSprites() {
        redrawSprites(bridge.spriteSnapshots(
            withTileWidth: tileLayout.tileWidth,
            tileHeight: tileLayout.tileHeight
        ))
    }

    private func redrawSprites(_ snapshots: [SIGSpriteSnapshot]) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Reuse layers: most sprites are unchanged between refreshes, and late missions have thousands.
        // Retain native frames so repeated zooming never compounds rounding error or rescans the world.
        let zoomTransform = CGAffineTransform(scaleX: tileLayout.zoom, y: tileLayout.zoom)
        var index = 0
        func place(_ image: UIImage?, frame: CGRect) {
            guard let image = image?.cgImage else { return }
            placeSprite(image, frame: frame, at: index, zoomTransform: zoomTransform)
            index += 1
        }
        for snapshot in snapshots {
            place(snapshot.image, frame: snapshot.frame)
            place(snapshot.statusImage, frame: snapshot.statusFrame)
        }
        spriteLayers[index...].forEach { $0.layer.removeFromSuperlayer() }
        spriteLayers.removeSubrange(index...)
        spriteLayerZoom = tileLayout.zoom
        CATransaction.commit()
    }

    private func placeSprite(
        _ image: CGImage,
        frame: CGRect,
        at index: Int,
        zoomTransform: CGAffineTransform
    ) {
        guard index < spriteLayers.count else {
            let layer = CALayer()
            layer.contents = image
            layer.frame = frame.applying(zoomTransform)
            spritesLayer.addSublayer(layer)
            spriteLayers.append(SpriteLayer(layer: layer, image: image, unzoomedFrame: frame))
            return
        }
        if spriteLayers[index].image !== image {
            spriteLayers[index].layer.contents = image
            spriteLayers[index].image = image
        }
        if spriteLayers[index].unzoomedFrame != frame || spriteLayerZoom != tileLayout.zoom {
            spriteLayers[index].layer.frame = frame.applying(zoomTransform)
            spriteLayers[index].unzoomedFrame = frame
        }
    }

    private func scaleSpriteLayersToCurrentZoom() {
        let zoom = tileLayout.zoom
        guard spriteLayerZoom != zoom else { return }
        let transform = CGAffineTransform(scaleX: zoom, y: zoom)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spriteLayers.forEach { item in
            item.layer.frame = item.unzoomedFrame.applying(transform)
        }
        spriteLayerZoom = zoom
        CATransaction.commit()
    }

    private func reloadUnitInfo() {
        unitInfoLabel.text = bridge.selectedUnitInfo
        layoutUnitInfo()
    }

    private func layoutUnitInfo() {
        guard unitInfoLabel.text != nil else {
            unitInfoLabel.frame = .zero
            return
        }
        unitInfoLabel.frame = maximumUnitInfoFrame
        unitInfoLabel.sizeToFit()
    }

    private func refreshWorld() {
        guard let snapshot = bridge.worldSnapshot(
            withTileWidth: tileLayout.tileWidth,
            tileHeight: tileLayout.tileHeight,
            miniMapGridSize: miniImageGrid
        ) else { return }
        mapView.configAllItems()
        miniMapView.update(with: snapshot.miniMapImage)
        updateMiniMapViewport()
        redrawSprites(snapshot.sprites)
        redrawRanges()
        reloadUnitInfo()
        updateContextControls()
        updateStatus()
    }

    private func updateStatus() {
        // The engine belongs to the enemy turn's thread; keep the last values until it ends.
        guard !bridge.turnInProgress else { return }
        let credits = String(
            format: String(localized: "%i cr", bundle: frameworkBundle),
            Int32(clamping: bridge.credits)
        )
        creditsButton.setTitle(credits, for: .normal)
        creditsButton.accessibilityLabel = credits
        let turn = String(
            format: String(localized: "Turn %ld", bundle: frameworkBundle),
            bridge.turn
        )
        turnButton.setTitle(turn, for: .normal)
        turnButton.accessibilityLabel = turn
    }

    private func refreshSelection(from previousSelection: IndexPath?) {
        let selectionPaths = Set([previousSelection, bridge.selectedUnitIndexPath].compactMap { $0 })
        for indexPath in selectionPaths {
            guard let cell = mapView.cellForItem(at: indexPath) else { continue }
            configCell(cell, at: indexPath)
        }
        redrawRanges()
        reloadUnitInfo()
        updateContextControls()
        updateStatus()
    }

    private func selectNextUnit() {
        let previousSelection = bridge.selectedUnitIndexPath
        guard bridge.selectNextUnit() else { return }
        if bridge.selectedUnitSelectionMayChangeWorld() {
            refreshWorld()
        } else {
            refreshSelection(from: previousSelection)
        }
        revealSelectedUnit()
    }

    private func updateContextControls() {
        let availableActions: SIGUnitAction
        if let indexPath = bridge.selectedUnitIndexPath {
            availableActions = bridge.availableActions(
                atX: indexPath.row,
                y: indexPath.section
            )
        } else {
            availableActions = []
        }

        weaponView.isHidden = !availableActions.contains(.weapon)
        specialView.isHidden = !bridge.canRepairSelectedUnit && !Self.unitActionMetadata.contains {
            $0.isSpecial && availableActions.contains($0.action)
        }
    }

    private func centerSelectedUnit() {
        guard let indexPath = bridge.selectedUnitIndexPath else { return }
        mapView.scrollToItem(
            at: indexPath,
            at: [.centeredVertically, .centeredHorizontally],
            animated: true
        )
    }

    /// Centers the selection when its tile is off screen or under the HUD (outside the inset map area).
    private func revealSelectedUnit() {
        guard let indexPath = bridge.selectedUnitIndexPath,
              let tileFrame = tileLayout.layoutAttributesForItem(at: indexPath)?.frame else { return }
        let freeArea = mapView.bounds.inset(by: mapView.adjustedContentInset)
        guard !freeArea.contains(CGPoint(x: tileFrame.midX, y: tileFrame.midY)) else { return }
        centerSelectedUnit()
    }

    private func showSelectedUnit() {
        guard let unit = bridge.selectedUnit else {
            showMissionBriefing()
            return
        }
        yus_showTitle(message: unit.details, image: unit.image)
    }

    private func endTurn() {
        let lowFuelAircraft = bridge.lowFuelAircraftChoices()
        guard !lowFuelAircraft.isEmpty else {
            completeEndTurn()
            return
        }

        var actions = lowFuelAircraft.map { choice in
            YUSAction(title: choice.title, style: .default) { [weak self] _ in
                guard let self else { return }
                let previousSelection = bridge.selectedUnitIndexPath
                guard bridge.selectLowFuelAircraft(withIdentifier: choice.identifier) else { return }
                refreshSelection(from: previousSelection)
                revealSelectedUnit()
            }
        }
        actions.append(YUSAction(
            title: String(localized: "End Turn Anyway", bundle: frameworkBundle),
            style: .destructive
        ) { [weak self] _ in
            self?.completeEndTurn()
        })
        showCancellableMenu(
            String(localized: "Low fuel warning for aircrafts", bundle: frameworkBundle),
            actions: actions
        )
    }

    private func completeEndTurn() {
        // The low-fuel warning runs this later; the game may have been stopped meanwhile.
        guard engineStarted, !stopped, !bridge.turnInProgress else { return }
        setTurnInProgress(true)
        bridge.endTurn { [weak self] autosaved, messages in
            self?.finishEndTurn(autosaved: autosaved, messages: messages)
        }
    }

    private func finishEndTurn(autosaved: Bool, messages: [String]) {
        setTurnInProgress(false)
        refreshWorld()
        if bridge.terminationStatus != 0 {
            mapView.isUserInteractionEnabled = false
            unitOrdersView.isUserInteractionEnabled = false
            endTurnButton.isUserInteractionEnabled = false
            weaponView.isUserInteractionEnabled = false
            specialView.isUserInteractionEnabled = false
        }
        addNotifications(messages)
        guard autosaved else {
            yus_showTitle(
                message: String(localized: "Unable to save game.", bundle: frameworkBundle)
            )
            return
        }
        showTurnOutcome()
    }

    private func setTurnInProgress(_ inProgress: Bool) {
        // Input stays off while the worker thread owns the engine.
        view.isUserInteractionEnabled = !inProgress
        if inProgress {
            turnActivityIndicator.startAnimating()
            updateContextControls()
        } else {
            turnActivityIndicator.stopAnimating()
        }
    }

    private func showTurnOutcome() {
        let title: String
        var message: String?
        switch bridge.terminationStatus {
        case -1:
            music.play(.failure)
            title = String(localized: "Mission Failed", bundle: frameworkBundle)
        case 1:
            music.play(.success)
            title = String(localized: "Mission Completed", bundle: frameworkBundle)
            message = bridge.missionDebriefing()
        default:
            return
        }

        yus_showTitle(
            title,
            message: message,
            completion: { [weak self] in self?.quitGame() }
        )
    }
}
