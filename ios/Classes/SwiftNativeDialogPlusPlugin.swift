import Flutter
import UIKit

public class SwiftNativeDialogPlusPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "native_dialog_plus",
      binaryMessenger: registrar.messenger()
    )

    let instance = SwiftNativeDialogPlusPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

    switch call.method {
    case "showDialog":
      let exception = tryBlock {
        self.showDialog(call, result)
      }

      if exception != nil {
        result(
          FlutterError(
            code: "DIALOG_ERROR",
            message: exception!.reason,
            details: nil
          )
        )
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Helpers

  private var controller: UIViewController? {
    return UIApplication.shared.windows.first?.rootViewController
  }

  private var unavailableError: FlutterError {
    return FlutterError(
      code: "UNAVAILABLE",
      message: "Native alert is unavailable",
      details: nil
    )
  }

  private var invalidStyleError: FlutterError {
    return FlutterError(
      code: "INVALID_STYLE",
      message: "Given index for style is invalid",
      details: nil
    )
  }

  private func indexToActionStyle(_ index: Int) -> UIAlertAction.Style? {
    switch index {
    case 0: return .default
    case 1: return .cancel
    case 2: return .destructive
    default: return nil
    }
  }

  private func indexToAlertStyle(_ index: Int) -> UIAlertController.Style? {
    switch index {
    case 0: return .actionSheet
    case 1: return .alert
    default: return nil
    }
  }

  // MARK: - Main

  private func showDialog(
    _ call: FlutterMethodCall,
    _ result: @escaping FlutterResult
  ) {

    let args = call.arguments as! NSDictionary

    let title = args["title"] as? String
    let message = args["message"] as? String
    let style = args["style"] as! Int

    guard var alertStyle = indexToAlertStyle(style) else {
      result(invalidStyleError)
      return
    }

    // iPad fix
    if UIDevice.current.userInterfaceIdiom == .pad,
       alertStyle == .actionSheet {
      alertStyle = .alert
    }

    let alert = UIAlertController(
      title: nil,
      message: nil,
      preferredStyle: alertStyle
    )

    // -------------------------------
    // ✅ FIXED TITLE FONT
    // -------------------------------

    if let title = title {

      let titleAttr = NSAttributedString(
        string: title,
        attributes: [
          .font: UIFont.systemFont(
            ofSize: 17,
            weight: .semibold
          )
        ]
      )

      alert.setValue(titleAttr, forKey: "attributedTitle")
    }

    // -------------------------------
    // ✅ FIXED MESSAGE FONT
    // -------------------------------

    if let message = message {

      let messageAttr = NSAttributedString(
        string: message,
        attributes: [
          .font: UIFont.systemFont(
            ofSize: 14,
            weight: .regular
          )
        ]
      )

      alert.setValue(messageAttr, forKey: "attributedMessage")
    }

    // -------------------------------
    // ACTIONS
    // -------------------------------

    let actions = args["actions"] as! [NSDictionary]

    for (index, action) in actions.enumerated() {

      let text = action["text"] as! String
      let enabled = action["enabled"] as! Bool

      guard let actionStyle =
              indexToActionStyle(action["style"] as! Int)
      else {
        result(invalidStyleError)
        return
      }

      let alertAction = UIAlertAction(
        title: text,
        style: actionStyle
      ) { _ in
        result(index)
      }

      alertAction.isEnabled = enabled

      // -------------------------------
      // ✅ FIX BUTTON FONT
      // -------------------------------

      let font = UIFont.systemFont(
        ofSize: 16,
        weight: .medium
      )

      let attrText = NSAttributedString(
        string: text,
        attributes: [
          .font: font
        ]
      )

      alertAction.setValue(
        attrText,
        forKey: "attributedTitle"
      )

      alert.addAction(alertAction)
    }

    // -------------------------------
    // PRESENT
    // -------------------------------

    guard let controller = controller else {
      result(unavailableError)
      return
    }

    controller.present(alert, animated: true)
  }
}
