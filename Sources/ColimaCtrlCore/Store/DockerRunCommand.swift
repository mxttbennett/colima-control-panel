import Foundation

public enum DockerRunCommand {
    /// A `docker run` command that recreates the container's image, ports, mounts, environment, network, restart policy and limits.
    public static func make(name: String, inspect: ContainerInspect) -> String {
        var lines = ["docker run -d", "--name \(ShellCommand.quote(name))"]
        if inspect.restartPolicy != "no" { lines.append("--restart \(inspect.restartPolicy)") }
        if let network = inspect.attachments.first?.network, network != "bridge" { lines.append("--network \(ShellCommand.quote(network))") }
        if let memory = inspect.memoryLimit { lines.append("--memory \(memory)") }
        if let cpus = inspect.cpuLimit { lines.append("--cpus \(cpus.formatted(.number.grouping(.never)))") }
        for port in inspect.ports { lines.append("-p \(port.host):\(port.container)") }
        for mount in inspect.mounts {
            lines.append("-v \(ShellCommand.quote("\(mount.source):\(mount.destination)" + (mount.readOnly ? ":ro" : "")))")
        }
        for variable in inspect.env where variable.key != "PATH" {
            lines.append("-e \(ShellCommand.quote("\(variable.key)=\(variable.value)"))")
        }
        lines.append(ShellCommand.quote(inspect.image))
        return lines.enumerated().map { index, line in
            index == 0 ? line + " \\" : index == lines.count - 1 ? "  " + line : "  " + line + " \\"
        }.joined(separator: "\n")
    }
}
