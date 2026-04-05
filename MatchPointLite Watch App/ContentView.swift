//
//  ContentView.swift
//  MatchPointLiteApp
//
//  Created by Rafael Correa on 3/23/26.
//

import SwiftUI

#if os(watchOS)
import WatchKit
#endif

struct ContentView: View {
    @StateObject private var vm = MatchPointManager()
    @State private var showEditMenu = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // OPPONENT
                scoreSection(title: "OPPONENT",
                             score: vm.isTieBreak ? "\(vm.opponentTBPoints)" : vm.opponentPoints.rawValue,
                             games: vm.opponentGames, sets: vm.opponentSets,
                             color: .red, isServing: !vm.servingUserTeam, isTop: true) {
                    vm.scorePoint(forUser: false)
                    triggerHaptic(type: vm.lastHaptic)
                }
                
                // YOU
                scoreSection(title: "YOU",
                             score: vm.isTieBreak ? "\(vm.userTBPoints)" : vm.userPoints.rawValue,
                             games: vm.userGames, sets: vm.userSets,
                             color: .green, isServing: vm.servingUserTeam, isTop: false) {
                    vm.scorePoint(forUser: true)
                    triggerHaptic(type: vm.lastHaptic)
                }
            }
            .ignoresSafeArea()
            .highPriorityGesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.width < -30 {
                            vm.undo()
                            triggerHaptic(type: .undo)
                        }
                    }
            )
            
            // --- CENTERED MATCH IDENTIFIERS (Equator Placement) ---
                        VStack {
                            Spacer() // Pushes to middle
                            
                            if !vm.isTieBreak {
                                HStack(spacing: 6) {
                                    // 1. DEUCE COUNTER (D1, D2, D3)
                                    if vm.deuceCount > 0 {
                                        Text("D\(vm.deuceCount)")
                                            .font(.system(size: 12, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(vm.deuceCount >= 3 && vm.isStarPointEnabled ? Color.yellow : Color.black)
                                            .foregroundColor(vm.deuceCount >= 3 && vm.isStarPointEnabled ? .black : .white)
                                            .cornerRadius(4)
                                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.5), lineWidth: 1))
                                    }
                                    
                                    // 2. STAR POINT IDENTIFIER
                                    if vm.isStarPointEnabled && vm.deuceCount >= 3 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 12))
                                            Text("STAR")
                                                .font(.system(size: 10, weight: .black))
                                        }
                                        .padding(.horizontal, 5.5)
                                        .padding(.vertical, 2)
                                        .background(Color.yellow)
                                        .foregroundColor(.black)
                                        .cornerRadius(4)
                                    }
                                    
                                    // 3. GOLDEN POINT IDENTIFIER
                                    // Appears at 40-40 when Golden Point is enabled
                                    if vm.isGoldenPoint && vm.userPoints == .forty && vm.opponentPoints == .forty {
                                        Text("GOLDEN PT")
                                            .font(.system(size: 10, weight: .black))
                                            .padding(.horizontal, 5.5)
                                            .padding(.vertical, 2)
                                            .background(Color.yellow)
                                            .foregroundColor(.black)
                                            .cornerRadius(4)
                                    }
                                }
                                .shadow(radius: 2)
                            }
                            
                            Spacer() // Pushes to middle
                        }
            
            if showEditMenu {
                editOverlay
            }
        }
    }
    
    @ViewBuilder
    func scoreSection(title: String, score: String, games: Int, sets: Int, color: Color, isServing: Bool, isTop: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("G: \(games)").bold()
                Spacer().frame(width: 20)
                Text("S: \(sets)").bold()
            }
            .font(.system(.subheadline, design: .monospaced))
            .padding(.top, isTop ? 32 : 10)

            Spacer()

            HStack(alignment: .center, spacing: 10) {
                if isServing { Image(systemName: "tennisball.fill").foregroundColor(.yellow).font(.title3) }
                
                Text(score)
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                if isServing { Spacer().frame(width: 25) }
            }

            Text(title).font(.caption2).tracking(3).opacity(0.7).padding(.bottom, 10)
            Spacer()
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.opacity(0.85))
        .foregroundColor(.white)
        .onTapGesture {
            action()
        }
        .onLongPressGesture(minimumDuration: 0.8) {
            withAnimation { showEditMenu = true }
            triggerHaptic(type: .undo)
        }
    }
    
    var editOverlay: some View {
            // We create a local constant to bypass the StateObject wrapper bugs
            let manager = vm
            
            return ScrollView {
                VStack(spacing: 10) {
                    Text("MATCH SETTINGS").font(.headline).padding(.top)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Golden Point (No Ads)", isOn: $vm.isGoldenPoint)
                        Toggle("Star Point (3rd Deuce)", isOn: $vm.isStarPointEnabled)
                    }
                    .font(.system(size: 10))
                    .padding(.horizontal)

                    HStack(spacing: 15) {
                        // GAMES ADJUSTER
                        VStack {
                            Text("GAMES").font(.system(size: 8))
                            HStack {
                                Button(action: { manager.modifyGames(forUser: true, increment: false) }) {
                                    Image(systemName: "minus.circle")
                                }
                                Button(action: { manager.modifyGames(forUser: true, increment: true) }) {
                                    Image(systemName: "plus.circle")
                                }
                            }
                            .font(.title3)
                            .buttonStyle(.plain)
                        }
                        
                        // SETS ADJUSTER
                        VStack {
                            Text("SETS").font(.system(size: 8))
                            HStack {
                                Button(action: { manager.modifySets(forUser: true, increment: false) }) {
                                    Image(systemName: "minus.circle")
                                }
                                Button(action: { manager.modifySets(forUser: true, increment: true) }) {
                                    Image(systemName: "plus.circle")
                                }
                            }
                            .font(.title3)
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Button("SWITCH SERVE") {
                        manager.toggleServe()
                    }.buttonStyle(.bordered).font(.caption2)
                    
                    HStack {
                        Button("UNDO") {
                            manager.undo()
                        }.tint(.orange)
                        
                        Button("RESET") {
                            manager.resetMatch()
                            self.showEditMenu = false
                        }.tint(.red)
                    }.buttonStyle(.borderedProminent).font(.caption2)
                    
                    Button("CLOSE") {
                        withAnimation { self.showEditMenu = false }
                    }.font(.caption).padding(.bottom)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.95))
            .cornerRadius(15)
            .padding()
            .foregroundColor(.white)
        }
    
    func adjuster(label: String, inc: @escaping () -> Void, dec: @escaping () -> Void) -> some View {
        VStack {
            Text(label).font(.system(size: 8))
            HStack {
                Button(action: dec) { Image(systemName: "minus.circle") }
                Button(action: inc) { Image(systemName: "plus.circle") }
            }
            .font(.title3)
            .buttonStyle(.plain)
        }
    }

    func triggerHaptic(type: HapticFeedbackType) {
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        switch type {
        case .point: device.play(.click)
        case .game: device.play(.success)
        case .set: device.play(.notification)
        case .undo: device.play(.directionDown)
        case .starPoint:
            if #available(watchOS 10.0, *) {
                device.play(.retry)
            } else {
                device.play(.notification)
            }
        }
        #endif
    }
}
