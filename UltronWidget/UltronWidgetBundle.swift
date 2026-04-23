import WidgetKit
import SwiftUI

@main
struct UltronWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        if #available(iOS 18.0, *) {
            StatusControlWidget()
        }
    }
}
