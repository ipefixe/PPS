//
//  PPSService.swift
//  PPS
//
//  Created by Kevin Boulala on 23/06/2025.
//

import Foundation
import SwiftSoup

enum PPSError: LocalizedError {
    case invalidURL(String)
    case invalidData(URL?)
    case csrfTokenNotFound
    case authenticityTokenNotFound
    case ppsCodeNotFound

    var errorDescription: String {
        return switch self {
        case .invalidURL(let url): "The URL generated is invalid: \(url)"
        case .invalidData(let url): "Invalid HTML data received for: \(url?.absoluteString ?? "---")"
        case .csrfTokenNotFound: "CSRF Token not found"
        case .authenticityTokenNotFound: "Authenticity Token not found"
        case .ppsCodeNotFound: "PPS Code not found"
        }
    }
}

final class PPSService {
    // MARK: - Enums

    private enum Path: String {
        case pps
        case raceDate
        case personalInfos
        case cardiovascularRisks
        case riskFactors
        case precautions
        case finalization

        var httpMethod: String {
            switch self {
            case .pps:
                return "GET"
            default: // Everything else is a POST
                return "POST"
            }
        }

        var path: String {
            let base = "https://pps.athle.fr/"

            return switch self {
            case .pps:
                base
            case .raceDate:
                base + "courses/wizards/race_date"
            case .personalInfos:
                base + "courses/wizards/personal_infos"
            case .cardiovascularRisks:
                base + "courses/wizards/cardiovascular_risks"
            case .riskFactors:
                base + "courses/wizards/risk_factors"
            case .precautions:
                base + "courses/wizards/precautions"
            case .finalization:
                base + "courses/wizards/finalization"
            }
        }
    }

    // MARK: - Publics

    func generatePPSCode(raceDate: Date,
                         gender: String,
                         lastname: String,
                         firstname: String,
                         birthdate: Date,
                         email: String) async throws -> String {
        let raceDateString = raceDate.shortDate
        let birthdateDay = birthdate.day
        let birthdateMonth = birthdate.month
        let birthdateYear = birthdate.year

        let (csrfPPS, authenticityPPS) = try await getPPS()

        let (csrfRace, authenticityRace) = try await postRaceDate(csrf: csrfPPS,
                                                                  authenticity: authenticityPPS,
                                                                  date: raceDateString)

        let (csrfPers, authenticityPers) = try await postPersonalInfos(csrf: csrfRace,
                                                                       authenticity: authenticityRace,
                                                                       gender: gender,
                                                                       lastname: lastname,
                                                                       firstname: firstname,
                                                                       day: birthdateDay,
                                                                       month: birthdateMonth,
                                                                       year: birthdateYear,
                                                                       email: email)

        let (csrfCardio, authenticityCardio) = try await postCardiovascularRisks(csrf: csrfPers,
                                                                                 authenticity: authenticityPers)

        let (csrfRisk, authenticityRisk) = try await postRiskFactors(csrf: csrfCardio,
                                                                     authenticity: authenticityCardio)

        let (csrfPrec, authenticityPrec) = try await postPrecautions(csrf: csrfRisk,
                                                                     authenticity: authenticityRisk)

        let ppsCode = try await postFinalization(csrf: csrfPrec,
                                                 authenticity: authenticityPrec)

        return ppsCode
    }

    // MARK: - Privates

    /// Find the CSRF token
    /// - Parameter html: HTML code to search for the `CSRF token`
    /// - Returns: CSRF Token, otherwise throw an exception
    private func csrfToken(from html: String) throws -> String {
        let document = try SwiftSoup.parse(html)
        let csrfElements = try document.select("meta[name=csrf-token]")

        guard let csrfToken = try csrfElements.first()?.attr("content") else {
            throw PPSError.csrfTokenNotFound
        }

        return csrfToken
    }

    /// Find the Authenticity Token
    /// - Parameter html: HTML code to search for the `Authenticity Token`
    /// - Returns: Authenticity Token, otherwise throw an exception
    private func authenticityToken(from html: String) throws -> String {
        let document = try SwiftSoup.parse(html)
        let authentTokenElements = try document.select("input[name=authenticity_token]")

        guard let authenticityToken = try authentTokenElements.first()?.attr("value") else {
            throw PPSError.authenticityTokenNotFound
        }

        return authenticityToken
    }

    /// Find pps code in html page
    /// - Parameter html: HTML code to search for the `Authenticity Token`
    /// - Returns: PPS Code, otherwise throw an exception
    private func ppsCode(from html: String) throws -> String {
        let document = try SwiftSoup.parse(html)
        let ppsCodeElements = try document.select("button[data-clipboard-text]")

        guard let ppsCode = try ppsCodeElements.first()?.attr("data-clipboard-text") else {
            throw PPSError.ppsCodeNotFound
        }

        return ppsCode
    }

    /// Fill the header of an URL request
    /// - Parameters:
    ///   - request: URL Request to update
    ///   - csrfToken: CSRF Token to set in the header of the request (can be nil for the first GET)
    private func fillHeader(of request: inout URLRequest,
                            csrfToken: String? = nil) {
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        if let csrfToken {
            request.setValue(csrfToken, forHTTPHeaderField: "X-CSRF-Token")
        }
    }

    /// Download data from an URL request
    /// - Parameter request: Target request
    /// - Returns: HTML code, otherwise an exception
    private func data(for request: URLRequest) async throws -> String {
        let (data, _) = try await URLSession.shared.data(for: request)

        guard let html = String(data: data, encoding: .utf8) else {
            throw PPSError.invalidData(request.url)
        }

        return html
    }

    // MARK: Requests

