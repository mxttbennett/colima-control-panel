import Foundation

public enum ShellCommand {
    public static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    /// A `.command` script that opens a shell in the container, preferring bash and falling back to sh.
    public static func dockerExecScript(socketPath: String, containerID: String) -> String {
        let id = quote(containerID)
        return """
        #!/bin/zsh
        export DOCKER_HOST=\(quote("unix://" + socketPath))
        docker exec -it \(id) sh -c 'command -v bash >/dev/null 2>&1 && exec bash || exec sh'
        """
    }
}
