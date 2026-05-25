@testable import BigPowersBenchmarkKit
import Testing

@Suite("HostRunModelResolver")
struct HostRunModelResolverTests {
    @Test("resolves OpenCode catalog ID to provider/model slug")
    func opencodeCatalogId() throws {
        let model = StaticModelCatalogs.opencodeModel(
            id: "opencode/big-pickle",
            name: "Big Pickle"
        )
        let slug = try HostRunModelResolver.opencodeModelSlug(
            catalogModelId: model.id,
            catalog: [model]
        )
        #expect(slug == "opencode/big-pickle")
    }

    @Test("resolves via intel profile modelAlias")
    func profileAlias() throws {
        let profile = ModelIntelProfile(
            modelId: "opencode:opencode/nemotron-3-super-free",
            label: "Nemotron",
            modelAlias: "opencode/nemotron-3-super-free",
            pingTransport: PingTransport.openCode.rawValue
        )
        let slug = try HostRunModelResolver.opencodeModelSlug(
            catalogModelId: profile.modelId,
            profile: profile
        )
        #expect(slug == "opencode/nemotron-3-super-free")
    }

    @Test("rejects Claude CLI transport in host mode")
    func rejectsClaudeCLI() {
        let model = StaticModelCatalogs.claudeCLIModel(modelArg: "claude-haiku-4-5")
        #expect(throws: RunnerError.self) {
            try HostRunModelResolver.opencodeModelSlug(
                catalogModelId: model.id,
                catalog: [model]
            )
        }
    }

    @Test("hostCompatible filters bench candidates by transport")
    func hostCompatibleFilter() {
        let openCode = ModelIntelProfile(
            modelId: "opencode:opencode/big-pickle",
            label: "Pickle",
            pingTransport: PingTransport.openCode.rawValue,
            benchCandidate: true
        )
        let claude = ModelIntelProfile(
            modelId: "claudecli:claude-haiku-4-5",
            label: "Haiku",
            pingTransport: PingTransport.claudeCLI.rawValue,
            benchCandidate: true
        )
        #expect(HostRunModelResolver.isHostCompatible(profile: openCode))
        #expect(!HostRunModelResolver.isHostCompatible(profile: claude))
    }
}