    private func getPPS() async throws -> (String, String) {
        print("⚪️ GET PPS")
        guard let url = URL(string: Path.pps.path) else {
            throw PPSError.invalidURL(Path.pps.path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = Path.pps.httpMethod
        fillHeader(of: &request)

        let html = try await data(for: request)

        let csrfToken = try csrfToken(from: html)
        let authenticityToken = try authenticityToken(from: html)

        print("🟢\(csrfToken)\n🟢\(authenticityToken)")

        return (csrfToken, authenticityToken)
    }

    private func postRaceDate(csrf: String,
                              authenticity: String,
                              date: String) async throws -> (String, String) {
        print("⚪️ POST RACE DATE")
        guard let url = URL(string: Path.raceDate.path) else {
            throw PPSError.invalidURL(Path.raceDate.path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = Path.raceDate.httpMethod
        fillHeader(of: &request, csrfToken: csrf)
        request.httpBody = Data("_method=patch&authenticity_token=\(authenticity)&course[race_date]=\(date)&button".utf8)

        let html = try await data(for: request)

        let csrfToken = try csrfToken(from: html)
        let authenticityToken = try authenticityToken(from: html)

        print("🟢\(csrfToken)\n🟢\(authenticityToken)")

        return (csrfToken, authenticityToken)
    }

    private func postPersonalInfos(csrf: String,
                                   authenticity: String,
                                   gender: String,
                                   lastname: String,
                                   firstname: String,
                                   day: String,
                                   month: String,
                                   year: String,
                                   email: String) async throws -> (String, String) {
        print("⚪️ POST PERSONAL INFOS")
        guard let url = URL(string: Path.personalInfos.path) else {
            throw PPSError.invalidURL(Path.personalInfos.path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = Path.personalInfos.httpMethod
        fillHeader(of: &request, csrfToken: csrf)
        request.httpBody = Data(
            "_method=patch&authenticity_token=\(authenticity)&course[gender]&course[gender]=\(gender)&course[last_name]=\(lastname)&course[first_name]=\(firstname)&course[birthdate(3i)]=\(day)&course[birthdate(2i)]=\(month)&course[birthdate(1i)]=\(year)&course[email]=\(email)&button".utf8
        )

        let html = try await data(for: request)

        let csrfToken = try csrfToken(from: html)
        let authenticityToken = try authenticityToken(from: html)

        print("🟢\(csrfToken)\n🟢\(authenticityToken)")

        return (csrfToken, authenticityToken)
    }

    private func postCardiovascularRisks(csrf: String,
                                         authenticity: String) async throws -> (String, String) {
        print("⚪️ POST CARDIOVASCULAR RISKS")
        guard let url = URL(string: Path.cardiovascularRisks.path) else {
            throw PPSError.invalidURL(Path.cardiovascularRisks.path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = Path.cardiovascularRisks.httpMethod
        fillHeader(of: &request, csrfToken: csrf)
        request.httpBody = Data(
            "_method=patch&authenticity_token=\(authenticity)&course[cardiovascular_risks_video]=1&course[cardiovascular_risks_checkbox]=0&course[cardiovascular_risks_checkbox]=1&button".utf8
        )

        let html = try await data(for: request)

        let csrfToken = try csrfToken(from: html)
        let authenticityToken = try authenticityToken(from: html)

        print("🟢\(csrfToken)\n🟢\(authenticityToken)")

        return (csrfToken, authenticityToken)
    }

    private func postRiskFactors(csrf: String,
                                 authenticity: String) async throws -> (String, String) {
        print("⚪️ POST RISK FACTORS")
        guard let url = URL(string: Path.riskFactors.path) else {
            throw PPSError.invalidURL(Path.riskFactors.path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = Path.riskFactors.httpMethod
        fillHeader(of: &request, csrfToken: csrf)
        request.httpBody = Data(
            "_method=patch&authenticity_token=\(authenticity)&course[risk_factors_video]=1&course[risk_factors_checkbox]=0&course[risk_factors_checkbox]=1&button".utf8
        )

        let html = try await data(for: request)

        let csrfToken = try csrfToken(from: html)
        let authenticityToken = try authenticityToken(from: html)

        print("🟢\(csrfToken)\n🟢\(authenticityToken)")

        return (csrfToken, authenticityToken)
    }

    private func postPrecautions(csrf: String,
                                 authenticity: String) async throws -> (String, String) {
        print("⚪️ POST PRECAUTIONS")
        guard let url = URL(string: Path.precautions.path) else {
            throw PPSError.invalidURL(Path.precautions.path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = Path.precautions.httpMethod
        fillHeader(of: &request, csrfToken: csrf)
        request.httpBody = Data(
            "_method=patch&authenticity_token=\(authenticity)&course[precautions_video]=1&course[precautions_checkbox]=0&course[precautions_checkbox]=1&button".utf8
        )

        let html = try await data(for: request)

        let csrfToken = try csrfToken(from: html)
        let authenticityToken = try authenticityToken(from: html)

        print("🟢\(csrfToken)\n🟢\(authenticityToken)")

        return (csrfToken, authenticityToken)
    }

    private func postFinalization(csrf: String,
                                  authenticity: String) async throws -> String {
        print("⚪️ POST FINALIZATION")
        guard let url = URL(string: Path.finalization.path) else {
            throw PPSError.invalidURL(Path.finalization.path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = Path.finalization.httpMethod
        fillHeader(of: &request, csrfToken: csrf)
        request.httpBody = Data(
            "_method=patch&authenticity_token=\(authenticity)&course[finalization_checkbox]=0&course[finalization_checkbox]=1&course[ffa_newsletter]=0&button".utf8
        )

        let html = try await data(for: request)

        return try ppsCode(from: html)
    }
}
