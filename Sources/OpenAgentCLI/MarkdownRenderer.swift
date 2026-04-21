import Foundation

// MARK: - Markdown Terminal Renderer

/// Lightweight Markdown-to-terminal renderer with ANSI styling.
///
/// Converts common Markdown elements (code blocks, headings, lists, inline
/// bold/code) into terminal-friendly output with box-drawing borders for
/// code blocks and ANSI escape sequences for text styling.
///
/// Designed as a pure function -- `render()` accepts a Markdown string and
/// returns a formatted string. No side effects, no I/O.
enum MarkdownRenderer {

    // MARK: - Public API

    /// Render Markdown text into terminal-formatted output.
    ///
    /// - Parameters:
    ///   - markdown: Raw Markdown string.
    ///   - terminalWidth: Column width used for word-wrapping plain text.
    ///                    Defaults to `terminalWidth()`.
    /// - Returns: ANSI-styled string suitable for terminal display.
    static func render(_ markdown: String, terminalWidth: Int? = nil) -> String {
        guard !markdown.isEmpty else { return "" }

        let width = terminalWidth ?? Self.terminalWidth()
        let blocks = splitIntoBlocks(markdown)

        var results: [String] = []
        for block in blocks {
            let rendered = renderBlock(block, terminalWidth: width)
            results.append(rendered)
        }

        return results.joined(separator: "\n\n")
    }

    /// Cached terminal width — computed once per process invocation.
    private static let cachedTerminalWidth: Int = computeTerminalWidth()

    /// Detect the current terminal column width.
    ///
    /// Returns the cached value — computed once at first access — to avoid
    /// spawning a subprocess on every code block render.
    static func terminalWidth() -> Int {
        cachedTerminalWidth
    }

    private static func computeTerminalWidth() -> Int {
        // Method 1: stty size (macOS + Linux)
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/stty")
        process.arguments = ["size"]
        process.standardOutput = pipe
        // Redirect stdin to /dev/tty so stty can query the actual terminal
        if let tty = FileHandle(forReadingAtPath: "/dev/tty") {
            process.standardInput = tty
        }

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // stty size output: "rows cols" e.g. "24 80"
            let parts = output.split(separator: " ")
            if parts.count == 2, let cols = Int(parts[1]), cols > 0 {
                return cols
            }
        } catch {
            // Fall through to next method
        }

        // Method 2: COLUMNS environment variable
        if let cols = ProcessInfo.processInfo.environment["COLUMNS"],
           let width = Int(cols), width > 0 {
            return width
        }

