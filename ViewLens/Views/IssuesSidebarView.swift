import SwiftUI
import ViewLensKit

public struct IssuesSidebarView: View {
    @Bindable var model: AppModel
    @State private var copiedSnippet: String? = nil

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("HIG & WCAG Issues")
                    .font(.headline)
                Spacer()
                Text("\(model.currentIssues.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(model.currentIssues.isEmpty ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .foregroundColor(model.currentIssues.isEmpty ? .green : .red)
                    .cornerRadius(4)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if model.currentIssues.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    Text("100% HIG & WCAG Compliant")
                        .font(.headline)
                    Text("No touch target, clipping, occlusion, or color contrast defects detected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(model.currentIssues.enumerated()), id: \.offset) { index, issue in
                            IssueCardView(issue: issue, isSelected: model.selectedIssue == issue) {
                                model.selectedIssue = issue
                                if let elemIdx = issue.elementIndex {
                                    model.selectedElementIndex = elemIdx
                                }
                            }
                        }
                    }
                    .padding(8)
                }
            }

            Divider()

            // Selected Issue Remediation Panel
            if let issue = model.selectedIssue {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Suggested Remediation")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    if let remediation = issue.remediation {
                        Text(remediation.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let snippet = remediation.codeSnippet {
                            HStack {
                                Text(snippet)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(6)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(4)

                                Spacer()

                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(snippet, forType: .string)
                                    copiedSnippet = snippet
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        copiedSnippet = nil
                                    }
                                }) {
                                    Image(systemName: copiedSnippet == snippet ? "checkmark" : "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
}

struct IssueCardView: View {
    let issue: ViewLensIssue
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: issue.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(issue.severity == .error ? .red : .orange)

                    Text(issue.kind.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(issue.severity == .error ? .red : .orange)

                    Spacer()

                    if let wcag = issue.wcagCriterion {
                        Text([wcag, issue.wcagLevel].compactMap { $0 }.joined(separator: " "))
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }

                    if let elemIdx = issue.elementIndex {
                        Text("#\(elemIdx)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(issue.description)
                    .font(.caption)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
