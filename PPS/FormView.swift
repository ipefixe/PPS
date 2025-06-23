//
//  FormView.swift
//  PPS
//
//  Created by Kevin Boulala on 23/06/2025.
//

import SwiftUI

struct FormView: View {
    enum Sex: String, CaseIterable, Identifiable {
        case male, female
        var id: Self { self }
    }

    @State private var raceDate: Date = .init()
    @State private var sex: Sex = .male
    @State private var lastname: String = ""
    @State private var firstname: String = ""
    @State private var birthdate: Date = Date().addingTimeInterval(-1032000000)
    @State private var email: String = ""

    private var invalidDateRace: Bool {
        guard let dateMin = Calendar.current.date(byAdding: .hour, value: -1, to: Date()),
              let dateMax = Calendar.current.date(byAdding: .month, value: 3, to: dateMin) else {
            return true
        }
        return raceDate < dateMin || raceDate > dateMax
    }

    private var invalidDateBirth: Bool {
        guard let dateLimite = Calendar.current.date(byAdding: .year, value: -18, to: raceDate) else {
            return true
        }
        return birthdate > dateLimite
    }

    private var disableGenerateButton: Bool {
        return lastname.isEmpty || firstname.isEmpty || email.isEmpty || invalidDateRace || invalidDateBirth
    }

    var body: some View {
        VStack {
            Image("PPS")

            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .symbolRenderingMode(.multicolor)
                    .symbolEffect(.breathe)
                    .padding(.horizontal, 5)
                Text("If this is your first time, or if you don't remember the risks, precautions and recommendations. Thank you for following the [Parcours de Prévention Santé](https://pps.athle.fr) offered by the FFA.")
            }
            .padding(.vertical, 40)

            ScrollView {
                VStack(alignment: .leading, spacing: 20.0) {
                    DatePicker(selection: $raceDate,
                               displayedComponents: [.date]) {
                        Text("Date of your next race")
                        Text("The PPS is valid for 3 months")
                    }

                    HStack {
                        Text("Sex")
                        Spacer()
                        Picker("Sex", selection: $sex) {
                            Text("Male").tag(Sex.male)
                            Text("Female").tag(Sex.female)
                        }
                    }

                    HStack {
                        TextField("Last name", text: $lastname)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        TextField("First name", text: $firstname)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                    }

                    DatePicker(selection: $birthdate,
                               displayedComponents: [.date]) {
                        Text("Birthdate")
                        Text("The PPS is reserved exclusively for runners aged 18 and over on the date of the race")
                    }

                    TextField("Email", text: $email)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .center) {
                        Button("Generate") {}
                            .buttonStyle(.borderedProminent)
                            .disabled(disableGenerateButton)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding()
    }
}

#Preview {
    FormView()
}
