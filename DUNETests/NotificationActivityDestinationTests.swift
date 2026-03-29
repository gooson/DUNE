import Testing
@testable import DUNE

@Suite("NotificationActivityDestination")
struct NotificationActivityDestinationTests {
    @Test("repeated personal records routes get unique navigation IDs")
    func repeatedPersonalRecordsRoutesGetUniqueIDs() {
        let first = NotificationActivityDestination(destination: .personalRecords(), requestID: 1)
        let second = NotificationActivityDestination(destination: .personalRecords(), requestID: 2)

        #expect(first.id != second.id)
    }

    @Test("same request keeps stable navigation ID")
    func sameRequestKeepsStableID() {
        let first = NotificationActivityDestination(destination: .exerciseMix, requestID: 7)
        let second = NotificationActivityDestination(destination: .exerciseMix, requestID: 7)

        #expect(first.id == second.id)
    }
}
