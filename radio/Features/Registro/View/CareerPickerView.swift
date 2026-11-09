// radio/Features/Registro/View/CareerPickerView.swift

import SwiftUI

struct CareerPickerView: View {
    let careers: [Career]
    @Binding var selectedCareerId: String?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [Career] {
        guard !searchText.isEmpty else { return careers }
        return careers.filter {
            $0.name.localizedStandardContains(searchText) ||
            $0.department.localizedStandardContains(searchText) ||
            $0.faculty.localizedStandardContains(searchText)
        }
    }

    private var groups: [(title: String, careers: [Career])] {
        var order: [String] = []
        var buckets: [String: [Career]] = [:]
        for career in filtered {
            let key = "\(career.group) · \(career.department)"
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(career)
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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(career.name).foregroundStyle(.primary)
                                    Text(career.level == "posgrado" ? "Posgrado · \(career.department)" : career.department)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
        .searchable(text: $searchText, prompt: "Buscar programa, departamento o facultad")
        .navigationTitle("Programa académico")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DepartmentPickerView: View {
    let departments: [DepartmentOption]
    @Binding var selectedDepartmentId: String?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [DepartmentOption] {
        guard !searchText.isEmpty else { return departments }
        return departments.filter {
            $0.name.localizedStandardContains(searchText) ||
            $0.faculty.localizedStandardContains(searchText)
        }
    }

    private var groups: [(title: String, items: [DepartmentOption])] {
        var order: [String] = []
        var buckets: [String: [DepartmentOption]] = [:]
        for dept in filtered {
            if buckets[dept.group] == nil { order.append(dept.group) }
            buckets[dept.group, default: []].append(dept)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var body: some View {
        List {
            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.items) { dept in
                        Button {
                            selectedDepartmentId = dept.id
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dept.name).foregroundStyle(.primary)
                                    Text(dept.faculty)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedDepartmentId == dept.id {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Buscar departamento o facultad")
        .navigationTitle("Departamento")
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
                       faculty: "Facultad de Educación, Artes y Humanidades", campus: "cucuta", modality: "presencial")
            ],
            selectedCareerId: Binding<String?>.constant("ingenieria-sistemas")
        )
    }
}
