---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-09
updated: 2026-03-16
---

# E2E Phase 0 Completed Surface Index

이 문서는 phase 0 `e2e` surface 중 `done` 상태 문서를 target별로 묶어 보여준다.
세부 inventory, assertion scope, PR gate, deferred lane의 source of truth는 각 개별 `done` TODO 문서다.
현재 열려 있는 backlog는 [101 E2E Phase 0 Open Page Backlog Index](101-ready-p2-e2e-phase0-page-backlog-index.md)에서 관리한다.

## DUNE Today / Settings

- [022 DashboardView](022-done-p2-e2e-dune-dashboard-view.md)
- [023 ConditionScoreDetailView](023-done-p2-e2e-dune-condition-score-detail-view.md)
- [024 MetricDetailView](024-done-p2-e2e-dune-metric-detail-view.md)
- [025 AllDataView](025-done-p2-e2e-dune-all-data-view.md)
- [026 WeatherDetailView](026-done-p2-e2e-dune-weather-detail-view.md)
- [027 NotificationHubView](027-done-p2-e2e-dune-notification-hub-view.md)
- [028 SettingsView](028-done-p2-e2e-dune-settings-view.md)
- [029 WhatsNewView](029-done-p2-e2e-dune-whats-new-view.md)
- [030 PinnedMetricsEditorView](030-done-p2-e2e-dune-pinned-metrics-editor-view.md)
- [031 CloudSyncConsentView](031-done-p2-e2e-dune-cloud-sync-consent-view.md)

## DUNE Activity / Exercise

- [043 MuscleMapDetailView](043-done-p2-e2e-dune-muscle-map-detail-view.md)
- [044 MuscleMap3DView](044-done-p2-e2e-dune-muscle-map-3d-view.md)
- [045 ExercisePickerView](045-done-p2-e2e-dune-exercise-picker-view.md)

## DUNE Wellness / Life

- [065 WellnessView](065-done-p2-e2e-dune-wellness-view.md)
- [066 WellnessScoreDetailView](066-done-p2-e2e-dune-wellness-score-detail-view.md)
- [067 BodyHistoryDetailView](067-done-p2-e2e-dune-body-history-detail-view.md)
- [068 InjuryHistoryView](068-done-p2-e2e-dune-injury-history-view.md)
- [069 InjuryStatisticsView](069-done-p2-e2e-dune-injury-statistics-view.md)
- [070 BodyCompositionFormSheet](070-done-p2-e2e-dune-body-composition-form-sheet.md)
- [071 InjuryFormSheet](071-done-p2-e2e-dune-injury-form-sheet.md)
- [072 LifeView](072-done-p2-e2e-dune-life-view.md)
- [073 HabitFormSheet](073-done-p2-e2e-dune-habit-form-sheet.md)
- [074 HabitHistorySheet](074-done-p2-e2e-dune-habit-history-sheet.md)

## DUNEWatch

- [075 CarouselHomeView](075-done-p2-e2e-dunewatch-carousel-home-view.md)
- [076 QuickStartAllExercisesView](076-done-p2-e2e-dunewatch-quick-start-all-exercises-view.md)
- [077 WorkoutPreviewView](077-done-p2-e2e-dunewatch-workout-preview-view.md)
- [078 SessionPagingView](078-done-p2-e2e-dunewatch-session-paging-view.md)
- [079 MetricsView](079-done-p2-e2e-dunewatch-metrics-view.md)
- [080 ControlsView](080-done-p2-e2e-dunewatch-controls-view.md)
- [081 RestTimerView](081-done-p2-e2e-dunewatch-rest-timer-view.md)
- [082 SetInputSheet](082-done-p2-e2e-dunewatch-set-input-sheet.md)
- [083 SessionSummaryView](083-done-p2-e2e-dunewatch-session-summary-view.md)

## DUNEVision Deferred

- [084 VisionContentView](084-done-p3-e2e-dunevision-content-view.md)
- [085 VisionDashboardView](085-done-p3-e2e-dunevision-dashboard-view.md)
- [086 VisionTrainView](086-done-p3-e2e-dunevision-train-view.md)
- [087 VisionDashboardWindowScene](087-done-p3-e2e-dunevision-dashboard-window-scene.md)
- [088 Chart3DContainerView](088-done-p3-e2e-dunevision-chart3d-container-view.md)
- [089 VisionVolumetricExperienceView](089-done-p3-e2e-dunevision-volumetric-experience-view.md)
- [090 VisionImmersiveExperienceView](090-done-p3-e2e-dunevision-immersive-experience-view.md)
- [091 VisionPlaceholderSurfaces](091-done-p3-e2e-dunevision-placeholder-surfaces.md)

## DUNEWidget Deferred

- [092 SmallWidgetView](092-done-p3-e2e-dunewidget-small-widget-view.md)
- [093 MediumWidgetView](093-done-p3-e2e-dunewidget-medium-widget-view.md)
- [094 LargeWidgetView](094-done-p3-e2e-dunewidget-large-widget-view.md)
- [095 WidgetPlaceholderStates](095-done-p3-e2e-dunewidget-placeholder-states.md)

## Notes

- 개별 완료 문서는 삭제하지 않는다. 상세 내용은 각 `done` TODO에서 유지한다.
- 새 surface가 완료되면 active backlog index에서 제거한 뒤 이 문서에 추가한다.
- `DUNEWidget` deferred surface 4건도 이 문서로 이동했으며, 후속 snapshot/preview lane은 별도 TODO로 계속 관리한다.
