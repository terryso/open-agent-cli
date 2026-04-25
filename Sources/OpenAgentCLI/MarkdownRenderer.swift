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

        let lines = trimmed.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Table block: all lines match |...| pattern (at least 2 lines)
        let tableLines = lines.filter { isTableLine($0) }
        if tableLines.count >= 2 && tableLines.count == lines.count {
            return renderTable(tableLines, terminalWidth: terminalWidth)
        }

        // Blockquote block: all lines start with >
        let blockquoteLines = lines.filter { isBlockquoteLine($0) }
        if !lines.isEmpty && blockquoteLines.count == lines.count {
            return renderBlockquote(lines)
        }

        // Horizontal rule: single line of only -, *, or _ characters (no | present)
        if isHorizontalRule(trimmed) {
            return renderHorizontalRule(terminalWidth: terminalWidth)
        }

        // Check if all lines are list items (unordered or ordered)
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
    /// H1: bold + ═ decoration line
    /// H2: bold + ─ decoration line
    /// H3-H6: bold only
    private static func renderHeading(_ line: String, level: Int) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let hashCount = level
        let startIndex = trimmed.index(trimmed.startIndex, offsetBy: hashCount)
        let title = String(trimmed[startIndex...].trimmingCharacters(in: .whitespaces))

        let boldTitle = ANSI.bold(title)

        if level == 1 {
            let decoration = String(repeating: "\u{2550}", count: displayWidth(title))
            return boldTitle + "\n" + decoration
        }

        if level == 2 {
            let decoration = String(repeating: "\u{2500}", count: displayWidth(title))
            return boldTitle + "\n" + decoration
        }

        return boldTitle
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

    /// Apply inline Markdown formatting: **bold**, `code`, and [link](url).
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

        // Inline link: [text](url) → underlined text (URL hidden)
        result = replaceInlineLinks(result)

        return result
    }

    /// Replace `[text](url)` patterns with underlined text only.
    private static func replaceInlineLinks(_ text: String) -> String {
        var result = text
        var searchStart = result.startIndex

        while searchStart < result.endIndex {
            // Find opening [ from searchStart
            guard let openBracket = result[searchStart...].firstIndex(of: "[") else { break }

            // Find closing ] after [
            let afterOpen = result.index(after: openBracket)
            guard afterOpen < result.endIndex,
                  let closeBracket = result[afterOpen...].firstIndex(of: "]") else { break }

            // Check for ( immediately after ]
            let afterClose = result.index(after: closeBracket)
            guard afterClose < result.endIndex && result[afterClose] == "(" else {
                searchStart = result.index(after: openBracket)
                continue
            }

            // Find closing ) after (
            let afterParen = result.index(after: afterClose)
            guard afterParen < result.endIndex,
                  let closeParen = result[afterParen...].firstIndex(of: ")") else { break }

            // Extract link text (between [ and ])
            let linkText = String(result[result.index(after: openBracket)..<closeBracket])

            // Replace [text](url) with underlined text
            let replacement = ANSI.underline(linkText)
            result.replaceSubrange(openBracket...closeParen, with: replacement)

            // Move search start past the replacement
            searchStart = result.index(openBracket, offsetBy: replacement.count, limitedBy: result.endIndex) ?? result.endIndex
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

    // MARK: - Display Width Utilities

    /// Calculate the visual display width of a string in terminal columns.
    /// CJK and other East Asian characters count as 2 columns; ASCII as 1.
    private static func displayWidth(_ string: String) -> Int {
        var width = 0
        for scalar in string.unicodeScalars {
            if isDoubleWidthScalar(scalar.value) {
                width += 2
            } else if !scalar.properties.isDefaultIgnorableCodePoint && scalar != "\r" {
                width += 1
            }
        }
        return width
    }

    /// Whether a Unicode scalar is double-width in East Asian terminal contexts.
    private static func isDoubleWidthScalar(_ v: UInt32) -> Bool {
        // CJK Unified Ideographs + Extensions
        (0x4E00...0x9FFF).contains(v) ||
        (0x3400...0x4DBF).contains(v) ||
        (0x20000...0x2A6DF).contains(v) ||
        (0x2A700...0x2CEAF).contains(v) ||
        // CJK Compatibility Ideographs
        (0xF900...0xFAFF).contains(v) ||
        (0x2F800...0x2FA1F).contains(v) ||
        // Fullwidth Forms
        (0xFF01...0xFF60).contains(v) ||
        (0xFFE0...0xFFE6).contains(v) ||
        // CJK Symbols, Punctuation, Hiragana, Katakana, Bopomofo
        (0x3000...0x33FF).contains(v) ||
        // Hangul Syllables + Jamo
        (0xAC00...0xD7AF).contains(v) ||
        (0x1100...0x11FF).contains(v) ||
        (0x3130...0x318F).contains(v)
    }

    /// Truncate a string to fit within the given display width (terminal columns).
    private static func truncateToDisplayWidth(_ string: String, maxWidth: Int) -> String {
        var width = 0
        var idx = string.startIndex
        while idx < string.endIndex {
            let charWidth = displayWidth(String(string[idx]))
            if width + charWidth > maxWidth {
                break
            }
            width += charWidth
            idx = string.index(after: idx)
        }
        return String(string[..<idx])
    }

    // MARK: - Table Rendering

    /// Check if a line is a table row (starts and ends with |).
    private static func isTableLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count >= 2
    }

    /// Check if a line is a table separator row (e.g., |---|---|).
    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") && trimmed.hasSuffix("|") else { return false }
        // Split and check each cell contains only -, :, or whitespace
        let inner = String(trimmed.dropFirst().dropLast())
        let cells = inner.split(separator: "|", omittingEmptySubsequences: false)
        return cells.allSatisfy { cell in
            let content = cell.trimmingCharacters(in: .whitespaces)
            return content.isEmpty || content.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    /// Extract cell contents from a table row.
    private static func extractCells(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Remove leading and trailing |
        let inner = String(trimmed.dropFirst().dropLast())
        return inner.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    /// Render a table block with box-drawing borders.
    ///
    /// Parses Markdown table rows and renders with Unicode box-drawing characters.
    /// Header row is bold; numeric cells are right-aligned.
    static func renderTable(_ lines: [String], terminalWidth: Int) -> String {
        // Separate header, separator, and data rows
        var headerCells: [String] = []
        var dataRows: [[String]] = []
        var separatorFound = false

        for line in lines {
            if isTableSeparator(line) {
                separatorFound = true
                continue
            }
            let cells = extractCells(line)
            if headerCells.isEmpty && !separatorFound {
                headerCells = cells
            } else {
                dataRows.append(cells)
            }
        }

        let columnCount = headerCells.count
        guard columnCount > 0 else { return lines.joined(separator: "\n") }

        // Calculate column widths (max content length per column)
        var colWidths = Array(repeating: 0, count: columnCount)

        for (i, cell) in headerCells.enumerated() {
            colWidths[i] = max(colWidths[i], displayWidth(cell))
        }
        for row in dataRows {
            for i in 0..<columnCount {
                let cell = i < row.count ? row[i] : ""
                colWidths[i] = max(colWidths[i], displayWidth(cell))
            }
        }

        // Apply terminal width constraints: cap each column proportionally
        let totalPadding = (columnCount + 1) * 3 // border chars + padding
        let availableWidth = max(terminalWidth - totalPadding, columnCount * 4)
        let maxPerCol = availableWidth / columnCount

        for i in 0..<columnCount {
            if colWidths[i] > maxPerCol {
                colWidths[i] = maxPerCol
            }
        }

        // Helper: format a cell with padding and optional alignment
        func formatCell(_ content: String, colIndex: Int, width: Int) -> String {
            let truncated: String
            if displayWidth(content) > width {
                if width > 3 {
                    truncated = truncateToDisplayWidth(content, maxWidth: width - 3) + "..."
                } else {
                    truncated = truncateToDisplayWidth(content, maxWidth: width)
                }
            } else {
                truncated = content
            }

            let isNumeric = content.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" }
            let truncatedWidth = displayWidth(truncated)
            if isNumeric && truncatedWidth < width {
                let padding = width - truncatedWidth
                return String(repeating: " ", count: padding) + truncated
            } else if truncatedWidth < width {
                return truncated + String(repeating: " ", count: width - truncatedWidth)
            }
            return truncated
        }

        // Build horizontal borders
        func buildBorder(left: String, mid: String, right: String, fill: String = "\u{2500}") -> String {
            var parts = [String]()
            parts.append(left)
            for (i, w) in colWidths.enumerated() {
                // +2 for padding spaces on each side of content
                let segLen = w + 2
                parts.append(String(repeating: fill, count: segLen))
                if i < colWidths.count - 1 {
                    parts.append(mid)
                }
            }
            parts.append(right)
            return parts.joined()
        }

        // Build a content row
        func buildRow(_ cells: [String], bold: Bool = false) -> String {
            var parts = [String]()
            parts.append("\u{2502}")
            for i in 0..<columnCount {
                let content = i < cells.count ? cells[i] : ""
                let formatted = formatCell(content, colIndex: i, width: colWidths[i])
                let cell = " \(formatted) "
                if bold {
                    parts.append(ANSI.bold(cell))
                } else {
                    parts.append(cell)
                }
                parts.append("\u{2502}")
            }
            return parts.joined()
        }

        // Assemble table
        var result: [String] = []
        result.append(buildBorder(left: "\u{250C}", mid: "\u{252C}", right: "\u{2510}"))
        result.append(buildRow(headerCells, bold: true))

        if !dataRows.isEmpty {
            result.append(buildBorder(left: "\u{251C}", mid: "\u{253C}", right: "\u{2524}"))
            for row in dataRows {
                result.append(buildRow(row))
            }
        }

        result.append(buildBorder(left: "\u{2514}", mid: "\u{2534}", right: "\u{2518}"))
        return result.joined(separator: "\n")
    }

    // MARK: - Blockquote Rendering

    /// Check if a line is a blockquote line (starts with >).
    private static func isBlockquoteLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix(">")
    }

    /// Render a blockquote block with │ prefix.
    static func renderBlockquote(_ lines: [String]) -> String {
        return lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let content: String
            if trimmed.hasPrefix("> ") {
                content = String(trimmed.dropFirst(2))
            } else if trimmed.hasPrefix(">") {
                content = String(trimmed.dropFirst(1))
            } else {
                content = trimmed
            }
            let renderedContent = renderInline(content)
            return "\u{2502} " + renderedContent
        }.joined(separator: "\n")
    }

    // MARK: - Horizontal Rule Rendering

    /// Check if text is a horizontal rule (only -, *, or _ characters, at least 3, no |).
    private static func isHorizontalRule(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        // Must not contain | (that would be a table row)
        guard !trimmed.contains("|") else { return false }
        // Single line only
        guard !trimmed.contains("\n") else { return false }
        // Remove all allowed characters
        let filtered = trimmed.filter { $0 != "-" && $0 != "*" && $0 != "_" && $0 != " " }
        guard filtered.isEmpty else { return false }
        // Must have at least 3 non-space characters
        let nonSpace = trimmed.filter { $0 != " " }
        return nonSpace.count >= 3
    }

    /// Render a horizontal rule as a line of ─ characters spanning the terminal width.
    static func renderHorizontalRule(terminalWidth: Int) -> String {
        return String(repeating: "\u{2500}", count: terminalWidth)
    }
}
