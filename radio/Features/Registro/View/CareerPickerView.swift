// radio/Features/Registro/View/CareerPickerView.swift

//
//  CareerPickerView.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

// radio/Features/Registro/View/CareerPickerView.swift

import SwiftUI

struct CareerPickerView: View {
    let careers: [Career]
    @Binding var selectedCareerId: String?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [Career] {
        guard !searchText.isEmpty else { return careers }
        return careers.filter { $0.name.localizedStandardContains(searchText) }
    }

    private var groups: [(title: String, careers: [Career])] {
        var order: [String] = []
        var buckets: [String: [Career]] = [:]
        for career in filtered {
            if buckets[career.group] == nil { order.append(career.group) }
            buckets[career.group, default: []].append(career)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var body: some View {
        List {
            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.careers) { career in
                        Button {
                            selectedCareerId = career.id
                            dismiss()
                        } label: {
                            HStack {
                                Text(career.name).foregroundStyle(.primary)
                                Spacer()
                                if selectedCareerId == career.id {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Buscar carrera")
        .navigationTitle("Carrera")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CareerPickerView(
            careers: [
                Career(id: "ingenieria-sistemas", name: "Ingeniería de Sistemas",
                       faculty: "Facultad de Ingeniería", campus: "cucuta", modality: "presencial"),
                Career(id: "derecho", name: "Derecho",
                       faculty: "Facultad de Educación, Artes y Humanidades", campus: "cucuta", modality: "presencial"),
                Career(id: "ingenieria-civil-ocana", name: "Ingeniería Civil (Ocaña)",
                       faculty: "Facultad de Ingenierías", campus: "ocana", modality: "presencial")
            ],
            selectedCareerId: Binding<String?>.constant("ingenieria-sistemas")
        )
    }
}
