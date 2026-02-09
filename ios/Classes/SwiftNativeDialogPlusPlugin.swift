import Flutter
import UIKit

public class SwiftNativeDialogPlusPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "native_dialog_plus", binaryMessenger: registrar.messenger())
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
        result(FlutterError(code: "DIALOG_ERROR", message: exception!.reason, details: nil))
        return
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private var controller: UIViewController? {
    return UIApplication.shared.keyWindow?.rootViewController
  }

  private var okText: String {
    return NSLocalizedString("OK", comment: "OK")
  }

  private var cancelText: String {
    return NSLocalizedString("Cancel", comment: "Cancel")
  }

  private var unavailableError: FlutterError {
    return FlutterError(code: "UNAVAILABLE", message: "Native alert is unavailable", details: nil)
  }
  private var invalidStyleError: FlutterError {
    return FlutterError(
      code: "INVALID_STYLE", message: "Given index for style is invalid", details: nil)
  }

  private func indexToActionStyle(_ index: Int) -> UIAlertAction.Style? {
    switch index {
    case 0:
      return .default
    case 1:
      return .cancel
    case 2:
      return .destructive
    default:
      return nil
    }
  }

  private func indexToAlertStyle(_ index: Int) -> UIAlertController.Style? {
    switch index {
    case 0:
      return .actionSheet
    case 1:
      return .alert
    default:
      return nil
    }
  }

  private func showDialog(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as! NSDictionary
    let title = args.value(forKey: "title") as? String ?? nil
    let message = args.value(forKey: "message") as? String ?? nil
    let style = args.value(forKey: "style") as! Int

    var alertStyle = indexToAlertStyle(style)
    if alertStyle == nil {
      result(invalidStyleError)
      return
    }

    // Check if the device is an iPad and the style is .actionSheet
    // .actionSheet is not supported on iPadOS since 13.2
    if UIDevice.current.userInterfaceIdiom == .pad && alertStyle == .actionSheet {
      alertStyle = .alert
    }

    let alert = UIAlertController(title: title, message: message, preferredStyle: alertStyle!)
    
    // Set fixed font sizes for title and message
    if let title = title {
      let titleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
      let attributedTitle = NSAttributedString(
        string: title,
        attributes: [NSAttributedString.Key.font: titleFont]
      )
      alert.setValue(attributedTitle, forKey: "attributedTitle")
    }
    
    if let message = message {
      let messageFont = UIFont.systemFont(ofSize: 13, weight: .regular)
      let attributedMessage = NSAttributedString(
        string: message,
        attributes: [NSAttributedString.Key.font: messageFont]
      )
      alert.setValue(attributedMessage, forKey: "attributedMessage")
    }

    let actions = args.value(forKey: "actions") as! [NSDictionary]

    for (index, action) in actions.enumerated() {
      let title = action.value(forKey: "text") as! String
      let enabled = action.value(forKey: "enabled") as! Bool

      var actionStyle = indexToActionStyle(action.value(forKey: "style") as! Int)
      if actionStyle == nil {
        result(invalidStyleError)
        return
      }

      let alertAction = UIAlertAction(
        title: title, style: actionStyle!,
        handler: { _ in
          result(index)
        })
      alertAction.isEnabled = enabled
      alert.addAction(alertAction)
    }

    guard let controller = controller else {
      result(unavailableError)
      return
    }
    
    controller.present(alert, animated: true) {
      // After presentation, traverse the view hierarchy and fix button fonts
      self.fixAlertActionFonts(in: alert.view)
    }
  }
  
  // Recursively traverse view hierarchy to find and fix button/label fonts
  private func fixAlertActionFonts(in view: UIView) {
    // Fix labels (action button titles)
    if let label = view as? UILabel {
      let currentSize = label.font.pointSize
      label.font = UIFont.systemFont(ofSize: currentSize, weight: label.font.weight)
      label.adjustsFontForContentSizeCategory = false
    }
    
    // Recursively check subviews
    for subview in view.subviews {
      fixAlertActionFonts(in: subview)
    }
  }
}

// Extension to get font weight
extension UIFont {
  var weight: Weight {
    guard let weightNumber = traits[.weight] as? NSNumber else { return .regular }
    let weightRawValue = CGFloat(weightNumber.doubleValue)
    let weight = Weight(rawValue: weightRawValue)
    return weight
  }
  
  private var traits: [UIFontDescriptor.TraitKey: Any] {
    return fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any] ?? [:]
  }
}