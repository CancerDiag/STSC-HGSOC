EnrichrDotPlot <- function (seurat_obj, database, mods = "all", n_terms = 3, p_cutoff = 0.05, 
    p_adj = TRUE, break_ties = TRUE, term_size = 10, wgcna_name = NULL) 
{
    if (is.null(wgcna_name)) {
        wgcna_name <- seurat_obj@misc$active_wgcna
    }
    modules <- GetModules(seurat_obj, wgcna_name)
    if (mods == "all") {
        mods <- levels(modules$module)
        mods <- mods[mods != "grey"]
    }
    enrichr_df <- GetEnrichrTable(seurat_obj, wgcna_name)
    if (p_adj) {
        enrichr_df <- subset(enrichr_df, Adjusted.P.value <= 
            p_cutoff)
    }
    else {
        enrichr_df <- subset(enrichr_df, P.value <= p_cutoff)
    }
    mod_colors <- dplyr::select(modules, c(module, color)) %>% 
        dplyr::distinct()
    enrichr_df$color <- mod_colors[match(enrichr_df$module, mod_colors$module), 
        "color"]
    wrapText <- function(x, len) {
        sapply(x, function(y) paste(strwrap(y, len), collapse = "\n"), 
            USE.NAMES = FALSE)
    }
    top_terms <- enrichr_df %>% subset(db == database & module %in% 
        mods) %>% group_by(module) %>% slice_max(order_by = Combined.Score, 
        n = n_terms) %>% .$Term
    plot_df <- subset(enrichr_df, Term %in% top_terms)
    if (break_ties) {
        plot_df <- do.call(rbind, lapply(plot_df %>% group_by(module) %>% 
            group_split, function(x) {
            x[sample(n_terms), ]
        }))
    }
    plot_df <- plot_df %>% mutate(Term = stringr::str_replace(Term, 
        " \\s*\\([^\\)]+\\)", ""))
    plot_df$Term <- wrapText(plot_df$Term, 45)
    plot_df$module <- factor(as.character(plot_df$module), levels = levels(modules$module))
    plot_df <- arrange(plot_df, module)
    plot_df$Term <- factor(as.character(plot_df$Term), levels = unique(as.character(plot_df$Term)))
    if (p_adj) {
        plot_df$p <- plot_df$Adjusted.P.value
    }
    else {
        plot_df$p <- plot_df$P.value
    }
    plot_df <- plot_df %>% drop_na() 
    max_p <- 10 #quantile(-log(plot_df$p), 0.95)
    plot_df$logp <- -log(plot_df$p)
    plot_df$logp <- ifelse(plot_df$logp > max_p, max_p, plot_df$logp)
    p <- plot_df %>% ggplot(aes(x = module, y = Term, size = log10(Combined.Score), 
        color = logp)) + geom_point() + Seurat::RotatedAxis() + 
        ylab("") + xlab("") + labs(color = bquote("-log"[10] ~ 
        "(P)"), size = bquote("log"[10] ~ "(Enrich)")) + scale_y_discrete(limits = rev) + 
        ggtitle(database) + theme(plot.title = element_text(hjust = 0.5), 
        axis.line.x = element_blank(), axis.line.y = element_blank(), 
        axis.text.y = element_text(size = term_size), panel.border = element_rect(colour = "black", 
            fill = NA, size = 1), panel.grid = element_line(size = 0.25, 
            color = "lightgrey"))
    p
}