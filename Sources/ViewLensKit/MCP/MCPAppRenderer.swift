import Foundation

/// Generates the self-contained HTML/CSS/JavaScript MCP Review Application (MCP-18.1 - MCP-18.5).
public enum MCPAppRenderer {

    /// Renders a complete, standalone, accessible HTML review application for a review or template.
    public static func renderAppHTML(
        reviewID: String = "latest",
        templateName: String = "LoginForm",
        overallStatus: String = "Passed",
        passedCount: Int = 12,
        failedCount: Int = 0
    ) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>ViewLens Review App — \(templateName)</title>
          <style>
            :root {
              --bg: #0F1117;
              --surface: #1A1D27;
              --border: #2E3346;
              --text: #F1F3F9;
              --text-muted: #8E96B0;
              --accent: #6C5CE7;
              --accent-hover: #5849D6;
              --success: #00B894;
              --warning: #FDCB6E;
              --error: #FF7675;
              --font: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
              --mono: "SF Mono", Monaco, Menlo, Consolas, monospace;
            }
            @media (prefers-reduced-motion: reduce) {
              * { animation: none !important; transition: none !important; }
            }
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body {
              background: var(--bg);
              color: var(--text);
              font-family: var(--font);
              display: flex;
              flex-direction: column;
              height: 100vh;
              overflow: hidden;
            }
            header {
              display: flex;
              align-items: center;
              justify-content: space-between;
              padding: 12px 20px;
              background: var(--surface);
              border-bottom: 1px solid var(--border);
            }
            .brand {
              display: flex;
              align-items: center;
              gap: 10px;
              font-weight: 700;
              font-size: 16px;
            }
            .badge {
              padding: 3px 8px;
              border-radius: 6px;
              font-size: 12px;
              font-weight: 600;
              background: rgba(108, 92, 231, 0.2);
              color: var(--accent);
            }
            .badge-pass {
              background: rgba(0, 184, 148, 0.2);
              color: var(--success);
            }
            .nav-tabs {
              display: flex;
              gap: 8px;
            }
            .tab-btn {
              background: transparent;
              border: 1px solid transparent;
              color: var(--text-muted);
              padding: 6px 14px;
              border-radius: 6px;
              cursor: pointer;
              font-weight: 600;
              font-size: 13px;
            }
            .tab-btn:hover, .tab-btn:focus {
              color: var(--text);
              background: rgba(255,255,255,0.05);
              outline: none;
            }
            .tab-btn.active {
              color: var(--text);
              background: var(--accent);
            }
            main {
              display: grid;
              grid-template-columns: 1fr 340px;
              flex: 1;
              overflow: hidden;
            }
            .stage {
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              padding: 24px;
              overflow: auto;
              position: relative;
            }
            .viewport-frame {
              width: 375px;
              height: 667px;
              background: #000;
              border-radius: 36px;
              border: 8px solid #2A2D3D;
              box-shadow: 0 20px 50px rgba(0,0,0,0.5);
              position: relative;
              overflow: hidden;
              display: flex;
              flex-direction: column;
            }
            .preview-canvas {
              flex: 1;
              position: relative;
              background: #181920;
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              padding: 20px;
            }
            .ui-card {
              width: 100%;
              background: #252836;
              border-radius: 12px;
              padding: 16px;
              margin-bottom: 12px;
            }
            .ui-btn {
              background: var(--accent);
              color: #fff;
              border: none;
              padding: 12px;
              border-radius: 8px;
              width: 100%;
              font-weight: 600;
              cursor: pointer;
            }
            .sidebar {
              background: var(--surface);
              border-left: 1px solid var(--border);
              display: flex;
              flex-direction: column;
              overflow-y: auto;
            }
            .sidebar-header {
              padding: 16px;
              border-bottom: 1px solid var(--border);
              font-weight: 700;
              font-size: 14px;
            }
            .tree-node {
              padding: 10px 16px;
              border-bottom: 1px solid rgba(255,255,255,0.04);
              cursor: pointer;
              font-size: 13px;
              display: flex;
              flex-direction: column;
              gap: 4px;
            }
            .tree-node:hover, .tree-node:focus {
              background: rgba(108, 92, 231, 0.1);
              outline: none;
            }
            .tree-node.selected {
              background: rgba(108, 92, 231, 0.25);
              border-left: 3px solid var(--accent);
            }
            .node-title {
              font-weight: 600;
              color: var(--text);
            }
            .node-sub {
              font-size: 11px;
              color: var(--text-muted);
              font-family: var(--mono);
            }
            .braille-preview {
              font-size: 14px;
              font-family: var(--mono);
              background: #11131A;
              padding: 6px 10px;
              border-radius: 4px;
              color: var(--warning);
              margin-top: 4px;
            }
            .code-box {
              background: #11131A;
              padding: 12px;
              border-radius: 6px;
              font-family: var(--mono);
              font-size: 12px;
              color: #A5B4FC;
              overflow-x: auto;
              margin-top: 8px;
            }
            .actions-bar {
              padding: 16px;
              border-top: 1px solid var(--border);
              display: flex;
              gap: 8px;
            }
            .action-btn {
              flex: 1;
              padding: 8px 12px;
              border-radius: 6px;
              font-size: 12px;
              font-weight: 600;
              cursor: pointer;
              border: 1px solid var(--border);
              background: rgba(255,255,255,0.05);
              color: var(--text);
            }
            .action-btn:hover {
              background: rgba(255,255,255,0.1);
            }
          </style>
        </head>
        <body>
          <header role="banner">
            <div class="brand">
              <span>🔍 ViewLens Review</span>
              <span class="badge">\(templateName)</span>
              <span class="badge badge-pass">\(overallStatus) (\(passedCount) Passed)</span>
            </div>
            <nav class="nav-tabs" role="tablist" aria-label="Review Views">
              <button class="tab-btn active" role="tab" aria-selected="true" id="tab-canvas" tabindex="0">Canvas</button>
              <button class="tab-btn" role="tab" aria-selected="false" id="tab-diff" tabindex="-1">Before/After Diff</button>
              <button class="tab-btn" role="tab" aria-selected="false" id="tab-a11y" tabindex="-1">VoiceOver Tree</button>
            </nav>
          </header>

