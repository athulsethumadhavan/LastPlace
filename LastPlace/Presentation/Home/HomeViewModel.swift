//
//  HomeViewModel.swift
//  LastPlace
//
//  Loads the default home + rooms + recent + important items in parallel.
//  Owns nothing UI-specific — the view renders whichever `LoadableState` case
//  is current.
//

import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var state: LoadableState<HomeDashboardContent> = .idle

    private let fetchDefaultHome: FetchDefaultHomeUseCase
    private let fetchRooms: FetchRoomsUseCase
    private let fetchRecent: FetchRecentItemsUseCase
    private let fetchImportant: FetchImportantItemsUseCase
    private let configuration: AppConfiguration
    private let logger: AppLogger

    init(
        fetchDefaultHome: FetchDefaultHomeUseCase,
        fetchRooms: FetchRoomsUseCase,
        fetchRecent: FetchRecentItemsUseCase,
        fetchImportant: FetchImportantItemsUseCase,
        configuration: AppConfiguration,
        logger: AppLogger
    ) {
        self.fetchDefaultHome = fetchDefaultHome
        self.fetchRooms = fetchRooms
        self.fetchRecent = fetchRecent
        self.fetchImportant = fetchImportant
        self.configuration = configuration
        self.logger = logger
    }

    func load() async {
        if case .loading = state { return }
        state = .loading

        do {
            let home = try await fetchDefaultHome.execute()
            async let roomsTask = fetchRooms.execute(homeID: home.id)
            async let recentTask = fetchRecent.execute(limit: configuration.recentItemsLimit)
            async let importantTask = fetchImportant.execute()

            let (rooms, recent, important) = try await (roomsTask, recentTask, importantTask)

            let content = HomeDashboardContent(
                home: home,
                rooms: rooms,
                recentItems: recent,
                importantItems: important
            )
            state = .loaded(content)
        } catch {
            logger.error("Home dashboard load failed", error: error, category: "home")
            state = .failed(UserFacingError.from(error))
        }
    }

    func refresh() async {
        await load()
    }
}
