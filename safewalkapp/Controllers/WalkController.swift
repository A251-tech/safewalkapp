/*import Foundation
import Combine
import CoreLocation
import MapKit
import UIKit

enum ShareKind {
   case started, missedCheckIn, arrived, sos, falseAlarm
}

// CONTROLLER: runs the whole walk.
//  - creates the walk in Firestore and shares the position every few seconds
//  - works out time left, next turn, arrival and "off route"
//  - runs the check-in timer
//  - SOS state
// It lives in MainTabView so it keeps running while the walk screen is open.
@MainActor
final class WalkController: ObservableObject {
    @Published private(set) var session: WalkSession?
    @Published private(set) var status: WalkStatus = .active
    @Published private(set) var now = Date()
    @Published private(set) var current: CLLocation?
    @Published private(set) var remainingMeters = 0.0
    @Published private(set) var nextCheckInAt = Date()
    @Published private(set) var isOffRoute = false
    @Published private(set) var isStarting = false
    @Published var showCheckIn = false
    @Published var errorMessage: String?

    private let service = WalkService()
    private let inviteService = InviteService()
    private var ownerUid: String?
    private var cancellables = Set<AnyCancellable>()
    private var tickTask: Task<Void, Never>?
    private var locationService: LocationService?
    private var lastWrite = Date.distantPast
    private var promptShown = false
    private var offRouteStrikes = 0

    // MARK: - Start

    func start(route: WalkPath, destinationName: String, destination: CLLocationCoordinate2D,
               ownerUid: String, ownerName: String, location: LocationService) async -> Bool {
        guard session == nil, !isStarting else { return false }
        errorMessage = nil
        isStarting = true
        defer { isStarting = false }

        let id = WalkService.newToken()
        let interval = TimeInterval(AppConfig.checkInMinutes * 60)
        let firstCheckIn = Date().addingTimeInterval(interval)
        let points = Grid.samplePoints(of: route, every: 20)
            .map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        let firstName = ownerName.split(separator: " ").first.map(String.init) ?? "Someone"

        do {
            try await service.create(id: id,
                                     ownerUid: ownerUid,
                                     ownerFirstName: firstName,
                                     destinationName: destinationName,
                                     expectedArrival: Date().addingTimeInterval(route.expectedTravelTime),
                                     checkInMinutes: AppConfig.checkInMinutes,
                                     nextCheckInAt: firstCheckIn,
                                     start: location.location?.coordinate)
        } catch {
            errorMessage = "Could not start the walk. Check your connection and try again."
            return false
        }

        status = .active
        nextCheckInAt = firstCheckIn
        promptShown = false
        offRouteStrikes = 0
        isOffRoute = false
        showCheckIn = false
        remainingMeters = route.distance
        current = location.location
        lastWrite = .distantPast          // first tick writes the position straight away
        locationService = location
        self.ownerUid = ownerUid
        session = WalkSession(id: id,
                              destinationName: destinationName,
                              destination: destination,
                              route: route,
                              startedAt: Date(),
                              checkInInterval: interval,
                              routePoints: points)

        // Contacts who joined your circle can now follow this walk in their app
        inviteService.setActiveWalk(ownerUid: ownerUid, walkId: id, name: destinationName)

        // Keep listening to location even when the screen is off
        location.beginWalkTracking()
        location.$location
            .compactMap { $0 }
            .sink { [weak self] newLocation in
                Task { @MainActor in self?.handle(newLocation) }
            }
            .store(in: &cancellables)

        startTicking()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    // MARK: - Location updates

    private func handle(_ location: CLLocation) {
        guard let session, status != .ended else { return }
        current = location

        // Where are we along the route?
        var nearest = Double.greatestFiniteMagnitude
        var nearestIndex = 0
        for (index, point) in session.routePoints.enumerated() {
            let d = location.distance(from: point)
            if d < nearest {
                nearest = d
                nearestIndex = index
            }
        }
        let pointsLeft = max(0, session.routePoints.count - 1 - nearestIndex)
        remainingMeters = nearest + Double(pointsLeft) * 20

        // Off route? Needs 3 updates in a row so one bad GPS fix doesn't trigger it
        if nearest > AppConfig.deviationRadius {
            offRouteStrikes += 1
            if offRouteStrikes >= 3 { isOffRoute = true }
        } else {
            offRouteStrikes = 0
            isOffRoute = false
        }

        // Arrived?
        let destination = CLLocation(latitude: session.destination.latitude,
                                     longitude: session.destination.longitude)
        if (status == .active || status == .missedCheckIn),
           location.distance(from: destination) <= AppConfig.arrivalRadius {
            finish(.arrived)
        }
    }

    // MARK: - Timer (runs once a second)

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let session, status != .ended else { return }
        now = Date()

        // 1. Share the position every few seconds, even if the user is standing still
        if status != .arrived,
           let current,
           now.timeIntervalSince(lastWrite) >= AppConfig.writeInterval {
            lastWrite = now
            service.updateLocation(id: session.id, coordinate: current.coordinate)
        }

        // 2. Check-in timer
        if status == .active {
            let left = nextCheckInAt.timeIntervalSince(now)
            if left <= 0 {
                status = .missedCheckIn
                showCheckIn = false
                service.setStatus(id: session.id, status: .missedCheckIn)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            } else if left <= Double(AppConfig.checkInPromptSeconds), !promptShown {
                promptShown = true
                showCheckIn = true
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }

    // MARK: - Actions

    func checkIn() {
        guard let session, status == .active || status == .missedCheckIn else { return }
        let next = Date().addingTimeInterval(session.checkInInterval)
        nextCheckInAt = next
        promptShown = false
        showCheckIn = false
        status = .active
        service.checkedIn(id: session.id, nextCheckInAt: next)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func triggerSOS() {
        guard let session, status != .sos, status != .ended, status != .arrived else { return }
        status = .sos
        showCheckIn = false
        service.setStatus(id: session.id, status: .sos)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    func cancelSOS() {
        guard let session, status == .sos else { return }
        status = .active
        nextCheckInAt = Date().addingTimeInterval(session.checkInInterval)
        promptShown = false
        service.setStatus(id: session.id, status: .active)
    }

    /// User taps End walk
    func end() {
        finish(.ended)
        close()
    }

    /// Closes the walk screen after arrival
    func close() {
        if let ownerUid {
            inviteService.setActiveWalk(ownerUid: ownerUid, walkId: nil, name: nil)
        }
        tickTask?.cancel()
        tickTask = nil
        cancellables.removeAll()
        session = nil
        isOffRoute = false
        showCheckIn = false
    }

    private func finish(_ final: WalkStatus) {
        guard let session else { return }
        service.finish(id: session.id, status: final)
        status = final
        locationService?.endWalkTracking()
        if final == .arrived {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Numbers for the screen

    private var secondsPerMeter: Double {
        guard let route = session?.route, route.distance > 0 else { return 0.75 }
        return route.expectedTravelTime / route.distance
    }

    var minutesLeft: Int {
        max(1, Int((remainingMeters * secondsPerMeter / 60).rounded(.up)))
    }

    var arrivalTime: Date {
        now.addingTimeInterval(remainingMeters * secondsPerMeter)
    }

    /// The next turn: its text and how far away it is
    var nextStep: (text: String, meters: Double)? {
        guard let route = session?.route else { return nil }
        let traveled = max(0, route.distance - remainingMeters)
        var start = 0.0
        for step in route.steps {
            if !step.instructions.isEmpty, start > traveled + 1 {
                return (step.instructions, start - traveled)
            }
            start += step.distance
        }
        return nil
    }

    // MARK: - Messages the user sends from their own phone

    func shareText(_ kind: ShareKind) -> String {
        guard let session else { return "" }
        let link = AppConfig.walkLink(session.id)
        let place = session.destinationName
        let arrive = arrivalTime.formatted(date: .omitted, time: .shortened)

        switch kind {
        case .started:
            return "I'm starting a walk to \(place) and expect to arrive around \(arrive). "
                + "Follow my live location here: \(link)"
        case .missedCheckIn:
            return "I missed my SafeWalk check-in on my walk to \(place). Please try to reach me. "
                + "Live link: \(link)" + mapsLine
        case .arrived:
            return "I've arrived safely at \(place). Thanks for keeping an eye on me."
        case .sos:
            return "SOS! I need help on my walk to \(place). Please call me and come if you can. "
                + "Live location: \(link)" + mapsLine
        case .falseAlarm:
            return "False alarm: I'm okay. Sorry for the scare, please ignore my earlier SOS."
        }
    }

    private var mapsLine: String {
        guard let c = current?.coordinate else { return "" }
        return String(format: "\nMap: https://maps.apple.com/?ll=%.5f,%.5f", c.latitude, c.longitude)
    }
}
*/
import Foundation
import Combine
import CoreLocation
import MapKit
import UIKit

