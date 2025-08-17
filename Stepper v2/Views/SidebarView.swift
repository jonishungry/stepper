//
//  SidebarView.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//

import SwiftUI

// MARK: - Sidebar View
struct SidebarView: View {
    @Binding var selectedMenuItem: MenuItem
    @Binding var showingSidebar: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Stepper")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.stepperDarkBlue)
                    
                    Spacer()
                }
                
                Text("Track your step progress!")
                    .font(.caption)
                    .foregroundColor(.stepperTeal)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
            
            // Menu Items
            VStack(spacing: 0) {
                ForEach(MenuItem.allCases, id: \.self) { item in
                    Button(action: {
                        selectedMenuItem = item
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSidebar = false
                        }
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: item.icon)
                                .font(.title3)
                                .foregroundColor(selectedMenuItem == item ? .stepperCream : .stepperDarkBlue)
                                .frame(width: 24)
                            
                            Text(item.rawValue)
                                .font(.body)
                                .foregroundColor(selectedMenuItem == item ? .stepperCream : .stepperDarkBlue)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            selectedMenuItem == item ?
                            Color.stepperTeal : Color.clear
                        )
                        .cornerRadius(selectedMenuItem == item ? 12 : 0)
                        .padding(.horizontal, selectedMenuItem == item ? 10 : 0)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.stepperCream)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 5, y: 0)
    }
}
