import Foundation

enum TransitCalendar {
    private struct Window {
        let start: Date
        let end: Date
        let label: String
    }

    static func current(on date: Date = Date()) -> TransitEvent? {
        windows.first { date >= $0.start && date <= $0.end }.map { TransitEvent(label: $0.label) }
    }

    private static let windows: [Window] = {
        let iso = DateFormatter()
        iso.calendar = Calendar(identifier: .gregorian)
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.timeZone = TimeZone(identifier: "Asia/Kolkata")
        iso.dateFormat = "yyyy-MM-dd"
        func d(_ s: String) -> Date { iso.date(from: s)! }
        return [
            Window(start: d("2026-10-22"), end: d("2026-11-18"), label: "VENUS RX"),
            Window(start: d("2026-11-08"), end: d("2026-11-29"), label: "MERCURY RX"),
            Window(start: d("2026-11-04"), end: d("2026-11-08"), label: "SATURN SQUARE VENUS"),
            Window(start: d("2027-02-10"), end: d("2027-04-20"), label: "MARS RX"),
            Window(start: d("2027-02-05"), end: d("2027-08-10"), label: "URANUS SQUARE MOON"),
            Window(start: d("2027-03-12"), end: d("2027-03-18"), label: "SATURN SQUARE SUN"),
            Window(start: d("2027-07-12"), end: d("2027-07-18"), label: "SATURN SQUARE ASC"),
            Window(start: d("2027-08-02"), end: d("2027-12-31"), label: "JUPITER IN VIRGO"),
            Window(start: d("2027-08-02"), end: d("2027-08-20"), label: "URANUS CONJUNCT SATURN"),
            Window(start: d("2027-10-08"), end: d("2027-10-22"), label: "JUPITER TRINE VENUS"),
            Window(start: d("2027-10-20"), end: d("2027-10-28"), label: "SATURN SQUARE ASC"),
            Window(start: d("2027-11-08"), end: d("2027-11-22"), label: "URANUS CONJUNCT SATURN"),
        ]
    }()
}
