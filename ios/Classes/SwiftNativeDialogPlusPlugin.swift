import Flutter
import UIKit

// =======================================================
// MARK: - Flutter Plugin
// =======================================================

public class SwiftNativeDialogPlusPlugin: NSObject, FlutterPlugin {

    // Register
    public static func register(with registrar: FlutterPluginRegistrar) {

        let channel = FlutterMethodChannel(
            name: "native_dialog_plus",
            binaryMessenger: registrar.messenger()
        )

        let instance = SwiftNativeDialogPlusPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // Handle calls
    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {

        if call.method == "showDialog" {
            showDialog(call, result)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    // Root controller
    private var rootController: UIViewController? {

        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first { $0.isKeyWindow }?
            .rootViewController
    }

    // Show dialog
    private func showDialog(
        _ call: FlutterMethodCall,
        _ result: @escaping FlutterResult
    ) {

        guard let args = call.arguments as? NSDictionary else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Invalid arguments",
                details: nil
            ))
            return
        }

        let title = args["title"] as? String ?? ""
        let message = args["message"] as? String ?? ""
        let actions = args["actions"] as? [NSDictionary] ?? []

        guard let controller = rootController else {
            result(FlutterError(
                code: "NO_CONTROLLER",
                message: "No root controller",
                details: nil
            ))
            return
        }

        let dialog = CustomDialogVC(
            titleText: title,
            messageText: message,
            actions: actions
        ) { index in
            result(index)
        }

        dialog.modalPresentationStyle = .overFullScreen
        dialog.modalTransitionStyle = .crossDissolve

        controller.present(dialog, animated: true)
    }
}

// =======================================================
// MARK: - Custom Dialog Controller
// =======================================================

fileprivate class CustomDialogVC: UIViewController {

    // Data
    private let titleText: String
    private let messageText: String
    private let actions: [NSDictionary]
    private let callback: (Int) -> Void

    // UI
    private let dimView = UIView()
    private let container = UIView()

    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let buttonsStack = UIStackView()

    // Init
    init(
        titleText: String,
        messageText: String,
        actions: [NSDictionary],
        callback: @escaping (Int) -> Void
    ) {

        self.titleText = titleText
        self.messageText = messageText
        self.actions = actions
        self.callback = callback

        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        setupBackground()
        setupContainer()
        setupLabels()
        setupButtons()
        layoutUI()
        animateIn()
    }

    // ===================================================
    // MARK: Setup UI
    // ===================================================

    private func setupBackground() {

        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dimView.alpha = 0

        view.addSubview(dimView)

        dimView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupContainer() {

        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 16
        container.clipsToBounds = true

        view.addSubview(container)

        container.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 300),
        ])
    }

    private func setupLabels() {

        // Title
        titleLabel.text = titleText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        // Disable scaling
        titleLabel.adjustsFontForContentSizeCategory = false
        titleLabel.preferredFontForTextStyle = nil


        // Message
        messageLabel.text = messageText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 4

        messageLabel.font = .systemFont(ofSize: 14)

        // Disable scaling
        messageLabel.adjustsFontForContentSizeCategory = false
        messageLabel.preferredFontForTextStyle = nil
    }

    private func setupButtons() {

        buttonsStack.axis = .vertical
        buttonsStack.spacing = 1
        buttonsStack.distribution = .fillEqually

        buttonsStack.backgroundColor = .separator

        for (index, item) in actions.enumerated() {

            let title = item["text"] as? String ?? "OK"
            let enabled = item["enabled"] as? Bool ?? true
            let style = item["style"] as? Int ?? 0

            let button = UIButton(type: .system)

            // Disable iOS15+ auto config
            if #available(iOS 15.0, *) {
                button.configuration = nil
            }

            button.tag = index
            button.isEnabled = enabled

            button.setTitle(title, for: .normal)

            // Fixed font
            let fixedFont = UIFont.systemFont(ofSize: 16)

            if let label = button.titleLabel {

                label.font = fixedFont

                // FULLY disable scaling
                label.adjustsFontForContentSizeCategory = false
                label.preferredFontForTextStyle = nil
                label.adjustsFontSizeToFitWidth = false
                label.minimumScaleFactor = 1.0

                label.setContentHuggingPriority(.required, for: .vertical)
                label.setContentCompressionResistancePriority(.required, for: .vertical)
            }

            // Color
            switch style {
            case 2:
                button.setTitleColor(.systemRed, for: .normal)
            default:
                button.setTitleColor(.systemBlue, for: .normal)
            }

            button.backgroundColor = .systemBackground

            // Fixed height
            button.heightAnchor
                .constraint(equalToConstant: 48)
                .isActive = true

            button.addTarget(
                self,
                action: #selector(buttonTapped(_:)),
                for: .touchUpInside
            )

            buttonsStack.addArrangedSubview(button)
        }
    }

    private func layoutUI() {

        let contentStack = UIStackView()

        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.alignment = .fill

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(messageLabel)

        container.addSubview(contentStack)
        container.addSubview(buttonsStack)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([

            // Content
            contentStack.topAnchor.constraint(
                equalTo: container.topAnchor,
                constant: 20
            ),

            contentStack.leadingAnchor.constraint(
                equalTo: container.leadingAnchor,
                constant: 16
            ),

            contentStack.trailingAnchor.constraint(
                equalTo: container.trailingAnchor,
                constant: -16
            ),

            // Buttons
            buttonsStack.topAnchor.constraint(
                equalTo: contentStack.bottomAnchor,
                constant: 20
            ),

            buttonsStack.leadingAnchor.constraint(
                equalTo: container.leadingAnchor
            ),

            buttonsStack.trailingAnchor.constraint(
                equalTo: container.trailingAnchor
            ),

            buttonsStack.bottomAnchor.constraint(
                equalTo: container.bottomAnchor
            ),
        ])
    }

    // ===================================================
    // MARK: Actions
    // ===================================================

    @objc private func buttonTapped(_ sender: UIButton) {

        dismiss(animated: true) {
            self.callback(sender.tag)
        }
    }

    // ===================================================
    // MARK: Animation
    // ===================================================

    private func animateIn() {

        dimView.alpha = 0
        container.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)

        UIView.animate(withDuration: 0.25) {

            self.dimView.alpha = 1
            self.container.transform = .identity
        }
    }
}
