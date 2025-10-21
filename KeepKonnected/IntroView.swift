//
//  IntroView.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/18/25.
//

import SwiftUI
import SwiftData

// Very Basic Introduction Pages

struct IntroPage1: View {
    @EnvironmentObject private var introState: IntroState
    var body: some View {
        VStack {
            
            // Centered explanatory text
            VStack(alignment: .leading, spacing: 30) {
                Text("KeepKonnected will ask you for some contacts that you want help staying in touch with.")
                    .font(.title2)
                Text("On the first page, you'll put in 3 to 5 contacts that you want reminders to be contacted about approximately weekly.")
                    .font(.subheadline)
                Text("On the second page, you'll enter about 5 to 10 different contacts that you want reminders about approximately monthly.")
                    .font(.subheadline)
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 30)
            .padding(.top, 50)
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            
            Button(action: { introState.value = 2 }) {
                Text("Next")
                    .font(.headline)
                    .padding()
                    .containerRelativeFrame(.horizontal, count: 5, span: 3, spacing: 0)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.bottom, 50)
        }
    }
}

struct IntroPage2: View {
    @EnvironmentObject private var introState: IntroState
    var body: some View {
        VStack {
            ContactView(contact_type: .weekly)
                .modelContainer(for: [Contact.self])
            
            Button(action: { introState.value = 3 }) {
                Text("Next")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
        }
    }
}

struct IntroPage3: View {
    @EnvironmentObject private var introState: IntroState
    var body: some View {
        VStack {
            ContactView(contact_type: .monthly)
                .modelContainer(for: [Contact.self])
            
            Button(action: { introState.value = 4 }) {
                Text("Finished")
                    .font(.headline)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
        }
    }
}

// Root view that shows the appropriate intro page based on IntroState
struct IntroRoot: View {
    @EnvironmentObject private var introState: IntroState
    var body: some View {
        VStack(alignment: .leading) {
            Text("Welcome to KeepKonnected")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .lineLimit(nil) // Allow unlimited lines
                .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
        }
        .padding(.top, 40)
        NavigationView {
            Group {
                switch introState.value {
                case 1:
                    IntroPage1()
                case 2:
                    IntroPage2()
                case 3:
                    IntroPage3()
                default:
                    // If value is 4 (or any other unexpected value), go to the main app; keep a placeholder
                    HomeView() // fallback; in the App we switch to ContactView when value == 4
                        .modelContainer(for: [Contact.self])
                }
            }
        }
    }
}

// Page 1 Light
#Preview("IntroRoot - Page 1") {
    let state = IntroState()
    state.value = 1
    return IntroRoot().environmentObject(state)
}

// Page 1 Dark
#Preview("IntroRoot - Page 1 Dark") {
    let state = IntroState()
    state.value = 1
    return IntroRoot().environmentObject(state)
        .preferredColorScheme(.dark)
}

// Page 2 Light
#Preview("IntroRoot - Page 2") {
    let state = IntroState()
    state.value = 2
    return IntroRoot().environmentObject(state)
}

// Page 2 Dark
#Preview("IntroRoot - Page 2 Dark") {
    let state = IntroState()
    state.value = 2
    return IntroRoot().environmentObject(state)
        .preferredColorScheme(.dark)
}

// Page 3 Light
#Preview("IntroRoot - Page 3") {
    let state = IntroState()
    state.value = 3
    return IntroRoot().environmentObject(state)
}

// Page 3 Dark
#Preview("IntroRoot - Page 3 Dark") {
    let state = IntroState()
    state.value = 3
    return IntroRoot().environmentObject(state)
        .preferredColorScheme(.dark)
}
