import Foundation
import Testing
@testable import Dailve

@Suite("RestTimerViewModel")
@MainActor
struct RestTimerViewModelTests {
    @Test("Initial state is not running")
    func initialState() {
        let vm = RestTimerViewModel()
        #expect(!vm.isRunning)
        #expect(vm.secondsRemaining == 0)
    }

    @Test("Start sets isRunning and secondsRemaining")
    func start() {
        let vm = RestTimerViewModel()
        vm.start(seconds: 90)
        #expect(vm.isRunning)
        #expect(vm.secondsRemaining == 90)
    }

    @Test("Stop sets isRunning to false")
    func stop() {
        let vm = RestTimerViewModel()
        vm.start(seconds: 90)
        vm.stop()
        #expect(!vm.isRunning)
    }

    @Test("addTime increases remaining seconds")
    func addTime() {
        let vm = RestTimerViewModel()
        vm.start(seconds: 60)
        vm.addTime(30)
        #expect(vm.secondsRemaining == 90)
    }

    @Test("formattedTime shows mm:ss format")
    func formattedTime() {
        let vm = RestTimerViewModel()
        vm.start(seconds: 90)
        #expect(vm.formattedTime == "1:30")
    }

    @Test("formattedTime shows 0:00 when not running")
    func formattedTimeNotRunning() {
        let vm = RestTimerViewModel()
        #expect(vm.formattedTime == "0:00")
    }

    @Test("progress is 0 at start (full remaining)")
    func progressStart() {
        let vm = RestTimerViewModel()
        vm.start(seconds: 60)
        // progress = 1.0 - (60/60) = 0.0 (inverted: 0 = just started, 1 = done)
        #expect(vm.progress == 0.0)
    }

    @Test("Default duration is 90 seconds")
    func defaultDuration() {
        let vm = RestTimerViewModel()
        #expect(vm.defaultDuration == 90)
    }
}
