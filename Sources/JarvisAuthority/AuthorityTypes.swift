import Foundation

public enum ActionKind: String, Codable, CaseIterable, Sendable {
    case observe, draft, send, publish, spend, delete
    public var exportsData: Bool { [.send, .publish, .spend].contains(self) }
}

public enum SpendCurrency: String, Codable, Sendable { case usd, eur, gbp }

/// IDs refer to host-owned resources. Model input cannot supply content, classification or grants.
public struct ActionProposal: Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: ActionKind
    public let destination: UUID
    public let resource: UUID
    public let amount: Int
    public let currency: SpendCurrency?

    public init(
        id: UUID = UUID(), kind: ActionKind, destination: UUID, resource: UUID, amount: Int = 0,
        currency: SpendCurrency? = nil
    ) {
        self.id = id
        self.kind = kind
        self.destination = destination
        self.resource = resource
        self.amount = amount
        self.currency = currency
    }

    public static func decode(_ data: Data) throws -> ActionProposal {
        guard data.count <= 4096 else { throw AuthorityFailure.invalidProposal }
        do { return try JSONDecoder().decode(Self.self, from: data) } catch {
            throw AuthorityFailure.invalidProposal
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, destination, resource, amount, currency
    }
    private struct Field: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: Field.self)
        guard
            Set(fields.allKeys.map(\.stringValue)).subtracting(["currency"])
                == Set(["id", "kind", "destination", "resource", "amount"])
        else { throw AuthorityFailure.invalidProposal }
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        kind = try values.decode(ActionKind.self, forKey: .kind)
        destination = try values.decode(UUID.self, forKey: .destination)
        resource = try values.decode(UUID.self, forKey: .resource)
        amount = try values.decode(Int.self, forKey: .amount)
        currency = try values.decodeIfPresent(SpendCurrency.self, forKey: .currency)
    }
}

public enum ResourceClassification: Sendable { case publicData, privateData, credential }

public struct ActionResource: Sendable {
    public let id: UUID
    public let classification: ResourceClassification
    public let content: String
    public init(id: UUID, classification: ResourceClassification, content: String) {
        self.id = id
        self.classification = classification
        self.content = content
    }
}

/// Constructed by the trusted host from explicit user authority, never decoded from tool/model text.
public struct ActionGrant: Sendable {
    public let id: UUID
    public let kind: ActionKind
    public let destination: UUID
    public let resources: Set<UUID>
    public let expiresAt: Date
    public let calls: Int
    public let spendLimit: Int
    public let currency: SpendCurrency?
    public let requiresApproval: Bool

    public init(
        id: UUID = UUID(), kind: ActionKind, destination: UUID, resources: Set<UUID>,
        expiresAt: Date, calls: Int = 1, spendLimit: Int = 0, currency: SpendCurrency? = nil,
        requiresApproval: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.destination = destination
        self.resources = resources
        self.expiresAt = expiresAt
        self.calls = calls
        self.spendLimit = spendLimit
        self.currency = currency
        self.requiresApproval = requiresApproval
    }
}

public enum ActionState: String, Codable, Sendable {
    case awaitingApproval, ready, denied, cancelled, dispatched, succeeded, rejected, uncertain
}

public enum AuthorityFailure: Error {
    case invalidProposal, invalidConfiguration, capacity, identityConflict
}

/// An authenticated adapter's structured receipt, not a success claim found in tool output text.
public struct ActionReceipt: Sendable {
    public let proposal: ActionProposal
    public let accepted: Bool
    public init(proposal: ActionProposal, accepted: Bool) {
        self.proposal = proposal
        self.accepted = accepted
    }
}

public protocol ActionTool: Sendable {
    func execute(_ proposal: ActionProposal, resource: ActionResource) async throws -> ActionReceipt
    func lookup(_ id: UUID) async throws -> ActionReceipt?
}

/// Fixed-shape metadata only: no content, destination labels, paths, tokens or raw errors.
public struct AuthorityAudit: Codable, Sendable {
    public let request: UUID
    public let kind: ActionKind
    public let state: ActionState
}
