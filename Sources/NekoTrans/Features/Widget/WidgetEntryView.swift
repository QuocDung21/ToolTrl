//
//  WidgetEntryView.swift
//  NekoTrans
//
//  Created by Dũng Nguyễn Quốc on 29/9/26.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let text: String

    static var placeholder: SimpleEntry {
        SimpleEntry(date: .now, text: "NekoTrans - Tra từ nhanh")
    }
}



// MARK: - Widget Entry View
struct WidgetEntryView: View {
    var entry: SimpleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.text)
                .font(.headline)
                .lineLimit(2)

            Text(entry.date, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Previews

#Preview("Medium Preview") {
    WidgetEntryView(entry: .placeholder)
        .frame(width: 329, height: 155)
}
