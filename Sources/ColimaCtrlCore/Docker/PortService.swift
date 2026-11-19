import Foundation

public struct PortMapping: Equatable, Hashable, Sendable {
    public let host: Int
    public let container: Int
    public let proto: String

    public var service: KnownPort? { KnownPort.lookup(containerPort: container) }
    /// Unknown ports open in the browser, the same as before they were labeled.
    public var opensInBrowser: Bool { service?.opensInBrowser ?? true }
}

public struct KnownPort: Equatable, Sendable {
    public let name: String
    public let opensInBrowser: Bool

    public static func lookup(containerPort: Int) -> KnownPort? {
        table[containerPort]
    }

    private static let table: [Int: KnownPort] = [
        80: .web("Web"), 443: .web("Web (HTTPS)"), 3000: .web("Web"), 4200: .web("Web"), 5000: .web("Web"), 5001: .web("Web (HTTPS)"),
        5173: .web("Web"), 8000: .web("Web"), 8080: .web("Web"), 8081: .web("Web"), 8443: .web("Web (HTTPS)"), 8888: .web("Web"),
        9090: .web("Prometheus"), 3100: .web("Loki API"), 3200: .web("Tempo API"), 15672: .web("RabbitMQ management"),
        1433: .other("SQL Server"), 1521: .other("Oracle"), 3306: .other("MySQL"), 5432: .other("PostgreSQL"), 6379: .other("Redis"),
        27017: .other("MongoDB"), 9042: .other("Cassandra"), 11211: .other("Memcached"), 5672: .other("RabbitMQ (AMQP)"),
        9092: .other("Kafka"), 2181: .other("ZooKeeper"), 4222: .other("NATS"), 22: .other("SSH"),
        5005: .other("Debugger"), 9229: .other("Node debugger"),
        10000: .other("Azure Blob storage"), 10001: .other("Azure Queue storage"), 10002: .other("Azure Table storage"),
    ]

    private static func web(_ name: String) -> KnownPort { KnownPort(name: name, opensInBrowser: true) }
    private static func other(_ name: String) -> KnownPort { KnownPort(name: name, opensInBrowser: false) }
}
