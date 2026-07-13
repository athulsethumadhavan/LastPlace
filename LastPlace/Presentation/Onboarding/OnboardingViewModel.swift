//
//  OnboardingViewModel.swift
//  LastPlace
//

import Foundation
import Observation

@Observable
@MainActor
final class OnboardingViewModel {
    let pages: [OnboardingPage]
    var currentIndex: Int

    private let onFinished: @MainActor () -> Void

    init(
        pages: [OnboardingPage] = OnboardingPage.defaultPages,
        currentIndex: Int = 0,
        onFinished: @escaping @MainActor () -> Void
    ) {
        self.pages = pages
        self.currentIndex = currentIndex
        self.onFinished = onFinished
    }

    var currentPage: OnboardingPage { pages[currentIndex] }
    var isLastPage: Bool { currentIndex >= pages.count - 1 }
    var primaryButtonTitle: String { isLastPage ? "Get Started" : "Continue" }

    func advance() {
        if isLastPage {
            onFinished()
        } else {
            currentIndex += 1
        }
    }

    func skip() {
        onFinished()
    }
}
