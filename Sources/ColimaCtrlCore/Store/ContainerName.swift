import Foundation

public enum ContainerName {
    /// Why `name` cannot be used for a container, or nil when Docker will accept it.
    public static func problem(with name: String, current: String, others: [String]) -> String? {
        guard name.count >= 2 else { return "Use at least 2 characters." }
        guard name.first?.isASCII == true, name.first?.isLetter == true || name.first?.isNumber == true else { return "Start with a letter or number." }
        guard name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "_.-".contains($0)) }) else {
            return "Use only letters, numbers, underscores, periods and hyphens."
        }
        if name == current { return "That is already its name." }
        if others.contains(name) { return "Another container already uses that name." }
        return nil
    }
}
