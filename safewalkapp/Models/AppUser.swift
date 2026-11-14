//
//  AppUser.swift
//  safewalkapp
//



import Foundation

// MODEL: plain data, no screen or Firebase logic.
// This is what we store in Firestore at users/{uid}.
struct AppUser: Identifiable {
    let id: String          // Firebase Auth uid
    var fullName: String
    var email: String
    var phone: String?      // not in the design yet; needed later for trusted contacts
    var createdAt: Date
}
