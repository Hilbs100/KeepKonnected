//
//  AppState.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/28/25.
//


// File: `KeepKonnected/AppState.swift` — shared app state
import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var selectedContactID: String? = nil
}
