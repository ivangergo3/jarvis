import Foundation

/// One bounded, ephemeral authority session. Restart requires fresh host authorization.
public actor AuthoritySession {
    private struct Entry {
        let proposal: ActionProposal
        let grant: UUID?
        var state: ActionState
    }
    private let grants: [UUID: ActionGrant]
    private let resources: [UUID: ActionResource]
    private let tool: any ActionTool
    private let clock: @Sendable () -> Date
    private var revoked = Set<UUID>()
    private var calls: [UUID: Int] = [:]
    private var spent: [UUID: Int] = [:]
    private var entries: [UUID: Entry] = [:]
    private var audit: [AuthorityAudit] = []
    private var connected = true
    private let capacity: Int

    public init(
        grants: [ActionGrant], resources: [ActionResource], tool: any ActionTool,
        capacity: Int = 128, clock: @escaping @Sendable () -> Date = { Date() }
    ) throws {
        guard (1...1024).contains(capacity), grants.count <= 128, resources.count <= 128,
            Set(grants.map(\.id)).count == grants.count,
            Set(resources.map(\.id)).count == resources.count,
            grants.allSatisfy({
                (1...1024).contains($0.calls) && $0.spendLimit >= 0 && !$0.resources.isEmpty
                    && ($0.kind == .spend
                        ? $0.currency != nil : $0.currency == nil && $0.spendLimit == 0)
            }),
            resources.allSatisfy({ $0.content.utf8.count <= 65_536 })
        else { throw AuthorityFailure.invalidConfiguration }
        self.grants = Dictionary(uniqueKeysWithValues: grants.map { ($0.id, $0) })
        self.resources = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })
        self.tool = tool
        self.capacity = capacity
        self.clock = clock
    }

    public func propose(_ proposal: ActionProposal) throws -> ActionState {
        if let existing = entries[proposal.id] {
            guard existing.proposal == proposal else { throw AuthorityFailure.identityConflict }
            return existing.state
        }
        guard entries.count < capacity else { throw AuthorityFailure.capacity }
        let grant = grants.values.sorted { $0.id.uuidString < $1.id.uuidString }.first {
            permits($0, proposal)
        }
        let state: ActionState =
            !connected || grant == nil
            ? .denied : (grant?.requiresApproval == true ? .awaitingApproval : .ready)
        entries[proposal.id] = Entry(proposal: proposal, grant: grant?.id, state: state)
        record(proposal.id, state)
        return state
    }

    /// Only the trusted host holds this interface; it is absent from the proposal schema.
    public func decide(_ id: UUID, approve: Bool) -> ActionState? {
        guard let entry = entries[id], entry.state == .awaitingApproval else {
            return entries[id]?.state
        }
        let stillAllowed =
            entry.grant.flatMap { grants[$0] }.map { permits($0, entry.proposal) } ?? false
        record(id, approve && connected && stillAllowed ? .ready : .denied)
        return entries[id]?.state
    }

    public func execute(_ id: UUID) async -> ActionState? {
        guard let entry = entries[id], entry.state == .ready else { return entries[id]?.state }
        if Task.isCancelled {
            record(id, .cancelled)
            return .cancelled
        }
        guard connected, let grantID = entry.grant, let grant = grants[grantID],
            permits(grant, entry.proposal), let resource = resources[entry.proposal.resource]
        else {
            record(id, .denied)
            return .denied
        }
        // Reserve before suspension. Unknown/rejected outcomes never replenish authority automatically.
        calls[grantID, default: 0] += 1
        spent[grantID, default: 0] += entry.proposal.amount
        record(id, .dispatched)
        do {
            let receipt = try await tool.execute(entry.proposal, resource: resource)
            guard entries[id]?.state == .dispatched else { return entries[id]?.state }
            if Task.isCancelled || receipt.proposal != entry.proposal {
                record(id, .uncertain)
            } else {
                record(id, receipt.accepted ? .succeeded : .rejected)
            }
        } catch { recordIfDispatched(id, .uncertain) }
        return entries[id]?.state
    }

    public func cancel(_ id: UUID) {
        guard let state = entries[id]?.state else { return }
        if [.ready, .awaitingApproval].contains(state) { record(id, .cancelled) }
        if state == .dispatched { record(id, .uncertain) }
    }

    public func revoke(_ grant: UUID) {
        revoked.insert(grant)
        for entry in Array(entries.values) where entry.grant == grant { cancel(entry.proposal.id) }
    }

    public func disconnect() {
        connected = false
        for id in Array(entries.keys) { cancel(id) }
    }

    public func reconcile(_ id: UUID) async -> ActionState? {
        guard let entry = entries[id], entry.state == .uncertain else { return entries[id]?.state }
        do {
            if let receipt = try await tool.lookup(id), receipt.proposal == entry.proposal,
                entries[id]?.state == .uncertain
            {
                record(id, receipt.accepted ? .succeeded : .rejected)
            }
        } catch { return entries[id]?.state }
        return entries[id]?.state
    }

    public func state(_ id: UUID) -> ActionState? { entries[id]?.state }
    public func auditTrail() -> [AuthorityAudit] { audit }

    private func permits(_ grant: ActionGrant, _ proposal: ActionProposal) -> Bool {
        guard !revoked.contains(grant.id), clock() < grant.expiresAt,
            grant.kind == proposal.kind, grant.destination == proposal.destination,
            grant.resources.contains(proposal.resource), calls[grant.id, default: 0] < grant.calls,
            let resource = resources[proposal.resource], resource.classification != .credential,
            !proposal.kind.exportsData || resource.classification == .publicData,
            proposal.amount >= 0,
            proposal.currency == grant.currency,
            proposal.kind == .spend
                ? proposal.amount > 0 : proposal.amount == 0 && proposal.currency == nil
        else { return false }
        return proposal.amount <= grant.spendLimit - spent[grant.id, default: 0]
    }

    private func recordIfDispatched(_ id: UUID, _ state: ActionState) {
        if entries[id]?.state == .dispatched { record(id, state) }
    }

    private func record(_ id: UUID, _ state: ActionState) {
        guard var entry = entries[id] else { return }
        entry.state = state
        entries[id] = entry
        audit.append(AuthorityAudit(request: id, kind: entry.proposal.kind, state: state))
        if audit.count > 256 { audit.removeFirst(audit.count - 256) }
    }
}