        // Fallback: 80 columns
        return 80
    }

    /// Word-wrap text at the given column width, preserving leading indentation.
    ///
    /// Breaks at word boundaries. Continuation lines inherit the leading
    /// whitespace of the original line.
    static func wordWrap(_ text: String, width: Int) -> String {
        guard width > 0 else { return text }

        var result: [String] = []

        for line in text.components(separatedBy: "\n") {
            let leadingIndent = line.prefix(while: { $0 == " " })
            let indentCount = leadingIndent.count
            let content = String(line.dropFirst(indentCount))

            // Short enough -- no wrapping needed
            if line.count <= width { result.append(line); continue }

            // Wrap this line
            let words = content.split(separator: " ", omittingEmptySubsequences: false)
            var currentLine = String(leadingIndent)
            let maxWidth = width

            for word in words {
                let candidate = currentLine.isEmpty
                    ? String(leadingIndent) + word
                    : currentLine + " " + word

                if candidate.count <= maxWidth {
                    currentLine = candidate
                } else {
                    if currentLine != String(leadingIndent) {
                        result.append(currentLine)
                    }
                    currentLine = String(leadingIndent) + word
                }
            }
            if !currentLine.isEmpty {
                result.append(currentLine)
            }
        }

        return result.joined(separator: "\n")
    }

    // MARK: - Block Splitting

    /// Split Markdown input into blocks.
    ///
    /// Handles fenced code blocks (``` ... ```) as single blocks even though
    /// they may contain blank lines. All other content is split on double
    /// newlines.
    private static func splitIntoBlocks(_ markdown: String) -> [String] {
        var blocks: [String] = []
        var currentCodeBlock: [String] = []
        var inCodeBlock = false
        let lines = markdown.components(separatedBy: "\n")
        var nonCodeBuffer: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") && !inCodeBlock {
                // Start of code block -- flush any accumulated non-code lines first
                if !nonCodeBuffer.isEmpty {
                    let nonCode = nonCodeBuffer.joined(separator: "\n")
                    // Split accumulated non-code on double newlines
                    let subBlocks = nonCode.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    blocks.append(contentsOf: subBlocks)
                    nonCodeBuffer = []
                }
                inCodeBlock = true
                currentCodeBlock = [line]
                continue
            }

            if inCodeBlock {
                currentCodeBlock.append(line)
                if trimmed.hasPrefix("```") && currentCodeBlock.count > 1 {
                    // End of code block
                    blocks.append(currentCodeBlock.joined(separator: "\n"))
                    inCodeBlock = false
                    currentCodeBlock = []
                }
                continue
            }

            // Non-code line: accumulate and detect paragraph breaks
            nonCodeBuffer.append(line)
        }

        // Flush remaining code block (unclosed)
        if inCodeBlock {
            blocks.append(currentCodeBlock.joined(separator: "\n"))
        }

        // Flush remaining non-code
        if !nonCodeBuffer.isEmpty {
            let nonCode = nonCodeBuffer.joined(separator: "\n")
            let subBlocks = nonCode.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            blocks.append(contentsOf: subBlocks)
        }

        return blocks
    }

    // MARK: - Block Rendering

    /// Render a single block based on its detected type.
    private static func renderBlock(_ block: String, terminalWidth: Int) -> String {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)

        // Code block: starts and ends with ```
        if trimmed.hasPrefix("```") && trimmed.hasSuffix("```") && trimmed.count > 6 {
            return renderCodeBlock(block)
        }

        // Unclosed code block fallback
        if trimmed.hasPrefix("```") {
            return renderUnclosedCodeBlock(block)
        }

        // Check if all lines are list items (unordered or ordered)
        let lines = trimmed.components(separatedBy: "\n").filter { !$0.isEmpty }
        let allListItems = !lines.isEmpty && lines.allSatisfy { !isListLine($0).isEmpty }
        if allListItems {
            return renderListBlock(lines, terminalWidth: terminalWidth)
        }

        // Single-line heading
        if let heading = parseHeadingLevel(trimmed) {
            return renderHeading(trimmed, level: heading)
        }

        // Default: paragraph with inline rendering and word wrapping
        return renderParagraph(trimmed, terminalWidth: terminalWidth)
    }

    // MARK: - Code Block

    /// Render a fenced code block with box-drawing borders.
    ///
    /// Format:
    /// ```
    /// ┌───
    /// │ line 1
    /// │ line 2
    /// └───
    /// ```
    static func renderCodeBlock(_ block: String) -> String {
        let lines = block.components(separatedBy: "\n")
        guard lines.count >= 2 else { return block }

        // Extract content lines (skip opening ``` and closing ```)
        let contentLines = Array(lines.dropFirst().dropLast())

        // Determine border width from longest content line
        let maxLen = contentLines.map(\.count).max() ?? 0
        let borderWidth = max(maxLen, 3)

        let topBorder = "\u{250C}" + String(repeating: "\u{2500}", count: borderWidth + 2)
        let bottomBorder = "\u{2514}" + String(repeating: "\u{2500}", count: borderWidth + 2)

        var result: [String] = [topBorder]

        for line in contentLines {
            result.append("\u{2502} " + line)
        }

        result.append(bottomBorder)
        return result.joined(separator: "\n")
    }

    /// Graceful fallback for unclosed code blocks -- render as plain text.
    private static func renderUnclosedCodeBlock(_ block: String) -> String {
        let lines = block.components(separatedBy: "\n")
        // Skip the opening ``` line
        let contentLines = lines.first?.hasPrefix("```") == true ? Array(lines.dropFirst()) : lines
        return contentLines.joined(separator: "\n")
    }

    // MARK: - Headings

    /// Parse heading level from a line starting with # characters.
    /// Returns 1-6 for valid headings, nil otherwise.
    private static func parseHeadingLevel(_ line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }

        var hashCount = 0
        for char in trimmed {
            if char == "#" {
                hashCount += 1
            } else {
                break
            }
        }

        // Valid heading: 1-6 hashes followed by a space
        guard (1...6).contains(hashCount),
              trimmed.count > hashCount,
              trimmed[trimmed.index(trimmed.startIndex, offsetBy: hashCount)] == " " else {
            return nil
        }

        return hashCount
    }

    /// Render a heading with ANSI bold styling.
    ///
    /// Higher-level headings (fewer #) are just bold.
    /// All heading levels use bold; H1-H2 may include additional visual weight.
    private static func renderHeading(_ line: String, level: Int) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let hashCount = level
        let startIndex = trimmed.index(trimmed.startIndex, offsetBy: hashCount)
        let title = trimmed[startIndex...].trimmingCharacters(in: .whitespaces)

        if level <= 2 {
            // H1 and H2: bold + underline visual separator for H1
            let boldTitle = ANSI.bold(title)
            if level == 1 {
                return boldTitle
            }
            return boldTitle
        }

        return ANSI.bold(title)
    }

    // MARK: - Lists

    /// Check if a line is a list item (unordered or ordered).
    private static func isListLine(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Unordered: starts with - * or +
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return "unordered"
        }

        // Ordered: starts with digit(s) followed by ". "
        if let dotRange = trimmed.range(of: ". ", options: []) {
            let prefix = String(trimmed[trimmed.startIndex..<dotRange.lowerBound])
            if prefix.allSatisfy(\.isNumber) && !prefix.isEmpty {
                return "ordered"
            }
        }

        // Nested: has leading whitespace then a list marker
        let leadingSpaces = line.prefix(while: { $0 == " " })
        if !leadingSpaces.isEmpty {
            let afterSpaces = String(line.dropFirst(leadingSpaces.count))
            return isListLine(afterSpaces)
        }

        return ""
    }

    /// Render a block of list lines.
    private static func renderListBlock(_ lines: [String], terminalWidth: Int) -> String {
        return lines.map { line in
            renderListItem(line, terminalWidth: terminalWidth)
        }.joined(separator: "\n")
    }

    /// Render a single list item with proper indentation and bullet/number.
    private static func renderListItem(_ line: String, terminalWidth: Int) -> String {
        let leadingSpaces = line.prefix(while: { $0 == " " })
        let indentLevel = leadingSpaces.count / 2  // Each 2 spaces = 1 indent level
        let content = String(line.dropFirst(leadingSpaces.count))
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)

        let renderedContent: String
        if trimmedContent.hasPrefix("- ") || trimmedContent.hasPrefix("* ") || trimmedContent.hasPrefix("+ ") {
            let text = String(trimmedContent.dropFirst(2))
            renderedContent = renderInline(wordWrap(text, width: terminalWidth))
            let indent = String(repeating: "  ", count: indentLevel)
            return "\(indent)\u{2022} \(renderedContent)"
        }

        // Ordered list: "1. text"
        if let dotRange = trimmedContent.range(of: ". ") {
            let prefix = String(trimmedContent[trimmedContent.startIndex..<dotRange.lowerBound])
            let text = String(trimmedContent[dotRange.upperBound...])
            if prefix.allSatisfy(\.isNumber) && !prefix.isEmpty {
                renderedContent = renderInline(wordWrap(text, width: terminalWidth))
                let indent = String(repeating: "  ", count: indentLevel)
                return "\(indent)\(prefix). \(renderedContent)"
            }
        }

        // Fallback: treat as plain text with indent
        let indent = String(repeating: "  ", count: indentLevel)
        return "\(indent)\(renderInline(trimmedContent))"
    }

    // MARK: - Paragraphs

    /// Render a paragraph: word-wrap then apply inline formatting.
    private static func renderParagraph(_ text: String, terminalWidth: Int) -> String {
        let wrapped = wordWrap(text, width: terminalWidth)
        return renderInline(wrapped)
    }

    // MARK: - Inline Formatting

    /// Apply inline Markdown formatting: **bold** and `code`.
    static func renderInline(_ text: String) -> String {
        var result = text

        // Inline bold: **text**
        result = replaceInlineMarker(result, delimiter: "**") { content in
            ANSI.bold(content)
        }

        // Inline code: `text`
        result = replaceInlineMarker(result, delimiter: "`") { content in
            ANSI.cyan(content)
        }

        return result
    }

    /// Replace paired delimiters in text with a transformation function.
    ///
    /// Handles `**bold**` and `` `code` `` by finding matching delimiter pairs
    /// and replacing them with the transformed content.
    private static func replaceInlineMarker(
        _ text: String,
        delimiter: String,
        transform: (String) -> String
    ) -> String {
        var result = text
        while true {
            guard let openRange = result.range(of: delimiter) else { break }
            let afterOpen = openRange.upperBound
            guard let closeRange = result.range(of: delimiter, range: afterOpen..<result.endIndex) else { break }

            let content = String(result[afterOpen..<closeRange.lowerBound])
            let replacement = transform(content)
            result.replaceSubrange(openRange.lowerBound..<closeRange.upperBound, with: replacement)
        }
        return result
    }
}
