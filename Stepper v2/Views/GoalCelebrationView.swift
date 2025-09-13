//
//  GoalCelebrationView.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 9/1/25.
//

import SwiftUI
import AVFoundation

// MARK: - Confetti Particle Animation
public struct ConfettiParticle: View {
    public let index: Int
    @State public var animate = false
    
    public var colors: [Color] = [
        .stepperYellow, .stepperLightTeal, .stepperCream, .green, .orange
    ]
    
    public var randomColor: Color {
        colors[index % colors.count]
    }
    
    public var randomSize: CGFloat {
        CGFloat.random(in: 8...16)
    }
    
    public var randomX: CGFloat {
        CGFloat.random(in: -UIScreen.main.bounds.width/2...UIScreen.main.bounds.width/2)
    }
    
    public var randomDelay: Double {
        Double.random(in: 0...2)
    }
    
    public var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(randomColor)
            .frame(width: randomSize, height: randomSize)
            .offset(
                x: animate ? randomX : randomX,
                y: animate ? UIScreen.main.bounds.height + 100 : -100
            )
            .rotationEffect(.degrees(animate ? 360 : 0))
            .onAppear {
                withAnimation(
                    .linear(duration: Double.random(in: 3...6))
                    .delay(randomDelay)
                    .repeatForever(autoreverses: false)
                ) {
                    animate = true
                }
            }
    }
}

// MARK: - Goal Celebration View
struct GoalCelebrationView: View {
    let stepCount: Int
    let targetSteps: Int
    @Binding var isPresented: Bool
    @State private var confettiOpacity: Double = 0
    @State private var textScale: CGFloat = 0.1
    @State private var badgeRotation: Double = 0
    @State private var showSecondaryText = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var sparkleOffset: CGFloat = 0
    
    private var overachievement: Int {
        max(0, stepCount - targetSteps)
    }
    
    var body: some View {
        ZStack {
            // Background with animated gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.stepperYellow.opacity(0.8),
                    Color.stepperTeal.opacity(0.6),
                    Color.stepperDarkBlue
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: textScale)
            
            // Animated confetti/sparkles background
            ForEach(0..<50, id: \.self) { index in
                ConfettiParticle(index: index)
                    .opacity(confettiOpacity)
            }
            
            VStack(spacing: 30) {
                Spacer()
                
                // Trophy/Badge Icon with animation
                VStack(spacing: 20) {
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(Color.stepperYellow.opacity(0.6))
                            .frame(width: 180, height: 180)
                            .scaleEffect(pulseScale)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseScale)
                        
                        // Main trophy
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.stepperYellow)
                            .rotationEffect(.degrees(badgeRotation))
                            .scaleEffect(textScale)
                    }
                    
                    // Achievement Text with typewriter effect
                    VStack(spacing: 15) {
                        Text("🎉 Goal Achieved! 🎉")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.stepperCream)
                            .scaleEffect(textScale)
                        
                        if showSecondaryText {
                            VStack(spacing: 10) {
                                Text("\(stepCount) steps!")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(.stepperYellow)
                                    .transition(.scale.combined(with: .opacity))
                                
                                if overachievement > 0 {
                                    Text("🚀 \(overachievement) steps over your goal!")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                                
                                Text("Keep up the amazing work! 👏")
                                    .font(.headline)
                                    .foregroundColor(.stepperCream.opacity(0.9))
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Motivational quote or achievement badge
                if showSecondaryText {
                    VStack(spacing: 15) {
                        getMotivationalMessage()
                            .font(.body)
                            .foregroundColor(.stepperCream.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        
                        // Continue button
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.5)) {
                                isPresented = false
                            }
                        }) {
                            Text("Continue Your Journey! 🚀")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.stepperDarkBlue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.stepperYellow)
                                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                                )
                                .scaleEffect(pulseScale)
                        }
                        .padding(.horizontal, 40)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding()
        }
        .onAppear {
            startCelebrationSequence()
            triggerHapticFeedback()
        }
    }
    
    private func startCelebrationSequence() {
        // Start confetti immediately
        withAnimation(.easeOut(duration: 0.5)) {
            confettiOpacity = 1.0
        }
        
        // Trophy appears with bounce
        withAnimation(.spring(response: 0.8, dampingFraction: 0.5, blendDuration: 0)) {
            textScale = 1.0
        }
        
        // Start trophy rotation
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            badgeRotation = 360
        }
        
        // Start pulse effect
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
        
        // Show secondary text after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showSecondaryText = true
            }
        }
        
        // Sparkle animation
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            sparkleOffset = 360
        }
    }
    
    private func triggerHapticFeedback() {
        // Immediate success haptic
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Sequence of celebration haptics
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impactFeedback.impactOccurred(intensity: 0.8)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impactFeedback.impactOccurred(intensity: 0.6)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            impactFeedback.impactOccurred(intensity: 1.0)
        }
        
        // Final celebratory haptic
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
    }
    
    private func getMotivationalMessage() -> Text {
        let messages = [
            "🌟 You're crushing your goals! Every step counts towards a healthier you.",
            "💪 Your dedication is paying off! You're building incredible healthy habits.",
            "🔥 Amazing consistency! You're proving that small steps lead to big victories.",
            "⭐ You're not just meeting goals, you're exceeding them! Keep this momentum going.",
            "🎯 Goal achieved with style! Your commitment to health is truly inspiring."
        ]
        
        let selectedMessage = messages.randomElement() ?? messages[0]
        return Text(selectedMessage)
    }
}




