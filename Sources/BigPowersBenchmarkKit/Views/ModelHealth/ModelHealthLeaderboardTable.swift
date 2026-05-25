import SwiftUI

struct ModelHealthLeaderboardTable<ModelCell: View>: View {
    enum Mode {
        case liveCost
        case liveReason
        case history
    }

    let rows: [ModelHealthTableRow]
    let maxP50: Double
    let tokens: ThemeTokens
    let mode: Mode
    @Binding var columnCustomization: TableColumnCustomization<ModelHealthTableRow>
    @ViewBuilder let modelCell: (ModelHealthTableRow) -> ModelCell

    private func modelColumnWithRank(_ row: ModelHealthTableRow) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if let rank = row.rank {
                Text("\(rank)")
                    .fontWeight(.bold)
                    .foregroundColor(tokens.fg)
                    .frame(width: 28, alignment: .trailing)
            }
            modelCell(row)
        }
    }

    var body: some View {
        switch mode {
        case .liveCost:
            liveCostTable
        case .liveReason:
            liveReasonTable
        case .history:
            historyTable
        }
    }

    private var liveCostTable: some View {
        Table(rows, columnCustomization: $columnCustomization) {
            TableColumn("Bench?") { (row: ModelHealthTableRow) in
                BenchSuitabilityBadge(suitability: row.suitability, tokens: tokens)
            }
            .width(min: 72, ideal: 88, max: 110)
            .customizationID(ModelHealthColumnLayout.ColumnID.bench)

            TableColumn("Latency") { (row: ModelHealthTableRow) in
                LatencyCell(p50: row.p50, maxP50: maxP50, tokens: tokens)
            }
            .width(min: 130, ideal: 170, max: 220)
            .customizationID(ModelHealthColumnLayout.ColumnID.latency)

            TableColumn("Free") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.isFree, tooltip: "Free tier model", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.free)

            TableColumn("Ctx") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.hasContext, tooltip: "Context window ≥ 32K", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.ctx)

            TableColumn("Clear") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.notContentFiltered, tooltip: "Not content-filtered", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.clear)

            TableColumn("Tools") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.hasTools, tooltip: "Tool calling supported", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.tools)

            TableColumn("Rsp") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.responded, tooltip: "Got a response (latency recorded)", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.rsp)

            TableColumn("Match") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.modelMatched, tooltip: "Responded model matches request", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.match)

            TableColumn("cost") { (row: ModelHealthTableRow) in
                Text(String(format: "$%.4f", row.cost))
                    .foregroundColor(tokens.fg3)
            }
            .width(min: 72, ideal: 88, max: 110)
            .customizationID(ModelHealthColumnLayout.ColumnID.cost)

            TableColumn("Model") { (row: ModelHealthTableRow) in
                modelColumnWithRank(row)
            }
            .width(min: 220, ideal: 360, max: CGFloat.infinity)
            .customizationID(ModelHealthColumnLayout.ColumnID.model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var liveReasonTable: some View {
        Table(rows, columnCustomization: $columnCustomization) {
            TableColumn("Bench?") { (row: ModelHealthTableRow) in
                BenchSuitabilityBadge(suitability: row.suitability, tokens: tokens)
            }
            .width(min: 72, ideal: 88, max: 110)
            .customizationID(ModelHealthColumnLayout.ColumnID.bench)

            TableColumn("Latency") { (row: ModelHealthTableRow) in
                LatencyCell(p50: row.p50, maxP50: maxP50, tokens: tokens)
            }
            .width(min: 130, ideal: 170, max: 220)
            .customizationID(ModelHealthColumnLayout.ColumnID.latency)

            TableColumn("Free") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.isFree, tooltip: "Free tier model", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.free)

            TableColumn("Ctx") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.hasContext, tooltip: "Context window ≥ 32K", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.ctx)

            TableColumn("Clear") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.notContentFiltered, tooltip: "Not content-filtered", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.clear)

            TableColumn("Tools") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.hasTools, tooltip: "Tool calling supported", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.tools)

            TableColumn("Rsp") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.responded, tooltip: "Got a response (latency recorded)", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.rsp)

            TableColumn("Match") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.modelMatched, tooltip: "Responded model matches request", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.match)

            TableColumn("reason") { (row: ModelHealthTableRow) in
                Text(row.reasoningTokens > 0 ? "\(row.reasoningTokens)" : "—")
                    .foregroundColor(tokens.warn)
            }
            .width(min: 72, ideal: 88, max: 110)
            .customizationID(ModelHealthColumnLayout.ColumnID.reason)

            TableColumn("Model") { (row: ModelHealthTableRow) in
                modelColumnWithRank(row)
            }
            .width(min: 220, ideal: 360, max: CGFloat.infinity)
            .customizationID(ModelHealthColumnLayout.ColumnID.model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyTable: some View {
        Table(rows, columnCustomization: $columnCustomization) {
            TableColumn("Bench?") { (row: ModelHealthTableRow) in
                BenchSuitabilityBadge(suitability: row.suitability, tokens: tokens)
            }
            .width(min: 72, ideal: 88, max: 110)
            .customizationID(ModelHealthColumnLayout.ColumnID.bench)

            TableColumn("Latency") { (row: ModelHealthTableRow) in
                LatencyCell(p50: row.p50, maxP50: maxP50, tokens: tokens)
            }
            .width(min: 130, ideal: 170, max: 220)
            .customizationID(ModelHealthColumnLayout.ColumnID.latency)

            TableColumn("Free") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.isFree, tooltip: "Free tier model", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.free)

            TableColumn("Ctx") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.hasContext, tooltip: "Context window ≥ 32K", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.ctx)

            TableColumn("Clear") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.notContentFiltered, tooltip: "Not content-filtered", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.clear)

            TableColumn("Tools") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.hasTools, tooltip: "Tool calling supported", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.tools)

            TableColumn("Rsp") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.responded, tooltip: "Got a response (latency recorded)", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.rsp)

            TableColumn("Match") { (row: ModelHealthTableRow) in
                SignalCell(pass: row.modelMatched, tooltip: "Responded model matches request", tokens: tokens)
            }
            .width(min: 44, ideal: 52, max: 60)
            .customizationID(ModelHealthColumnLayout.ColumnID.match)

            TableColumn("cost") { (row: ModelHealthTableRow) in
                Text(String(format: "$%.4f", row.cost))
                    .foregroundColor(tokens.fg3)
            }
            .width(min: 72, ideal: 88, max: 110)
            .customizationID(ModelHealthColumnLayout.ColumnID.cost)

            TableColumn("Model") { (row: ModelHealthTableRow) in
                modelCell(row)
            }
            .width(min: 220, ideal: 360, max: CGFloat.infinity)
            .customizationID(ModelHealthColumnLayout.ColumnID.model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension ModelHealthTableRow {
    static func from(
        result: ModelHealthPingResult,
        rank: Int?,
        registry: [ModelInfo],
        maxP50: Double
    ) -> ModelHealthTableRow {
        let info = registry.first { $0.id == result.id }
        let suitability = info.map {
            BenchRankScore.compute(info: $0, pingResult: result, maxP50: maxP50).suitability
        } ?? .notSuitable
        return ModelHealthTableRow(
            id: result.id,
            label: result.label,
            rank: rank,
            p50: result.p50,
            cost: result.cost,
            reasoningTokens: result.reasoningTokens,
            responded: result.responded,
            modelMatched: result.modelMatched,
            notContentFiltered: result.notContentFiltered,
            hasTools: info?.capabilities.contains(.tools) ?? false,
            isFree: ModelHealthFreeTier.isFree(catalog: info, pingResult: result),
            hasContext: (info?.contextWindow ?? 0) >= 32000,
            suitability: suitability
        )
    }

    static func from(snapshotRow: SnapshotRow) -> ModelHealthTableRow {
        ModelHealthTableRow(
            id: snapshotRow.modelId,
            label: snapshotRow.label,
            rank: nil,
            p50: snapshotRow.p50,
            cost: snapshotRow.cost,
            reasoningTokens: 0,
            responded: snapshotRow.responded,
            modelMatched: snapshotRow.modelMatched,
            notContentFiltered: snapshotRow.notContentFiltered,
            hasTools: snapshotRow.hasTools,
            isFree: snapshotRow.isFree,
            hasContext: snapshotRow.hasContext,
            suitability: ModelHealthSnapshot.suitability(from: snapshotRow.suitability)
        )
    }
}
