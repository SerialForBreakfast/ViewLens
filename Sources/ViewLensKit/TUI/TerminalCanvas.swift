import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// ANSI terminal controller for full-screen and streaming Terminal User Interface (TUI) rendering.
public final class TerminalCanvas: @unchecked Sendable {
    public static let shared = TerminalCanvas()

    #if canImport(Darwin)
    private var originalTermios = termios()
    private var isRawModeActive = false
    #endif

    public init() {}

    // MARK: - Screen Buffer Management

    public func enterAlternateScreen() {
        print("\u{001B}[?1049h\u{001B}[H\u{001B}[?25l", terminator: "")
        fflush(stdout)
    }

    public func exitAlternateScreen() {
        print("\u{001B}[?25h\u{001B}[?1049l", terminator: "")
        fflush(stdout)
    }

    public func clearScreen() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        fflush(stdout)
    }

    public func moveCursor(row: Int, col: Int) {
        print("\u{001B}[\(row);\(col)H", terminator: "")
    }

    // MARK: - Raw Mode for Non-Blocking Keyboard Input

    #if canImport(Darwin)
    public func enableRawMode() {
        guard !isRawModeActive else { return }
        tcgetattr(STDIN_FILENO, &originalTermios)
        var raw = originalTermios
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
        raw.c_cc.16 = 0 // VMIN = 0
        raw.c_cc.17 = 1 // VTIME = 1 (100ms timeout)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        isRawModeActive = true
    }

    public func disableRawMode() {
        guard isRawModeActive else { return }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        isRawModeActive = false
    }

    public func readKey() -> Character? {
        var charBuffer: UInt8 = 0
        let bytesRead = read(STDIN_FILENO, &charBuffer, 1)
        if bytesRead > 0 {
            return Character(UnicodeScalar(charBuffer))
        }
        return nil
    }
    #endif

    // MARK: - Terminal Geometry

    public func getTerminalSize() -> (columns: Int, rows: Int) {
        #if canImport(Darwin)
        var ws = winsize()
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0 && ws.ws_col > 0 {
            return (Int(ws.ws_col), Int(ws.ws_row))
        }
        #endif
        return (80, 24) // Standard default fallback
    }

    // MARK: - ANSI Styling Helpers

    public static func styled(_ text: String, color: ANSIColor = .default, bold: Bool = false) -> String {
        let boldPrefix = bold ? "\u{001B}[1m" : ""
        return "\(boldPrefix)\(color.escapeCode)\(text)\u{001B}[0m"
    }

    public enum ANSIColor: Sendable {
        case `default`
        case red
        case green
        case yellow
        case blue
        case magenta
        case cyan
        case gray

        public var escapeCode: String {
            switch self {
            case .default: return "\u{001B}[39m"
            case .red: return "\u{001B}[31m"
            case .green: return "\u{001B}[32m"
            case .yellow: return "\u{001B}[33m"
            case .blue: return "\u{001B}[34m"
            case .magenta: return "\u{001B}[35m"
            case .cyan: return "\u{001B}[36m"
            case .gray: return "\u{001B}[90m"
            }
        }
    }
}
