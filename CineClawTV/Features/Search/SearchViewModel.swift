import Foundation
import SwiftUI
import os

@Observable
@MainActor
final class SearchViewModel {
    private let logger = Logger(subsystem: "com.cineclaw.tvos", category: "SearchVM")

    var query: String = "" {
        didSet {
            scheduleSearch()
        }
    }

    var isSearching: Bool = false
    var results: [SearchResultItem] = []
    var popularChips: [String] = ["Дюна", "Сёгун", "4K UHD", "Пингвин", "Медведь", "Мэйдэй"]

    private var searchTask: Task<Void, Never>?

    func setChipQuery(_ chip: String) {
        self.query = chip
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            results = []
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            self.isSearching = true
            do {
                let items = try await CineClawClient.shared.search(query: q)
                guard !Task.isCancelled else { return }
                self.results = items
                self.isSearching = false
            } catch {
                self.logger.error("Search failed: \(error.localizedDescription)")
                self.isSearching = false
            }
        }
    }
}
