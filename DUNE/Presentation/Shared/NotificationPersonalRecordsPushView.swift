import SwiftUI

struct NotificationPersonalRecordsPushView: View {
    @State private var viewModel: ActivityViewModel

    init(sharedHealthDataService: SharedHealthDataService?) {
        _viewModel = State(initialValue: ActivityViewModel(sharedHealthDataService: sharedHealthDataService))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.personalRecords.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background { DetailWaveBackground() }
                    .englishNavigationTitle("Personal Records")
            } else {
                PersonalRecordsDetailView(
                    records: viewModel.personalRecords,
                    notice: viewModel.personalRecordNotice,
                    rewardSummary: viewModel.workoutRewardSummary,
                    rewardHistory: viewModel.workoutRewardHistory
                )
            }
        }
        .task {
            await viewModel.loadActivityData()
        }
    }
}