enum ShareKind {
    case started, missedCheckIn, arrived, sos, falseAlarm
}

// CONTROLLER: runs the whole walk.
//  - creates the walk in Firestore and shares the position every few seconds
//  - works out time left, next turn, arrival and "off route"
//  - runs the check-in timer
//  - SOS state
// It lives in MainTabView so it keeps running while the walk screen is open.
@MainActor
final class WalkController: ObservableObject {
    @Published private(set) var session: WalkSession?
    @Published private(set) var status: WalkStatus = .active
    @Published private(set) var now = Date()
    @Published private(set) var current: CLLocation?
    @Published private(set) var remainingMeters = 0.0
    @Published private(set) var nextCheckInAt = Date()
    @Published private(set) var isOffRoute = false
    @Published private(set) var isStarting = false
    @Published var showCheckIn = false
    @Published var errorMessage: String?

    private let service = WalkService()
    private let inviteService = InviteService()
    private var ownerUid: String?
    private var cancellables = Set<AnyCancellable>()
    private var tickTask: Task<Void, Never>?
    private var locationService: LocationService?
    private var lastWrite = Date.distantPast
    private var promptShown = false
    private var offRouteStrikes = 0

    // MARK: - Start

    func start(route: WalkPath, destinationName: String, destination: CLLocationCoordinate2D,
               ownerUid: String, ownerName: String, location: LocationService) async -> Bool {
        guard session == nil, !isStarting else { return false }
        errorMessage = nil
        isStarting = true
        defer { isStarting = false }

        let id = WalkService.newToken()
        let interval = TimeInterval(AppConfig.checkInMinutes * 60)
        let firstCheckIn = Date().addingTimeInterval(interval)
        let points = Grid.samplePoints(of: route, every: 20)
            .map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        let firstName = ownerName.split(separator: " ").first.map(String.init) ?? "Someone"

        do {
            try await service.create(id: id,
                                     ownerUid: ownerUid,
                                     ownerFirstName: firstName,
                                     destinationName: destinationName,
                                     expectedArrival: Date().addingTimeInterval(route.expectedTravelTime),
                                     checkInMinutes: AppConfig.checkInMinutes,
                                     nextCheckInAt: firstCheckIn,
                                     start: location.location?.coordinate)
        } catch {
            errorMessage = "Could not start the walk. Check your connection and try again."
            return false
        }

        status = .active
        nextCheckInAt = firstCheckIn
        promptShown = false
        offRouteStrikes = 0
        isOffRoute = false
        showCheckIn = false
        remainingMeters = route.distance
        current = location.location
        lastWrite = .distantPast          // first tick writes the position straight away
        locationService = location
        self.ownerUid = ownerUid
        session = WalkSession(id: id,
                              destinationName: destinationName,
                              destination: destination,
                              route: route,
                              startedAt: Date(),
                              checkInInterval: interval,
                              routePoints: points)

        // Contacts who joined your circle can now follow this walk in their app
        inviteService.setActiveWalk(ownerUid: ownerUid, walkId: id, name: destinationName)

        // Keep listening to location even when the screen is off
        location.beginWalkTracking()
        location.$location
            .compactMap { $0 }
            .sink { [weak self] newLocation in
                Task { @MainActor in self?.handle(newLocation) }
            }
            .store(in: &cancellables)

        startTicking()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    // MARK: - Location updates

    private func handle(_ location: CLLocation) {
        guard let session, status != .ended else { return }
        current = location

        // Where are we along the route?
        var nearest = Double.greatestFiniteMagnitude
        var nearestIndex = 0
        for (index, point) in session.routePoints.enumerated() {
            let d = location.distance(from: point)
            if d < nearest {
                nearest = d
                nearestIndex = index
            }
        }
        let pointsLeft = max(0, session.routePoints.count - 1 - nearestIndex)
        remainingMeters = nearest + Double(pointsLeft) * 20

        // Off route? Needs 3 updates in a row so one bad GPS fix doesn't trigger it
        if nearest > AppConfig.deviationRadius {
            offRouteStrikes += 1
            if offRouteStrikes >= 3 { isOffRoute = true }
        } else {
            offRouteStrikes = 0
            isOffRoute = false
        }

        // Arrived?
        let destination = CLLocation(latitude: session.destination.latitude,
                                     longitude: session.destination.longitude)
        if (status == .active || status == .missedCheckIn),
           location.distance(from: destination) <= AppConfig.arrivalRadius {
            finish(.arrived)
        }
    }

    // MARK: - Timer (runs once a second)

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let session, status != .ended else { return }
        now = Date()

        // 1. Share the position every few seconds, even if the user is standing still
        if status != .arrived,
           let current,
           now.timeIntervalSince(lastWrite) >= AppConfig.writeInterval {
            lastWrite = now
            service.updateLocation(id: session.id, coordinate: current.coordinate)
        }

        // 2. Check-in timer
        if status == .active {
            let left = nextCheckInAt.timeIntervalSince(now)
            if left <= 0 {
                status = .missedCheckIn
                showCheckIn = false
                service.setStatus(id: session.id, status: .missedCheckIn)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            } else if left <= Double(AppConfig.checkInPromptSeconds), !promptShown {
                promptShown = true
                showCheckIn = true
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }

    // MARK: - Actions

    func checkIn() {
        guard let session, status == .active || status == .missedCheckIn else { return }
        let next = Date().addingTimeInterval(session.checkInInterval)
        nextCheckInAt = next
        promptShown = false
        showCheckIn = false
        status = .active
        service.checkedIn(id: session.id, nextCheckInAt: next)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func triggerSOS() {
        guard let session, status != .sos, status != .ended, status != .arrived else { return }
        status = .sos
        showCheckIn = false
        service.setStatus(id: session.id, status: .sos)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    func cancelSOS() {
        guard let session, status == .sos else { return }
        status = .active
        nextCheckInAt = Date().addingTimeInterval(session.checkInInterval)
        promptShown = false
        service.setStatus(id: session.id, status: .active)
    }

    /// User taps End walk. The walk screen stays open so the user can rate the walk;
    /// it closes when they tap Done (close()).
    func end() {
        finish(.ended)
    }

    /// Closes the walk screen after arrival
    func close() {
        if let ownerUid {
            inviteService.setActiveWalk(ownerUid: ownerUid, walkId: nil, name: nil)
        }
        tickTask?.cancel()
        tickTask = nil
        cancellables.removeAll()
        session = nil
        isOffRoute = false
        showCheckIn = false
    }

    private func finish(_ final: WalkStatus) {
        guard let session else { return }
        service.finish(id: session.id, status: final)
        status = final
        locationService?.endWalkTracking()
        // Contacts stop seeing "Walking now" as soon as the walk is over
        if let ownerUid {
            inviteService.setActiveWalk(ownerUid: ownerUid, walkId: nil, name: nil)
        }
        if final == .arrived {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Numbers for the screen

    private var secondsPerMeter: Double {
        guard let route = session?.route, route.distance > 0 else { return 0.75 }
        return route.expectedTravelTime / route.distance
    }

    var minutesLeft: Int {
        max(1, Int((remainingMeters * secondsPerMeter / 60).rounded(.up)))
    }

    var arrivalTime: Date {
        now.addingTimeInterval(remainingMeters * secondsPerMeter)
    }

    /// The next turn: its text and how far away it is
    var nextStep: (text: String, meters: Double)? {
        guard let route = session?.route else { return nil }
        let traveled = max(0, route.distance - remainingMeters)
        var start = 0.0
        for step in route.steps {
            if !step.instructions.isEmpty, start > traveled + 1 {
                return (step.instructions, start - traveled)
            }
            start += step.distance
        }
        return nil
    }

    // MARK: - Messages the user sends from their own phone

    func shareText(_ kind: ShareKind) -> String {
        guard let session else { return "" }
        let link = AppConfig.walkLink(session.id)
        let place = session.destinationName
        let arrive = arrivalTime.formatted(date: .omitted, time: .shortened)

        switch kind {
        case .started:
            return "I'm starting a walk to \(place) and expect to arrive around \(arrive). "
                + "Follow my live location here: \(link)"
        case .missedCheckIn:
            return "I missed my SafeWalk check-in on my walk to \(place). Please try to reach me. "
                + "Live link: \(link)" + mapsLine
        case .arrived:
            return "I've arrived safely at \(place). Thanks for keeping an eye on me."
        case .sos:
            return "SOS! I need help on my walk to \(place). Please call me and come if you can. "
                + "Live location: \(link)" + mapsLine
        case .falseAlarm:
            return "False alarm: I'm okay. Sorry for the scare, please ignore my earlier SOS."
        }
    }

    private var mapsLine: String {
        guard let c = current?.coordinate else { return "" }
        return String(format: "\nMap: https://maps.apple.com/?ll=%.5f,%.5f", c.latitude, c.longitude)
    }
}

