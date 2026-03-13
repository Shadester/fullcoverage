import Foundation

func generateSVGBadge(label: String = "coverage", pct: Double) -> String {
    let value = String(format: "%.0f%%", pct * 100)

    let color: String
    if pct >= 0.8 { color = "#3fb950" }
    else if pct >= 0.5 { color = "#d29922" }
    else { color = "#f85149" }

    let charW = 6.5
    let pad = 8.0
    let labelW = Double(label.count) * charW + pad * 2
    let valueW = Double(value.count) * charW + pad * 2
    let totalW = Int(labelW + valueW)
    let lx = Int(labelW / 2)
    let vx = Int(labelW + valueW / 2)

    return """
    <svg xmlns="http://www.w3.org/2000/svg" width="\(totalW)" height="20" role="img" aria-label="\(label): \(value)">
      <title>\(label): \(value)</title>
      <clipPath id="r"><rect width="\(totalW)" height="20" rx="3"/></clipPath>
      <g clip-path="url(#r)">
        <rect width="\(Int(labelW))" height="20" fill="#555"/>
        <rect x="\(Int(labelW))" width="\(Int(valueW))" height="20" fill="\(color)"/>
      </g>
      <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
        <text x="\(lx)" y="14">\(label)</text>
        <text x="\(vx)" y="14" font-weight="bold">\(value)</text>
      </g>
    </svg>
    """
}
