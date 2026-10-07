import Foundation
import Testing
@testable import DUNE

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

    @Test("Default duration is 30 seconds")
    func defaultDuration() {
        let vm = RestTimerViewModel()
        #expect(vm.defaultDuration == 30)
    }
    @Test("Background suspension uses elapsed wall time and completes only once")
    func suspendedCountdown() {
        var now = Date(timeIntervalSince1970: 1000)
        let vm = RestTimerViewModel(now: { now })
        vm.start(seconds: 90)
        now.addTimeInterval(75)
        vm.refresh()
        #expect(vm.secondsRemaining == 15)
        now.addTimeInterval(100)
        vm.refresh()
        vm.refresh()
        #expect(vm.secondsRemaining == 0)
        #expect(vm.completionCount == 1)
        #expect(!vm.isRunning)
    }

    @Test("Extending rest preserves elapsed time and bounds progress")
    func extendedCountdown() {
        var now = Date(timeIntervalSince1970: 1000)
        let vm = RestTimerViewModel(now: { now })
        vm.start(seconds: 60)
        now.addTimeInterval(20)
        vm.addTime(30)
        #expect(vm.secondsRemaining == 70)
        #expect(vm.defaultDuration == 90)
        #expect((0...1).contains(vm.progress))
        vm.stop()
    }

    @Test("Restore expired deadline completes without restarting a full rest")
    func restoreExpired() {
        let now = Date(timeIntervalSince1970: 1000)
        let vm = RestTimerViewModel(now: { now })
        vm.restore(endDate: now.addingTimeInterval(-1), totalDuration: 90)
        #expect(vm.completionCount == 1)
        #expect(vm.secondsRemaining == 0)
    }

    @Test("Extreme duration and extension remain bounded")
    func durationBounds() {
        let vm = RestTimerViewModel()
        vm.start(seconds: Int.max)
        vm.addTime(Int.max)
        #expect(vm.secondsRemaining <= 3600)
        vm.addTime(Int.min)
        #expect(!vm.isRunning)
        #expect(vm.secondsRemaining == 0)
    }

    @Test("Restore clamps a malformed future deadline to the total duration")
    func restoreFutureDeadline() {
        let now = Date(timeIntervalSince1970: 1000)
        let vm = RestTimerViewModel(now: { now })
        vm.restore(endDate: now.addingTimeInterval(100_000), totalDuration: 90)
        #expect(vm.secondsRemaining == 90)
        #expect(vm.endDate == now.addingTimeInterval(90))
        vm.stop()
    }

}
