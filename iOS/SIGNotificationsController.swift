//
//  SIGNotificationsController.swift
//  SIG
//
//

import UIKit
import YUSKit

final class SIGNotificationsController: YUSListController {
    private let notifications: [String]

    init(notifications: [String]) {
        self.notifications = notifications
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SIGNotificationsController does not support storyboard initialization")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = String(localized: "Notifications", bundle: frameworkBundle)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        setupSections([notifications.reversed().map { YUSListItem(label: $0) }])
    }
}
