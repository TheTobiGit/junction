import Foundation

final class LastURLStore {
    static let shared = LastURLStore()

    private(set) var lastRoutedURL: URL?
    private(set) var lastPickerURL: URL?

    private init() {}

    func recordRouted(_ url: URL) {
        lastRoutedURL = url
    }

    func recordPicker(_ url: URL) {
        lastPickerURL = url
    }

    var mostRecent: URL? {
        lastRoutedURL ?? lastPickerURL
    }
}
