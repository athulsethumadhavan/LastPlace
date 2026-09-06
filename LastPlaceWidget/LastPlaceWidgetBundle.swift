//
//  LastPlaceWidgetBundle.swift
//  LastPlaceWidget
//
//  Created by AthulAppStation on 16/07/26.
//

import WidgetKit
import SwiftUI

@main
struct LastPlaceWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentItemsWidget()
        ChecklistProgressWidget()
        SummaryWidget()
    }
}
