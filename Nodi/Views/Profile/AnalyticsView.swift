import SwiftUI
import Charts

struct AnalyticsView: View {
    let user: NodiUser
    @StateObject private var viewModel = AnalyticsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NodiSpacing.lg) {
                    profileSection
                    portfolioSection
                }
                .padding(NodiSpacing.lg)
            }
            .background(NodiColor.background)
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if let uid = user.id {
                    await viewModel.load(ownerId: uid)
                }
            }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: NodiSpacing.sm) {
            Text("Profile").font(NodiFont.title2())
            HStack(spacing: NodiSpacing.md) {
                MetricCard(value: user.profileViewCount, label: "Profile Views", icon: "eye")
                MetricCard(value: user.connectionCount, label: "Connections", icon: "person.2")
                MetricCard(value: user.followerCount, label: "Followers", icon: "person.crop.circle.badge.checkmark")
            }
        }
    }

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: NodiSpacing.sm) {
            Text("Portfolio").font(NodiFont.title2())

            HStack(spacing: NodiSpacing.md) {
                MetricCard(value: viewModel.projects.count, label: "Projects", icon: "square.grid.2x2")
                MetricCard(value: viewModel.totalProjectViews, label: "Total Views", icon: "chart.bar")
            }

            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if !viewModel.projects.isEmpty {
                NodiCard {
                    Chart(viewModel.projects.prefix(8)) { project in
                        BarMark(
                            x: .value("Views", project.viewCount),
                            y: .value("Project", project.title.isEmpty ? "Untitled" : project.title)
                        )
                        .foregroundStyle(NodiColor.accent)
                        .cornerRadius(4)
                    }
                    .frame(height: CGFloat(min(viewModel.projects.count, 8)) * 36 + 20)
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(NodiColor.divider)
                            AxisValueLabel().foregroundStyle(NodiColor.secondaryText)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisValueLabel().foregroundStyle(NodiColor.secondaryText)
                        }
                    }
                }
            }
        }
    }
}

private struct MetricCard: View {
    let value: Int
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: NodiSpacing.xs) {
            Image(systemName: icon).foregroundStyle(NodiColor.accent)
            Text("\(value)").font(NodiFont.title2())
            Text(label).font(NodiFont.caption()).foregroundStyle(NodiColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NodiSpacing.sm)
        .background(NodiColor.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: NodiRadius.sm, style: .continuous))
    }
}
