# email_html.R — email-safe HTML pieces for the weekly report.
#
# Power Automate sends this page by email, so: tables + inline styles only,
# no images, no JavaScript, no external CSS. Bars are two-cell tables,
# which Outlook renders where CSS widths on divs don't.

COL <- list(navy = "#003d5c", text = "#212529", muted = "#6c757d",
            line = "#e0e0e0", track = "#eef2f5", bar = "#4f7fa6",
            good = "#2e7d32", warn = "#b8860b", bad = "#c0392b", tint = "#f5f8fa")

esc <- function(x) htmltools::htmlEscape(as.character(x))

pct <- function(x) ifelse(is.na(x), "—", sprintf("%.0f%%", 100 * x))

num <- function(x) format(round(x), big.mark = ",", trim = TRUE)

h2 <- function(title, sub = NULL) {
  paste0(sprintf('<h2 style="color:%s; font-size:1.25rem; margin:28px 0 4px; padding-bottom:4px; border-bottom:2px solid %s;">%s</h2>',
                 COL$navy, COL$navy, title),
         if (!is.null(sub)) sprintf('<p style="color:%s; font-size:0.85rem; margin:0 0 10px;">%s</p>', COL$muted, sub) else "")
}

h3 <- function(title) {
  sprintf('<h3 style="color:%s; font-size:1rem; margin:16px 0 6px;">%s</h3>', COL$navy, title)
}

p <- function(...) {
  sprintf('<p style="font-size:0.92rem; line-height:1.45; margin:6px 0;">%s</p>', paste0(...))
}

small <- function(...) {
  sprintf('<p style="font-size:0.8rem; color:%s; margin:4px 0;">%s</p>', COL$muted, paste0(...))
}

# A row of number tiles: each element list(value, label, sub = NULL).
kpi_row <- function(tiles) {
  cells <- vapply(tiles, function(t) sprintf(
    '<td style="padding:10px 8px; text-align:center; border:1px solid %s; background:%s; width:%.0f%%;">
       <div style="font-size:1.5rem; font-weight:700; color:%s;">%s</div>
       <div style="font-size:0.78rem; color:%s; margin-top:2px;">%s</div>%s
     </td>',
    COL$line, COL$tint, 100 / length(tiles), t$color %||% COL$navy, t$value, COL$text, t$label,
    if (!is.null(t$sub)) sprintf('<div style="font-size:0.72rem; color:%s; margin-top:2px;">%s</div>', COL$muted, t$sub) else ""),
    character(1))
  sprintf('<table role="presentation" style="border-collapse:collapse; width:100%%; margin:8px 0;"><tr>%s</tr></table>',
          paste(cells, collapse = ""))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# Horizontal bar rows: label | bar | value. `frac` in 0-1.
bar_rows <- function(labels, frac, values, color = COL$bar) {
  rows <- vapply(seq_along(labels), function(i) {
    w <- max(1, min(100, round(100 * frac[i])))
    sprintf(
      '<tr>
         <td style="padding:3px 8px 3px 0; font-size:0.85rem; white-space:nowrap; width:38%%;">%s</td>
         <td style="padding:3px 0;"><table role="presentation" style="border-collapse:collapse; width:100%%;"><tr>
           <td style="width:%d%%; height:12px; background:%s;"></td><td style="background:%s;"></td>
         </tr></table></td>
         <td style="padding:3px 0 3px 8px; font-size:0.85rem; text-align:right; white-space:nowrap; width:14%%;">%s</td>
       </tr>',
      esc(labels[i]), w, color, COL$track, values[i])
  }, character(1))
  sprintf('<table role="presentation" style="border-collapse:collapse; width:100%%; margin:4px 0;">%s</table>',
          paste(rows, collapse = ""))
}

# Plain data table. `df` cells are already formatted strings (HTML allowed);
# the first column is left-aligned, the rest right-aligned.
html_table <- function(df, bold_last = FALSE) {
  th <- sprintf('<th style="padding:5px 8px; border-bottom:2px solid %s; font-size:0.8rem; color:%s; text-align:%s;">%s</th>',
                COL$navy, COL$muted, c("left", rep("right", ncol(df) - 1)), esc(names(df)))
  rows <- vapply(seq_len(nrow(df)), function(i) {
    weight <- if (bold_last && i == nrow(df)) "font-weight:700;" else ""
    paste0("<tr>", paste(sprintf('<td style="padding:5px 8px; border-bottom:1px solid %s; font-size:0.85rem; text-align:%s; %s">%s</td>',
                                 COL$line, c("left", rep("right", ncol(df) - 1)), weight,
                                 vapply(df[i, ], as.character, character(1))), collapse = ""), "</tr>")
  }, character(1))
  sprintf('<table style="border-collapse:collapse; width:100%%; margin:6px 0;"><tr>%s</tr>%s</table>',
          paste(th, collapse = ""), paste(rows, collapse = ""))
}

link_button <- function(url, text) {
  sprintf('<a href="%s" style="display:inline-block; background:%s; color:#ffffff; padding:7px 14px; border-radius:4px; text-decoration:none; font-size:0.85rem; margin:4px 6px 4px 0;">%s &rarr;</a>',
          url, COL$navy, text)
}

# "12 / 16" plus a color for how complete it is: quarters that have closed
# are judged (green >= 90%, amber >= 60%, red below); the open quarter is not.
done_cell <- function(n, of, window) {
  if (of == 0) return("—")
  f <- n / of
  color <- if (window != "past") COL$text else if (f >= 0.9) COL$good else if (f >= 0.6) COL$warn else COL$bad
  sprintf('<span style="color:%s; font-weight:600;">%d / %d</span>', color, n, of)
}

# Dates without zero padding ("Oct 5", "3:02 PM"): %e / %l pad with a
# space, which this squeezes out. (%-d isn't portable to R on macOS.)
fmt_date <- function(x, fmt, ...) gsub("\\s+", " ", trimws(format(x, fmt, ...)))
