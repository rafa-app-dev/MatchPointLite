//
//  MatchPointLiteApp.swift
//  MatchPointLiteApp
//
//  Created by Rafael Correa on 3/23/26.
//

import SwiftUI
import Combine

enum PointValue: String {
    case zero = "0", fifteen = "15", thirty = "30", forty = "40", ad = "AD"
}

enum HapticFeedbackType { case point, game, set, undo, starPoint }

struct MatchState {
    let userP: PointValue; let oppP: PointValue
    let userG: Int; let oppG: Int
    let userS: Int; let oppS: Int
    let isTB: Bool
    let userTBP: Int; let oppTBP: Int
    let servingUser: Bool
    let golden: Bool
    let starPointEnabled: Bool
    let currentDeuceCount: Int
}

class MatchPointManager: ObservableObject {
    @Published var userPoints: PointValue = .zero
    @Published var opponentPoints: PointValue = .zero
    @Published var userGames = 0
    @Published var opponentGames = 0
    @Published var userSets = 0
    @Published var opponentSets = 0
    
    @Published var isTieBreak = false
    @Published var userTBPoints = 0
    @Published var opponentTBPoints = 0
    @Published var servingUserTeam = true
    
    @Published var isGoldenPoint = false
    @Published var isStarPointEnabled = false
    @Published var deuceCount = 0 // Counter for Deuces
    
    @Published var lastHaptic: HapticFeedbackType = .point
    
    private var history: [MatchState] = []
    
    func scorePoint(forUser: Bool) {
        saveToHistory()
        lastHaptic = .point
        
        if isTieBreak {
            applyTieBreakLogic(forUser: forUser)
        } else {
            if forUser {
                applyStandardLogic(winner: &userPoints, loser: &opponentPoints, isUser: true)
            } else {
                applyStandardLogic(winner: &opponentPoints, loser: &userPoints, isUser: false)
            }
        }
        self.objectWillChange.send()
    }
    
    private func applyStandardLogic(winner: inout PointValue, loser: inout PointValue, isUser: Bool) {
        
        // 1. CHECK FOR DEUCE (40-40)
        if winner == .thirty && loser == .forty {
            deuceCount += 1
            if isStarPointEnabled && deuceCount == 3 {
                lastHaptic = .starPoint
            }
        }

        // 2. SCORING AT 40
        if winner == .forty {
            // Rule: Star Point (3rd Deuce wins the game)
            if isStarPointEnabled && deuceCount >= 3 {
                winGame(userWon: isUser)
                return
            }

            // Rule: Golden Point (First deuce wins the game)
            if isGoldenPoint && loser == .forty {
                winGame(userWon: isUser)
                return
            }

            // Standard Advantage Logic
            if loser == .forty {
                winner = .ad
            } else if loser == .ad {
                // Return to Deuce
                loser = .forty
                deuceCount += 1
                if isStarPointEnabled && deuceCount == 3 {
                    lastHaptic = .starPoint
                }
            } else {
                winGame(userWon: isUser)
            }
            
        } else if winner == .ad {
            winGame(userWon: isUser)
        } else {
            // Standard Point Increment
            switch winner {
            case .zero: winner = .fifteen
            case .fifteen: winner = .thirty
            case .thirty: winner = .forty
            default: break
            }
        }
    }
    
    private func winGame(userWon: Bool) {
            lastHaptic = .game
            if userWon { userGames += 1 } else { opponentGames += 1 }
            
            servingUserTeam.toggle()
            deuceCount = 0
            
            // Use a tiny delay to ensure the UI updates the "Win" state before resetting
            DispatchQueue.main.async {
                self.userPoints = .zero
                self.opponentPoints = .zero
                self.checkSetStatus()
                self.objectWillChange.send() // Force UI Refresh
            }
        }
    
    private func checkSetStatus() {
        if userGames == 6 && opponentGames == 6 {
            isTieBreak = true
        } else if (userGames >= 6 && userGames >= opponentGames + 2) || userGames == 7 {
            winSet(userWon: true)
        } else if (opponentGames >= 6 && opponentGames >= userGames + 2) || opponentGames == 7 {
            winSet(userWon: false)
        }
    }
    
    private func winSet(userWon: Bool) {
            lastHaptic = .set
            if userWon { userSets += 1 } else { opponentSets += 1 }
            
            DispatchQueue.main.async {
                self.userGames = 0
                self.opponentGames = 0
                self.userPoints = .zero
                self.opponentPoints = .zero
                self.isTieBreak = false
                self.userTBPoints = 0
                self.opponentTBPoints = 0
                self.deuceCount = 0
                self.objectWillChange.send() // Force UI Refresh
            }
        }

    private func applyTieBreakLogic(forUser: Bool) {
        if forUser { userTBPoints += 1 } else { opponentTBPoints += 1 }
        let total = userTBPoints + opponentTBPoints
        
        if total == 1 || (total > 1 && (total - 1) % 2 == 0) {
            servingUserTeam.toggle()
        }
        
        if userTBPoints >= 7 && userTBPoints >= opponentTBPoints + 2 {
            userGames = 7
            winSet(userWon: true)
        } else if opponentTBPoints >= 7 && opponentTBPoints >= userTBPoints + 2 {
            opponentGames = 7
            winSet(userWon: false)
        }
    }

    func modifyGames(forUser: Bool, increment: Bool) {
            saveToHistory()
            if forUser {
                userGames = max(0, userGames + (increment ? 1 : -1))
            } else {
                opponentGames = max(0, opponentGames + (increment ? 1 : -1))
            }
            checkSetStatus()
            self.objectWillChange.send()
        }
        
        func modifySets(forUser: Bool, increment: Bool) {
            saveToHistory()
            if forUser {
                userSets = max(0, userSets + (increment ? 1 : -1))
            } else {
                opponentSets = max(0, opponentSets + (increment ? 1 : -1))
            }
            self.objectWillChange.send()
        }
        
        func toggleServe() {
            saveToHistory()
            servingUserTeam.toggle()
            self.objectWillChange.send()
        }
    
    func resetMatch() {
        saveToHistory()
        userPoints = .zero; opponentPoints = .zero
        userGames = 0; opponentGames = 0
        userSets = 0; opponentSets = 0
        isTieBreak = false; userTBPoints = 0; opponentTBPoints = 0
        servingUserTeam = true
        deuceCount = 0
        self.objectWillChange.send()
    }
    
    private func saveToHistory() {
        let state = MatchState(userP: userPoints, oppP: opponentPoints, userG: userGames, oppG: opponentGames, userS: userSets, oppS: opponentSets, isTB: isTieBreak, userTBP: userTBPoints, oppTBP: opponentTBPoints, servingUser: servingUserTeam, golden: isGoldenPoint, starPointEnabled: isStarPointEnabled, currentDeuceCount: deuceCount)
        history.append(state)
    }
    
    func undo() {
        guard let prev = history.popLast() else { return }
        userPoints = prev.userP; opponentPoints = prev.oppP
        userGames = prev.userG; opponentGames = prev.oppG
        userSets = prev.userS; opponentSets = prev.oppS
        isTieBreak = prev.isTB; userTBPoints = prev.userTBP; opponentTBPoints = prev.oppTBP
        servingUserTeam = prev.servingUser
        isGoldenPoint = prev.golden
        isStarPointEnabled = prev.starPointEnabled
        deuceCount = prev.currentDeuceCount
        lastHaptic = .undo
        self.objectWillChange.send()
    }
}
