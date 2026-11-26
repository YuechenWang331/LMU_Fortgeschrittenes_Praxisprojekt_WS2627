# Einheitlicher Abbildungsstil (Vorlage: farbig hervorgehobene Wellen, grauer Rest, weisse Wellenlabels).
# Wird von Scripts/modellauswahl/11_figures.R geladen.

suppressPackageStartupMessages({library(ggplot2); library(scales)})

# Farben je Welle (Okabe-Ito-basiert, farbenblindenfreundlich) und Grau fuer alles ausserhalb der Wellen
WAVE_COL <- c(W1 = "#0072B2", W2 = "#E69F00", W3 = "#009E73", W4 = "#CC79A7", W5 = "#D55E00",
              W6 = "#56B4E9", W7 = "#9467BD", W8 = "#8C6D31")
GREY_LINE <- "#8A97A3"
# Raumtypen: warm = staedtisch, kalt = laendlich
KT_COL <- c("#D55E00", "#E69F00", "#56B4E9", "#0072B2")
KT_LAB <- c("Kreisfreie Großstadt", "Städtischer Kreis", "Ländlicher Kreis mit Verdichtungsansätzen",
            "Dünn besiedelter ländlicher Kreis")

lab_de <- function(x) format(x, big.mark = ".", decimal.mark = ",", scientific = FALSE, trim = TRUE)

theme_proj <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title.position   = "plot",
      plot.title            = element_text(face = "bold", size = base_size + 4, hjust = 0, margin = margin(b = 3)),
      plot.subtitle         = element_text(size = base_size, colour = "grey30", hjust = 0, margin = margin(b = 12)),
      plot.caption          = element_text(size = base_size - 3, colour = "grey45", hjust = 0, margin = margin(t = 8)),
      panel.grid.minor      = element_blank(),
      panel.grid.major      = element_line(colour = "#E9E9E9", linewidth = .35),
      axis.text             = element_text(colour = "grey30", size = base_size - 2),
      axis.title            = element_text(colour = "grey15", size = base_size - 1),
      strip.text            = element_text(face = "bold", hjust = 0, size = base_size),
      legend.position       = "bottom",
      legend.title          = element_text(face = "bold", size = base_size - 1),
      legend.text           = element_text(size = base_size - 1),
      plot.margin           = margin(14, 16, 10, 14),
      plot.background       = element_rect(fill = "white", colour = NA)
    )
}

# ragg zeichnet Umlaute und Sonderzeichen (–, ρ) korrekt; Ausweichloesung: Cairo
save_fig <- function(p, name, w, h) {
  dev <- if (requireNamespace("ragg", quietly = TRUE)) ragg::agg_png else function(...) grDevices::png(..., type = "cairo")
  ggsave(file.path(DIR_FIG, name), p, width = w, height = h, dpi = 200, bg = "white", device = dev)
}

# weisses Wellenlabel mit farbigem, fettem Text
wave_label <- function(data, ypos, size = 3.6) {
  geom_label(data = data, aes(x = mid, y = ypos, label = id, colour = id), fill = "white", fontface = "bold",
             size = size, linewidth = 0, label.padding = unit(.28, "lines"), show.legend = FALSE)
}
