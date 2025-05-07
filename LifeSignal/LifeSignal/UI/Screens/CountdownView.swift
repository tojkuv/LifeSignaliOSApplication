import SwiftUI
import Foundation

struct CountdownView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @State private var showCheckInConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Countdown circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                        .frame(width: 220, height: 220)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: calculateProgress())
                        .stroke(
                            calculateProgress() < 0.25 ? Color.red :
                                calculateProgress() < 0.5 ? Color.orange : Color.blue,
                            style: StrokeStyle(lineWidth: 15, lineCap: .round)
                        )
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                    
                    // Time remaining text
                    VStack(spacing: 8) {
                        Text("Time Remaining")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(userViewModel.timeUntilNextCheckIn)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("until check-in")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .padding(.top, 40)
                
                // Check-in button
                Button(action: {
                    showCheckInConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text("Check In Now")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                }
                .padding(.top, 20)
                
                // Interval information
                VStack(spacing: 16) {
                    HStack {
                        Text("Check-in interval:")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(formatInterval(userViewModel.checkInInterval))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Text("Last checked in:")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(formatDate(userViewModel.lastCheckedIn))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Text("Next check-in due:")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(formatDate(userViewModel.checkInExpiration))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Check-In")
            .navigationBarTitleDisplayMode(.large)
            .alert(isPresented: $showCheckInConfirmation) {
                Alert(
                    title: Text("Confirm Check-in"),
                    message: Text("Are you sure you want to check in now? This will reset your timer."),
                    primaryButton: .default(Text("Check In")) {
                        userViewModel.updateLastCheckedIn()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // Calculate progress for the circle (0.0 to 1.0)
    private func calculateProgress() -> CGFloat {
        let totalInterval = userViewModel.checkInInterval
        let elapsed = Date().timeIntervalSince(userViewModel.lastCheckedIn)
        let remaining = max(0, totalInterval - elapsed)
        return CGFloat(remaining / totalInterval)
    }
    
    // Format the interval for display
    private func formatInterval(_ interval: TimeInterval) -> String {
        let days = Int(interval / (24 * 60 * 60))
        let hours = Int((interval.truncatingRemainder(dividingBy: 24 * 60 * 60)) / (60 * 60))
        
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
    
    // Format date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    CountdownView()
        .environmentObject(UserViewModel())
}
