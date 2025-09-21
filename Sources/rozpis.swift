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
struct RozpisHokej: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generátor hokejových kalendářů z českého hokeje",
        discussion: "Stáhne rozpis pro všechny konfigurované týmy a vytvoří iCal kalendáře"
    )

    // Konfigurace týmů - klíč je název výstupního souboru, hodnota je URL
    private let teamsConfig: [String: String] = [
        "mladsi-zaci": "https://zapasy.ceskyhokej.cz/admin/schedule/dashboard/export?filter%5Bseason%5D=2025&filter%5BmanagingAuthorities%5D=all&filter%5Bregion%5D=all&filter%5Bteam%5D=1534&filter%5BtimeShortcut%5D=&filter%5Bleague%5D=league_118&filter%5Bnumber%5D=&filter%5Bstadium%5D=all&filter%5Bstate%5D=&filter%5BteamType%5D=all&filter%5Bsort%5D=&filter%5Bdirection%5D=ASC",
        "starsi-zaci": "https://zapasy.ceskyhokej.cz/admin/schedule/dashboard/export?filter%5Bseason%5D=2025&filter%5BdateRange%5D=&filter%5BmanagingAuthorities%5D=all&filter%5Bregion%5D=all&filter%5Bteam%5D=1534&filter%5BtimeShortcut%5D=&filter%5Bleague%5D=league_116&filter%5Bnumber%5D=&filter%5Bstadium%5D=all&filter%5Bstate%5D=&filter%5BteamType%5D=all&filter%5Bsort%5D=&filter%5Bdirection%5D=ASC",
        "muzi": "https://zapasy.ceskyhokej.cz/admin/schedule/dashboard/export?filter%5Bseason%5D=2025&filter%5BdateRange%5D=&filter%5BmanagingAuthorities%5D=all&filter%5Bregion%5D=all&filter%5Bteam%5D=1534&filter%5BtimeShortcut%5D=&filter%5Bleague%5D=league_84&filter%5Bnumber%5D=&filter%5Bstadium%5D=all&filter%5Bstate%5D=&filter%5BteamType%5D=all&filter%5Bsort%5D=&filter%5Bdirection%5D=ASC",
        "2-trida": "https://zapasy.ceskyhokej.cz/admin/schedule/dashboard/export?filter%5Bseason%5D=2025&filter%5BdateRange%5D=&filter%5BmanagingAuthorities%5D=all&filter%5Bregion%5D=all&filter%5Bteam%5D=1534&filter%5BtimeShortcut%5D=&filter%5Bleague%5D=league_143&filter%5Bnumber%5D=&filter%5Bstadium%5D=all&filter%5Bstate%5D=&filter%5BteamType%5D=all&filter%5Bsort%5D=&filter%5Bdirection%5D=ASC",
        "3-trida": "https://zapasy.ceskyhokej.cz/admin/schedule/dashboard/export?filter%5Bseason%5D=2025&filter%5BdateRange%5D=&filter%5BmanagingAuthorities%5D=all&filter%5Bregion%5D=all&filter%5Bteam%5D=1534&filter%5BtimeShortcut%5D=&filter%5Bleague%5D=league_144&filter%5Bnumber%5D=&filter%5Bstadium%5D=all&filter%5Bstate%5D=&filter%5BteamType%5D=all&filter%5Bsort%5D=&filter%5Bdirection%5D=ASC",
        "4-trida": "https://zapasy.ceskyhokej.cz/admin/schedule/dashboard/export?filter%5Bseason%5D=2025&filter%5BdateRange%5D=&filter%5BmanagingAuthorities%5D=all&filter%5Bregion%5D=all&filter%5Bteam%5D=1534&filter%5BtimeShortcut%5D=&filter%5Bleague%5D=league_145&filter%5Bnumber%5D=&filter%5Bstadium%5D=all&filter%5Bstate%5D=&filter%5BteamType%5D=all&filter%5Bsort%5D=&filter%5Bdirection%5D=ASC",
        "juniori": "https://zapasy.ceskyhokej.cz/admin/schedule/dashboard/export?filter%5Bseason%5D=2025&filter%5BdateRange%5D=&filter%5BmanagingAuthorities%5D=all&filter%5Bregion%5D=all&filter%5Bteam%5D=1534&filter%5BtimeShortcut%5D=&filter%5Bleague%5D=league_195&filter%5Bnumber%5D=&filter%5Bstadium%5D=all&filter%5Bstate%5D=&filter%5BteamType%5D=all&filter%5Bsort%5D=&filter%5Bdirection%5D=ASC",
        "dorost": "https://zapasy.ceskyhokej.cz/admin/schedule/dashboard/export?filter%5Bseason%5D=2025&filter%5BdateRange%5D=&filter%5BmanagingAuthorities%5D=all&filter%5Bregion%5D=all&filter%5Bteam%5D=1534&filter%5BtimeShortcut%5D=&filter%5Bleague%5D=league_197&filter%5Bnumber%5D=&filter%5Bstadium%5D=all&filter%5Bstate%5D=&filter%5BteamType%5D=all&filter%5Bsort%5D=&filter%5Bdirection%5D=ASC"
    ]

    enum CodingKeys: CodingKey {}

    mutating func run() async throws {
        print("Generuji kalendáře pro \(teamsConfig.count) týmů...")

        for (filename, url) in teamsConfig {
            print("Generuji kalendář: \(filename).ics")
            do {
                try await generateCalendar(url: url, outputFile: filename)
                print("✓ Úspěšně vygenerován: \(filename).ics")
            } catch {
                print("✗ Chyba při generování \(filename).ics: \(error)")
            }
        }

        print("Dokončeno. Vygenerováno \(teamsConfig.count) kalendářů.")
    }

    private func generateCalendar(url: String, outputFile: String) async throws {
        guard let requestUrl = URL(string: url) else {
            throw ValidationError("Neplatné URL: \(url)")
        }

        let request = URLRequest(url: requestUrl)
        let (responseUrl, _) = try await URLSession.shared.download(for: request)

        guard
            let csvData = try? Data(contentsOf: responseUrl),
            let windowsString = String(data: csvData, encoding: .windowsCP1250),
            let utfData = windowsString.data(using: .utf8)
        else {
            throw ValidationError("Nepodařilo se načíst nebo konvertovat CSV data z URL: \(url)")
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

                // Přidat sraz hodinu před zápasem (jen pokud není celodenní)
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

                // Přidat samotný zápas
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

            // Zapsat výstup do souboru nebo na stdout
            let calendarData = cal.vEncoded
            if let outputDirectory = ProcessInfo.processInfo.environment["OUTPUT_DIR"] {
                let outputPath = "\(outputDirectory)/\(outputFile).ics"
                let outputUrl = URL(fileURLWithPath: outputPath)
                try calendarData.write(to: outputUrl, atomically: true, encoding: .utf8)
            }
        } catch {
            throw ValidationError("Nepodařilo se parsovat CSV data: \(error)")
        }
    }
}

