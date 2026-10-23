// radio/Features/Buscar/View/BuscarView.swift

import SwiftUI

struct BuscarView: View {
    @State private var searchText: String = ""
    @State private var viewModel = BuscarViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.resultados, id: \.self) { resultado in
                Text(resultado)
            }
            .navigationTitle("Buscar")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .onChange(of: searchText) { _, newValue in
                viewModel.buscar(newValue)
            }
        }
    }
}
