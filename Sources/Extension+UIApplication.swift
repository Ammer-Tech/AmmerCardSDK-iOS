import UIKit

extension UIApplication {

    class func topViewController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(base: selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }

    class func topNavigationController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UINavigationController? {
        if let nav = base as? UINavigationController {
            return nav
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topNavigationController(base: selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topNavigationController(base: presented)
        }
        return nil
    }
}
