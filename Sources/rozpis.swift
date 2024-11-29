// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ArgumentParser
import CodableCSV
import ICalendarKit

@main
struct RozpisHokej: ParsableCommand {

    mutating func run() throws {
        let semaphore = DispatchSemaphore(value: 0)
        let url = URL(
            string: "https://zapasy.ceskyhokej.cz/admin/schedule/dashboard/export?filter%5Bseason%5D=2024&filter%5BmanagingAuthorities%5D=7&filter%5Bregion%5D=all&filter%5Bteam%5D=1534&filter%5BtimeShortcut%5D=&filter%5Bleague%5D=league_118&filter%5Bnumber%5D=&filter%5Bstadium%5D=all&filter%5Bstate%5D=&filter%5BteamType%5D=all&filter%5Bsort%5D=&filter%5Bdirection%5D=ASC"
        )!
        let request = URLRequest(url: url)
        URLSession.shared.downloadTask(with: request) { url, _, _ in
            defer {
                semaphore.signal()
            }
            guard
                let url,
                let csvData = try? Data(contentsOf: url),
                let windowsString = String(data: csvData, encoding: .windowsCP1250),
                let utfData = windowsString.data(using: .utf8)
            else {
                return
            }

            let decoder = CSVDecoder {
                $0.headerStrategy = .firstLine
                $0.encoding = .utf8
                $0.delimiters.field = ";"
            }
            do {
                let events = try decoder.decode([Event].self, from: utfData)
                var cal = ICalendar()
                cal.events = events.filter { !["Nehraje se"].contains($0.state) }.flatMap { event in
                    var items = [ICalendarEvent]()
                    if !event.isAllDay {
                        items.append(
                            ICalendarEvent(
                                dtstart: .dateTime(event.startDate.addingTimeInterval(-1 * 60 * 60)),
                                location: event.stadion.label,
                                summary: "Sraz hodinu před zápasem + rozcvička",
                                duration: .hours(1),
                                xAppleTravelDuration: event.stadion.travelDuration
                            )
                        )
                    }
                    items.append(
                        ICalendarEvent(
                            dtstart: event.isAllDay ? .dateOnly(event.startDate) : .dateTime(event.startDate),
                            location: event.stadion.label,
                            summary: "\(event.home) - \(event.away)",
                            dtend: event.isAllDay ? .dateOnly(event.endDate) : .dateTime(event.endDate)
                        )
                    )
                    return items
                }
                print(cal.vEncoded)
            } catch {}
        }.resume()
        semaphore.wait()
    }

}

struct Event: Decodable {

    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let stadion: Stadion
    let home: String
    let away: String
    let state: String

    enum CodingKeys: Int, CodingKey {
        case den = 0
        case datum = 1
        case zacatek = 2
        case zimniStadion = 3
        case soutez = 4
        case cisloUtkani = 5
        case domaci = 6
        case hoste = 7
        case stav = 8
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        home = try container.decode(String.self, forKey: .domaci)
        away = try container.decode(String.self, forKey: .hoste)
        stadion = try container.decode(Stadion.self, forKey: .zimniStadion)
        state = try container.decode(String.self, forKey: .stav)

        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.timeZone = TimeZone(identifier: "Europe/Prague")
        dateTimeFormatter.dateFormat = "dd.MM.yyyy HH:mm"

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.dateFormat = "dd.MM.yyyy"

        let dateString = try container.decode(String.self, forKey: .datum)
        let timeString = try container.decode(String.self, forKey: .zacatek)

        if dateString.contains(" - ") {
            isAllDay = true
            let parts = dateString.split(separator: "-", maxSplits: 2, omittingEmptySubsequences: true)
            guard let startDate = dateFormatter.date(from: String(parts[0])) else {
                throw DecodingError.dataCorruptedError(forKey: .datum, in: container, debugDescription: "Invalid date \(dateString)")
            }
            guard let endDate = dateFormatter.date(from: String(parts[1])) else {
                throw DecodingError.dataCorruptedError(forKey: .datum, in: container, debugDescription: "Invalid date \(dateString)")
            }
            self.startDate = startDate
            self.endDate = endDate.addingTimeInterval(24 * 60 * 60)
        } else if timeString.contains(" - ") {
            isAllDay = true
            guard let startDate = dateFormatter.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(forKey: .datum, in: container, debugDescription: "Invalid date \(dateString)")
            }
            self.startDate = startDate
            self.endDate = startDate
        } else {
            guard let startDate = dateTimeFormatter.date(from: "\(dateString) \(timeString)") else {
                throw DecodingError.dataCorruptedError(forKey: .datum, in: container, debugDescription: "Invalid date \(dateString) and time \(timeString)")
            }
            isAllDay = false
            self.startDate = startDate
            self.endDate = startDate.addingTimeInterval(2 * 60 * 60)
        }
    }

}

enum Stadion: String, Decodable {
    case beroun = "BE"
    case kladno = "KD"
    case pribram = "PB"
    case horovice = "HC"
    case kralupy = "KR"
    case cernosice = "CE"
    case kobraPraha = "K"
    case rakovnik = "RA"
    case spmArenaPraha = "RD"
    case slany = "SL"
    case hvezdaPraha = "H"
    case benesov = "BN"
    case sedlcany = "SD"
    case spartaPraha = "S"

    var label: String {
        switch self {
        case .beroun: return "Beroun, Zimní stadion"
        case .kladno: return "Kladno, ČEZ STADION Kladno"
        case .pribram: return "Příbram, Zimní stadion"
        case .horovice: return "Hořovice, Zimní stadion"
        case .kralupy: return "Kralupy nad Vltavou, Městský zimní stadion"
        case .cernosice: return "Černošice, Zimní stadion"
        case .kobraPraha: return "Praha - Kobra, Zimní stadion HC Kobra Praha"
        case .rakovnik: return "Rakovník, Zimní stadion města Rakovníka"
        case .spmArenaPraha: return "Praha, SPM ARENA"
        case .slany: return "VSH Slaný, Zimní stadion"
        case .hvezdaPraha: return "Praha - Hvězda, Zimní stadion HC Hvězda Praha"
        case .benesov: return "Benešov, Zimní stadion"
        case .sedlcany: return "Sedlčany, Zimní stadion"
        case .spartaPraha: return "Praha - Holešovice, Sportovní hala Fortuna"
        }
    }

    var travelDuration: ICalendarDuration {
        switch self {
        case .beroun: return .minutes(15)
        case .kladno: return .minutes(45)
        case .pribram: return .minutes(60)
        case .horovice: return .minutes(30)
        case .kralupy: return .minutes(75)
        case .cernosice: return .minutes(40)
        case .kobraPraha: return .minutes(60)
        case .rakovnik: return .minutes(45)
        case .spmArenaPraha: return .minutes(45)
        case .slany: return .minutes(60)
        case .hvezdaPraha: return .minutes(45)
        case .benesov: return .minutes(90)
        case .sedlcany: return .minutes(75)
        case .spartaPraha: return .minutes(60)
        }
    }
}
