//
//  SplashScreenView.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/21/25.
//

import SwiftUI
import HealthKit
import Charts

// MARK: - Splash Screen View
struct SplashScreenView: View {
    @State private var isLoading = true
    @State private var pawScale: CGFloat = 0.5
    @State private var pawOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 50
    @State private var backgroundOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            if isLoading {
                // Splash Screen
                ZStack {
                    // Background gradient
                    LinearGradient(
                        gradient: Gradient(colors: [Color.stepperDarkBlue, Color.stepperTeal]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    .opacity(backgroundOpacity)
                    
                    VStack(spacing: 30) {
                        Spacer()
                        
                        // App Icon/Logo
                        VStack(spacing: 20) {
                            // App Icon - replace this section
                            ZStack {
                                // Background circle (like your app icon)
                                Circle()
                                    .fill(Color.stepperTeal)
                                    .frame(width: 120, height: 120)
                                
                                // Paw print on top
                                Image("Splash")  // Use your actual app icon filename
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(25)  // Rounded corners like iOS icons
                                    .scaleEffect(pawScale)
                                    .opacity(pawOpacity)
                            }
                            .scaleEffect(pawScale)
                            .opacity(pawOpacity)
                            
                            // App name
                            Text("Stepper")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.stepperCream)
                                .offset(y: textOffset)
                                .opacity(pawOpacity)
                            
                            // Tagline
                            Text("Track your steps! 🐾")
                                .font(.title3)
                                .foregroundColor(.stepperCream.opacity(0.8))
                                .offset(y: textOffset)
                                .opacity(pawOpacity * 0.8)
                        }
                        
                        Spacer()
                        
                        // Loading indicator
                        VStack(spacing: 15) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .stepperYellow))
                                .scaleEffect(1.2)
                                .opacity(pawOpacity)
                            
                            Text("Getting ready...")
                                .font(.subheadline)
                                .foregroundColor(.stepperCream.opacity(0.7))
                                .opacity(pawOpacity)
                        }
                        .padding(.bottom, 50)
                    }
                }
                .onAppear {
                    startSplashAnimation()
                }
            } else {
                // Main App
                MainView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isLoading)
    }
    
    private func startSplashAnimation() {
        // Animate background
        withAnimation(.easeIn(duration: 0.5)) {
            backgroundOpacity = 1.0
        }
        
        // Animate paw and text with slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                pawScale = 1.0
                pawOpacity = 1.0
                textOffset = 0
            }
        }
        
        // Hide splash screen after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                isLoading = false
            }
        }
    }
}