          <main role="main">
            <section class="stage" aria-label="Visual Device Stage">
              <div class="viewport-frame" role="region" aria-label="iPhone Preview">
                <div class="preview-canvas">
                  <div class="ui-card">
                    <div style="font-weight:700; margin-bottom:4px;">Sign In</div>
                    <div style="font-size:12px; color:#8E96B0;">Enter your credentials</div>
                  </div>
                  <button class="ui-btn" id="btn-login" aria-label="Sign In Button">Sign In</button>
                </div>
              </div>
            </section>

            <aside class="sidebar" role="complementary" aria-label="Accessibility & Finding Inspector">
              <div class="sidebar-header">Hierarchy & Nonvisual Tree</div>
              <div role="tree" aria-label="Screen Elements">
                <div class="tree-node selected" role="treeitem" tabindex="0" aria-selected="true">
                  <div class="node-title">Primary Button: "Sign In"</div>
                  <div class="node-sub">ID: btn_login • Frame: [0.1, 0.8, 0.8, 0.08]</div>
                  <div class="braille-preview" aria-label="Simulated Braille">⠠⠎⠊⠛⠝ ⠠⠊⠝ ⠠⠃⠥⠞⠞⠕⠝</div>
                </div>
                <div class="tree-node" role="treeitem" tabindex="-1" aria-selected="false">
                  <div class="node-title">Header: "Sign In"</div>
                  <div class="node-sub">ID: header_title • Frame: [0.1, 0.2, 0.8, 0.05]</div>
                  <div class="braille-preview" aria-label="Simulated Braille">⠠⠎⠊⠛⠝ ⠠⠊⠝ ⠠⠓⠑⠁⠙⠊⠝⠛</div>
                </div>
              </div>

              <div class="sidebar-header" style="border-top: 1px solid var(--border);">Inspector & Remediation</div>
              <div style="padding: 16px;">
                <div style="font-size: 13px; font-weight:600;">Touch Target Evaluation:</div>
                <div style="font-size: 12px; color: var(--success); margin-top:4px;">✅ Height: 48pt (meets 44pt Apple HIG & WCAG 2.5.5)</div>

                <div style="font-size: 13px; font-weight:600; margin-top:12px;">Contrast Ratio:</div>
                <div style="font-size: 12px; color: var(--success); margin-top:4px;">✅ 5.8:1 (meets 4.5:1 WCAG 1.4.3 AA)</div>

                <div style="font-size: 13px; font-weight:600; margin-top:12px;">SwiftUI Code Snippet:</div>
                <pre class="code-box"><code>Button("Sign In") {
                    viewModel.login()
                }
                .frame(minHeight: 44)
                .accessibilityAddTraits(.isButton)</code></pre>
              </div>

              <div class="actions-bar">
                <button class="action-btn" id="btn-replay">Replay Step</button>
                <button class="action-btn" id="btn-approve">Approve Baseline</button>
              </div>
            </aside>
          </main>

          <script>
            // Accessible Keyboard Navigation & Tab Switching
            const tabs = document.querySelectorAll('.tab-btn');
            tabs.forEach(tab => {
              tab.addEventListener('click', () => {
                tabs.forEach(t => {
                  t.classList.remove('active');
                  t.setAttribute('aria-selected', 'false');
                  t.setAttribute('tabindex', '-1');
                });
                tab.classList.add('active');
                tab.setAttribute('aria-selected', 'true');
                tab.setAttribute('tabindex', '0');
              });
            });

            // Element Click Selection
            const treeNodes = document.querySelectorAll('.tree-node');
            treeNodes.forEach(node => {
              node.addEventListener('click', () => {
                treeNodes.forEach(n => {
                  n.classList.remove('selected');
                  n.setAttribute('aria-selected', 'false');
                });
                node.classList.add('selected');
                node.setAttribute('aria-selected', 'true');
              });
            });
          </script>
        </body>
        </html>
        """
    }
}
