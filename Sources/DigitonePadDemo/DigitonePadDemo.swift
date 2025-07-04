import SwiftUI
import UIComponents

@main
struct DigitonePadDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DigitonePadDemoView()
        }
    }
}

struct DigitonePadDemoView: View {
    @State private var isPlaying = false
    @State private var volume: Double = 0.5
    @State private var frequency: Double = 440.0
    @State private var filterCutoff: Double = 1000.0
    @State private var filterResonance: Double = 0.5
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack {
                    Text("DigitonePad")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("iPad Demo")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Main Controls
                VStack(spacing: 40) {
                    // Play/Stop Button
                    Button(action: {
                        isPlaying.toggle()
                    }) {
                        ZStack {
                            Circle()
                                .fill(isPlaying ? Color.red : Color.green)
                                .frame(width: 120, height: 120)
                                .shadow(radius: 10)
                            
                            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    }
                    .scaleEffect(isPlaying ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isPlaying)
                    
                    // Volume Control
                    VStack {
                        Text("Volume")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.gray)
                            
                            Slider(value: $volume, in: 0...1)
                                .accentColor(.blue)
                            
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        
                        Text("\(Int(volume * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // Frequency Control
                    VStack {
                        Text("Frequency")
                            .font(.headline)
                            .foregroundColor(.white)

                        HStack {
                            Text("220Hz")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Slider(value: $frequency, in: 220...880)
                                .accentColor(.orange)

                            Text("880Hz")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)

                        Text("\(Int(frequency))Hz")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    // Filter Controls
                    HStack(spacing: 30) {
                        // Filter Cutoff
                        VStack {
                            Text("Filter Cutoff")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack {
                                Text("100Hz")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                Slider(value: $filterCutoff, in: 100...8000)
                                    .accentColor(.purple)

                                Text("8kHz")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Text("\(Int(filterCutoff))Hz")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        // Filter Resonance
                        VStack {
                            Text("Resonance")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack {
                                Text("0%")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                Slider(value: $filterResonance, in: 0...1)
                                    .accentColor(.red)

                                Text("100%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Text("\(Int(filterResonance * 100))%")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Status
                VStack(spacing: 8) {
                    Text("Status: \(isPlaying ? "Playing" : "Stopped")")
                        .font(.subheadline)
                        .foregroundColor(isPlaying ? .green : .gray)

                    Text("DigitonePad Demo for iPad")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("Modules: UIComponents ✓")
                        .font(.caption)
                        .foregroundColor(.green)

                    Text("Freq: \(Int(frequency))Hz | Filter: \(Int(filterCutoff))Hz | Res: \(Int(filterResonance * 100))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.3)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            #if os(iOS)
            .navigationBarHidden(true)
            #else
            .toolbar(.hidden)
            #endif
        }
        #if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
}

#if DEBUG
struct DigitonePadDemoView_Previews: PreviewProvider {
    static var previews: some View {
        DigitonePadDemoView()
            .previewDevice("iPad Pro (12.9-inch) (6th generation)")
    }
}
#endif
