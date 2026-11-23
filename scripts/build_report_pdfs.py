#!/usr/bin/env python3
"""
Convert Markdown Engineering Reports to Publication-Quality HTML and PDF:
1. docs/PHASE2_FINAL_REPORT.md -> docs/PHASE2_FINAL_REPORT.html -> docs/PHASE2_FINAL_REPORT.pdf
2. docs/PHASE2_ARCHITECTURE.md -> docs/PHASE2_ARCHITECTURE.html -> docs/PHASE2_ARCHITECTURE.pdf

Syncs PDFs to Desktop and Downloads.
"""

import os
import subprocess
import markdown

REPO_ROOT = "/Users/aryan./cn-project"
DOCS_DIR = os.path.join(REPO_ROOT, "docs")
DESKTOP_DIR = "/Users/aryan./Desktop"
DOWNLOADS_DIR = "/Users/aryan./Downloads"
CHROME_BIN = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

REPORT_MD = os.path.join(DOCS_DIR, "PHASE2_FINAL_REPORT.md")
REPORT_HTML = os.path.join(DOCS_DIR, "PHASE2_FINAL_REPORT.html")
REPORT_PDF = os.path.join(DOCS_DIR, "PHASE2_FINAL_REPORT.pdf")

ARCH_MD = os.path.join(DOCS_DIR, "PHASE2_ARCHITECTURE.md")
ARCH_HTML = os.path.join(DOCS_DIR, "PHASE2_ARCHITECTURE.html")
ARCH_PDF = os.path.join(DOCS_DIR, "PHASE2_ARCHITECTURE.pdf")

CSS = """
@page {
    size: A4;
    margin: 20mm 18mm 20mm 18mm;
    @bottom-right {
        content: counter(page);
    }
}
* {
    box-sizing: border-box;
}
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    font-size: 11pt;
    line-height: 1.6;
    color: #1e293b;
    background: #ffffff;
    max-width: 900px;
    margin: 0 auto;
    padding: 20px;
}
h1 {
    font-size: 22pt;
    color: #0f172a;
    border-bottom: 2px solid #0284c7;
    padding-bottom: 8px;
    margin-top: 0;
    margin-bottom: 12px;
}
h2 {
    font-size: 15pt;
    color: #0369a1;
    border-bottom: 1px solid #cbd5e1;
    padding-bottom: 6px;
    margin-top: 24px;
    margin-bottom: 12px;
    page-break-after: avoid;
}
h3 {
    font-size: 12pt;
    color: #0f172a;
    margin-top: 18px;
    margin-bottom: 8px;
    page-break-after: avoid;
}
p {
    margin-top: 0;
    margin-bottom: 10px;
}
hr {
    border: none;
    border-top: 1px solid #e2e8f0;
    margin: 20px 0;
}
table {
    width: 100%;
    border-collapse: collapse;
    margin: 15px 0;
    font-size: 9.5pt;
    page-break-inside: avoid;
}
th, td {
    border: 1px solid #cbd5e1;
    padding: 7px 10px;
    text-align: left;
    vertical-align: top;
}
th {
    background-color: #f1f5f9;
    color: #0f172a;
    font-weight: 700;
}
tr:nth-child(even) td {
    background-color: #f8fafc;
}
code {
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
    font-size: 9pt;
    background-color: #f1f5f9;
    padding: 2px 5px;
    border-radius: 4px;
    color: #0369a1;
    border: 1px solid #e2e8f0;
}
pre {
    background-color: #0f172a;
    color: #f8fafc;
    padding: 12px 14px;
    border-radius: 6px;
    overflow-x: auto;
    font-size: 8.5pt;
    line-height: 1.45;
    page-break-inside: avoid;
    margin: 12px 0;
}
pre code {
    background: transparent;
    color: inherit;
    padding: 0;
    border: none;
    font-size: inherit;
}
ul, ol {
    margin-top: 0;
    margin-bottom: 12px;
    padding-left: 22px;
}
li {
    margin-bottom: 4px;
}
blockquote {
    border-left: 4px solid #0284c7;
    margin: 12px 0;
    padding: 8px 14px;
    background-color: #f0f9ff;
    color: #0369a1;
    font-style: italic;
}
.header-badge {
    display: inline-block;
    background: #0284c7;
    color: #ffffff;
    font-size: 9pt;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 4px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 8px;
}
"""

def convert_doc(md_path, html_path, pdf_path, title):
    print(f"Converting {md_path}...")
    with open(md_path, "r", encoding="utf-8") as f:
        md_text = f.read()

    html_body = markdown.markdown(md_text, extensions=['tables', 'fenced_code', 'toc'])

    full_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>{title}</title>
<style>
{CSS}
</style>
</head>
<body>
{html_body}
</body>
</html>
"""
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(full_html)
    print(f"HTML generated: {html_path}")

    # Generate PDF via Chrome Headless
    cmd = [
        CHROME_BIN,
        "--headless",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path}",
        html_path
    ]
    subprocess.run(cmd, check=True)
    print(f"PDF generated: {pdf_path}")

def main():
    convert_doc(REPORT_MD, REPORT_HTML, REPORT_PDF, "Phase 2 Final Engineering Report - Network Packers")
    convert_doc(ARCH_MD, ARCH_HTML, ARCH_PDF, "Phase 2 Architecture Document - Network Packers")

    # Sync to Desktop and Downloads
    for pdf in [REPORT_PDF, ARCH_PDF]:
        fname = os.path.basename(pdf)
        subprocess.run(["cp", "-f", pdf, os.path.join(DESKTOP_DIR, fname)], check=True)
        subprocess.run(["cp", "-f", pdf, os.path.join(DOWNLOADS_DIR, fname)], check=True)
        print(f"Synced {fname} to Desktop and Downloads.")

    print("All report PDFs generated and synced successfully!")

if __name__ == "__main__":
    main()