// Zbytek kódu zůstává stejný (struct Event a enum Stadion)
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
            
            guard let startDate = dateFormatter.date(from: String(parts[0]).trimmingCharacters(in: .whitespaces)) else {
                throw DecodingError.dataCorruptedError(forKey: .datum, in: container, debugDescription: "Invalid date \(dateString)")
            }
            
            guard let endDate = dateFormatter.date(from: String(parts[1]).trimmingCharacters(in: .whitespaces)) else {
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
    case kladno = "KL"
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
    case vystavistePraha = "V"
    case ricany = "RY"
    case melnik = "ME"
    case nymburk = "NB"
    case velkePopovice = "VP"
    case neratovice = "NE"
    case tremosna = "TM"
    case sobeslav = "SB"
    case klatovy = "KT"
    case domazlice = "DO"
    case jindrichuvHradec = "JH"
    case plzenKosutka = "PK"
    case humpolec = "HU"
    case rokycany = "RO"
    case milevsko = "MI"
    case vlasim = "VM"
    case kutnaHora = "KH"
    case benatkyNadJizerou = "BJ"
    case caslav = "ČA"

    var label: String {
        switch self {
        case .beroun: "Beroun, Zimní stadion"
        case .kladno: "Kladno, ČEZ STADION Kladno"
        case .pribram: "Příbram, Zimní stadion"
        case .horovice: "Hořovice, Zimní stadion"
        case .kralupy: "Kralupy nad Vltavou, Městský zimní stadion"
        case .cernosice: "Černošice, Zimní stadion"
        case .kobraPraha: "Praha - Kobra, Zimní stadion HC Kobra Praha"
        case .rakovnik: "Rakovník, Zimní stadion města Rakovníka"
        case .spmArenaPraha: "Praha, SPM ARENA"
        case .slany: "VSH Slaný, Zimní stadion"
        case .hvezdaPraha: "Praha - Hvězda, Zimní stadion HC Hvězda Praha"
        case .benesov: "Benešov, Zimní stadion"
        case .sedlcany: "Sedlčany, Zimní stadion"
        case .spartaPraha: "Praha - Holešovice, Sportovní hala Fortuna"
        case .vystavistePraha: "Praha - Výstaviště, Malá sportovní hala"
        case .ricany: "Říčany u Prahy, Com-Sys Ice Arena"
        case .melnik: "Mělník, Zimní stadion"
        case .nymburk: "Nymburk, Zimní stadion"
        case .velkePopovice: "Velké Popovice, Zimní stadion"
        case .neratovice: "Neratovice, Buldok Arena"
        case .tremosna: "Třemošná, Sport Aréna"
        case .sobeslav: "Soběslav, ZS TJ Spartak Soběslav"
        case .klatovy: "Klatovy, Zimní stadion města Klatov"
        case .domazlice: "Domažlice, Zimní stadion"
        case .jindrichuvHradec: "Jindřichův Hradec, Zimní stadion"
        case .plzenKosutka: "Plzeň - Košutka, ICE ARENA Plzeň"
        case .humpolec: "Humpolec, Zimní stadion"
        case .rokycany: "Rokycany, Zimní stadion"
        case .milevsko: "Milevsko, Zimní stadion"
        case .vlasim: "Vlašim, Zimní stadion"
        case .kutnaHora: "Kutná Hora, Zimní stadion"
        case .benatkyNadJizerou: "Benátky nad Jizerou, Zimní stadion"
        case .caslav: "Čáslav, Zimní stadion"
        }
    }
    
    var travelDuration: ICalendarDuration {
        switch self {
        case .beroun: .minutes(15)
        case .kladno: .minutes(45)
        case .pribram: .minutes(60)
        case .horovice: .minutes(30)
        case .kralupy: .minutes(75)
        case .cernosice: .minutes(40)
        case .kobraPraha: .minutes(60)
        case .rakovnik: .minutes(45)
        case .spmArenaPraha: .minutes(45)
        case .slany: .minutes(60)
        case .hvezdaPraha: .minutes(45)
        case .benesov: .minutes(90)
        case .sedlcany: .minutes(75)
        case .spartaPraha: .minutes(60)
        case .vystavistePraha: .minutes(45)
        case .ricany: .minutes(45)
        case .melnik: .minutes(70)
        case .nymburk: .minutes(75)
        case .velkePopovice: .minutes(45)
        case .neratovice: .minutes(60)
        case .tremosna: .minutes(45)
        case .sobeslav: .minutes(100)
        case .klatovy: .minutes(70)
        case .domazlice: .minutes(90)
        case .jindrichuvHradec: .minutes(120)
        case .plzenKosutka: .minutes(45)
        case .humpolec: .minutes(80)
        case .rokycany: .minutes(30)
        case .milevsko: .minutes(80)
        case .vlasim: .minutes(70)
        case .kutnaHora: .minutes(90)
        case .benatkyNadJizerou: .minutes(70)
        case .caslav: .minutes(90)
        }
    }
}
