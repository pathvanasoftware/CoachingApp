import Foundation

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var relativeDisplay: String {
        if isToday { return "Today" }
        if isYesterday { return "Yesterday" }
        let formatter = DateFormatter()
        if isThisWeek {
            formatter.dateFormat = "EEEE"
        } else {
            formatter.dateStyle = .medium
        }
        return formatter.string(from: self)
    }

    var timeDisplay: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var shortDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: self)
    }

    func daysFrom(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var startOfWeek: Date {
        let components = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return Calendar.current.date(from: components) ?? self
    }
}
