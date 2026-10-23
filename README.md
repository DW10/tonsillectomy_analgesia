# Intraoperative opioid choice in tonsillectomy

Code and manuscript source for a retrospective electronic patient record (EPR) cohort study of intraoperative opioid choice in adult and paediatric tonsillectomy at UCLH. The paper is written as a **Quarto book**: the prose, each figure and table, the supplementary material and all cross-references are rendered from this repository to HTML, Word (docx) and PDF.

> **Submission status:** pending

## What is (and is not) in this repo

| In the repo | Not in the repo (contact [Dylan](https://github.com/DW10)) |
|----|----|
| Manuscript and supplementary text, figure/table code, rendering set-up | The dataset |
| Dataset construction and analysis scripts | EPR extraction/cleaning pipeline (contains the EPR provider's IP) |
|  | `IMPACTfunctions` helper package (in development) |

## Workflow: three stages on three machines

```         
 1. Hospital TRE            2. Research TRE              3. Render machine
 dataset.qmd, anon.qmd      run_analysis.R               quarto render
 -> data/anon_*.rds   --->  -> export/ (results only) --->  -> _book/, _submission/
```

| Stage | Where | Run | Needs | Produces |
|----|----|----|----|----|
| 1\. Dataset | Hospital TRE | `scripts/peri_op_med_dataset.qmd`, then `scripts/peri_op_med_anon.qmd` | Source data, `IMPACTfunctions`, `scripts/settings.R` | `data/`: the anonymised dataset and sensitivity files (`anon_*.rds`) |
| 2\. Analysis | Research TRE | `Rscript run_analysis.R` | the `data/anon_*.rds` files, `IMPACTfunctions`, `scripts/settings.R` | `export/`: tables, plots, quoted numbers, package citations |
| 3\. Render | Any machine | `quarto render` | the repo plus the `export/` folder; **no patient-level data** | `_book/` (and `_submission/`) |

**What moves between stages**

- **1 to 2:** only `data/anon_dataset.rds`, `data/anon_opioid_sensititvity_df.rds` and `data/anon_readmit_sensititvity_df.rds`, through the approved export route. The identifiable `data/id_*.rds` files never leave the hospital TRE.
- **2 to 3:** only the `export/` folder, after you have checked it holds results only.

**Safeguards**

- `data/` and `export/` are git-ignored, so neither can be committed by accident.
- `data/` is the restricted folder. It holds the stage 1 files and `data/models.rds` (the fitted models, which contain patient-level rows and are used only inside stage 2).
- `export/` must contain summaries only. `run_analysis.R` ends with a check that warns if a saved plot embeds a large data frame; read that warning before you export.

### Stage 2 products (`export/`)

| File | Content |
|----|----|
| `main_objects.rds`, `supp_objects_analysis.rds`, `supp_objects_extra.rds` | `gt` tables and `ggplot`s, named after their figure/table label |
| `upset_adult.png`, `upset_paed.png` | UpSet plots |
| `supp_stats.rds` | Numbers quoted in the supplementary text |
| `inline_values.rds` | Value of every `` `r ...` `` expression in `index.qmd`, `abstract.qmd` and `manuscript.qmd`, so the render needs no dataset |
| `packages/` | R package table and citations (`grateful`) |
| `figures/`, `tables/` | Written by the render stage: one file per figure/table label (journal upload) |

## Running it

1.  Copy `scripts/settings_EXAMPLE.R` to `scripts/settings.R` and fill in the external paths (`functions_paths`, `dataset_path`). Project paths use `here::here()`; the repo root is marked by the `.here` file.

2.  **Stage 1, hospital TRE:** render `scripts/peri_op_med_dataset.qmd` then `scripts/peri_op_med_anon.qmd`. Move the three `data/anon_*.rds` files to the research TRE.

3.  **Stage 2, research TRE:** put the three files in `data/`, then:

    ``` bash
    Rscript run_analysis.R
    ```

    It runs the analysis and supplementary scripts, saves the inline values and package citations, and checks `export/`. A failing chunk stops the run with its real error. Copy `export/` out.

4.  **Stage 3, render machine:** put the `export/` folder in the repo, then:

    ``` bash
    quarto render                  # all formats
    quarto render --to docx        # one format
    ```

    `pre_render.R` runs first. It checks that `export/` is complete (and says what is missing), rebuilds the cross-reference map and clears `export/figures` and `export/tables`, which the render refills.

Optional switches for `pre_render.R`, all off by default: `REFRESH_AUTHORS=true` (author YAML from the plume sheet) and `REFRESH_DIAGRAMS=true` (re-render the Mermaid diagrams, needs node/npx). Example: `REFRESH_AUTHORS=true quarto render`.

## Repo map

| Path | Purpose |
|----|----|
| `index.qmd`, `abstract.qmd`, `manuscript.qmd`, `supplementary_*.qmd`, `references.qmd` | Book source (abstract, manuscript, supplement, references) |
| `_quarto.yml` | Shared settings, cross-reference numbering, authors |
| `run_analysis.R` | Stage 2 coordinator |
| `pre_render.R` | Stage 3 pre-render checks and housekeeping |
| `scripts/peri_op_med_dataset.qmd`, `scripts/peri_op_med_anon.qmd` | Stage 1: build and anonymise the dataset |
| `scripts/peri_op_med_analysis.qmd`, `scripts/peri_op_med_supp_mat.qmd` | Stage 2: main and supplementary tables, plots and models |
| `scripts/export_helpers.R`, `scripts/inline_helpers.R` | `load_objects()` / `show_float()`, and the inline-value formatters |
| `scripts/settings_EXAMPLE.R` | Copy to `scripts/settings.R` (git-ignored) |
| `scripts/plume_authors*.R`, `scripts/package_citations.R`, `scripts/xref_map.R`, `scripts/render_diagrams.sh` | Authors, package citations, cross-reference map, Mermaid diagrams |
| `data/` | Stage 1 outputs and `models.rds` (git-ignored) |
| `export/` | Stage 2 products and the render dump (git-ignored) |
| `_book/`, `_submission/` | Rendered output (git-ignored) |

## How to edit

- **Prose** lives in `index.qmd`, `manuscript.qmd`, `supplementary_tables_and_figures.qmd` and `supplementary_materials.qmd`. Numbers in the prose are typed by hand and must be checked manually after any change to the analysis.

- **Every figure/table is one labelled chunk with a caption**, for example:

  ```{{r}}
  #| label: fig-venn-adult
  #| fig-cap: "**Short title.** Description, abbreviations."
  show_float(main, width = 12, height = 8, scale = 1.5)
  ```

  `show_float()` finds the object from the label (`fig-venn-adult` -\> `main$fig_venn_adult`), saves a copy to `export/` named after the label, and prints it.

- **Label prefixes** (the prefix decides the numbering):

  | Prefix | Where | Caption option | Cite with | Renders as |
  |----|----|----|----|----|
  | `fig-` / `tbl-` | main manuscript | `fig-cap` / `tbl-cap` | `@fig-x` / `@tbl-x` | Figure 1 / Table 1 |
  | `sfig-` / `stbl-` | supplementary (on a Div, see below) | caption = last paragraph of the Div | `@sfig-x` / `@stbl-x` | Figure S1 / Table S1 |
  | `sec-` | headings (`## Title {#sec-x}`) |  | `@sec-x` | "Supplementary materials 1.1" (prefix set by `crossref-sec-prefix` in `_quarto.yml`; fixed text in the manuscript via `submission/xref-map.yml`) |

- **Supplementary floats** are Quarto *custom cross-reference types*, which only work on a Div (not on chunk options). The Div carries the label, the chunk inside is named `chunk-<label>` (so `show_float()` can find the object), and the caption is the last paragraph:

  ````         
  ::: {#sfig-venn-paed}
  ```{r}
  #| label: chunk-sfig-venn-paed
  #| fig-width: 18
  #| fig-height: 12
  show_float(supp, width = 12, height = 8, scale = 1.5)
  ```

  **Short title.** Description, abbreviations.
  :::
  ````

- **Add or move a figure/table:** (1) compute it in the relevant `scripts/` file and add it to the saved list under the label with `-` -\> `_`; (2) add a labelled chunk with a caption where it should appear. Order and numbering update automatically.

- Captions use the form `**Short title.** Description.` and must exist for every float. Chunks whose caption still reads `TODO: caption to be supplied by the authors.` need one.

- Mermaid diagrams (`fig-mermaid-groups`, `sfig-dag`) live in `diagrams/*.mmd` and are pre-rendered to `figures/*.png`; re-render with `REFRESH_DIAGRAMS=true quarto render` (runs `scripts/render_diagrams.sh`, needs node/npx) and commit `figures/`. They are *not* written to `export/` automatically.

## Render profiles

| Command | Output |
|----|----|
| `quarto render` | General render (`website` profile, the default): the all-in-one book as HTML, `tonsillectomy_manuscript.pdf` and `tonsillectomy_manuscript.docx` in `_book/` |
| `quarto render --profile submission` | Journal submission files in `_submission/`: `cover-letter.docx`, `manuscript.docx` (title page, no figures or tables), `figures-tables.docx` (all figures and tables with lists), `supplement.docx`, and `figures/` (300 dpi PNG named `Figure_1`, `Figure_S1`, ... with `figure_index.txt` mapping them to labels) |

- `_quarto.yml` holds shared settings (bibliography, cross-reference types, execute options) **and the author/affiliation block, the single source of truth** for all profiles. Do not add lists (`chapters`, `render`, `filters`) here: profile lists are appended, not replaced.
- `_quarto-website.yml` holds the book configuration and output formats.
- `_quarto-submission.yml` holds the submission configuration.
- **Page numbers**: Word outputs use `submission/reference.docx` (centred PAGE-field footer); the PDF uses `submission/pdf-page-numbers.tex`.
- **Title page**: `title-page.lua` builds it for any submission document with `title-page: true` (currently `submission/manuscript.qmd`): title, numbered author affiliations, the corresponding author's e-mail, and keywords (set under `keywords:` in the wrapper, shown in the given order). Everything else comes from the plume-managed author block in `_quarto.yml`.
- **Submission manuscript without floats**: `submission/manuscript.qmd` also includes the supplementary chapters inside a `.supp-only` block, so Quarto numbers every Figure / Table / Figure S / Table S exactly as in the book. After cross-references are resolved `submission-split.lua` (post-quarto) deletes all floats and the `.supp-only` block, leaving prose whose references are correct. `@sec-sm-*` references cannot be numbered outside the book, so `xref-hardcode.lua` replaces them with fixed text from `submission/xref-map.yml`, which `scripts/xref_map.R` regenerates from the headings of `supplementary_materials.qmd` on every render (do not edit it by hand; numbering assumes `##` = section 1, 2, ... in the supplement document).
- **Cover letter and supplement**: `submission/cover-letter.qmd` includes `index.qmd`; `submission/supplement.qmd` includes `supplementary_materials.qmd` with `number-sections: true` and `shift-heading-level-by: -1` so its `##` headings become sections 1, 2, ... (matching `submission/xref-map.yml`). The "Cover letter" / "Supplementary materials" chapter headings and the "Reviewer notes" callout are `content-visible when-profile="website"`, so they only appear in the book.
- **Figures and tables file**: `submission/figures-tables.qmd` includes the manuscript and both supplementary chapters; `submission-split.lua` (`submission-keep: floats`) keeps only the floats and adds a List of figures and a List of tables, then Main figures, Main tables, Supplementary figures and Supplementary tables, one float per page. `float-order.lua` records each float's label in document order so the filter can number and title them. The lists have no page numbers.
- **Figures folder**: `submission/post-render.R` runs after the submission render. It moves the Word files up into `_submission/` and builds `_submission/figures/` from `export/figures/` (PNGs written by `show_float()`) and the hand-made `figures/*.png` (mermaid / DAG), numbered in document order. It warns if a figure has no saved image.
- **R package table and citations**: `run_analysis.R` (stage 2, where the analysis packages are installed) calls `scripts/package_citations.R`, which finds the packages used with `renv::dependencies()` and cites them with [grateful](https://pakillo.github.io/grateful/). It writes `export/packages/grateful-refs.bib` and `export/packages/packages.csv`; `supplementary_materials.qmd` prints the table (Table S, `stbl-r-packages`). The website profile adds the bib to the book reference list; in the submission profile only `supplement.docx` loads it.
- **Authors** come from the shared plume Google sheet. By default the author YAML is left untouched. With `REFRESH_AUTHORS=true`, `pre_render.R` runs `scripts/plume_authors.R` to rewrite the `author:` / `affiliations:` keys of `_quarto.yml` from the sheet. Edit authors in the sheet, not in the YAML. If Google sign-in or the network is unavailable it warns and keeps the existing YAML.

Render artefacts (`*_cache/`, `index.tex/.typ/.aux/.log/.toc`, `_book/`, `_submission/`) are git-ignored. If a render misbehaves, delete the caches or run `quarto render --cache-refresh`.

Requires Quarto \>= 1.4 (custom "Figure S"/"Table S" cross-reference types), R, and the packages listed in the `Dockerfile`. Add a `bibliography:` (see `_quarto.yml`) before the first render with citations.

## Docker and working in a TRE

The `Dockerfile` builds an image (R, Quarto, LaTeX and all R packages incl. `ggconsort`) for stages 2 and 3.

``` bash
docker build -t tonsillectomy_analgesia .
docker run --rm -it -v "$PWD":/home/rstudio/tonsillectomy_analgesia tonsillectomy_analgesia bash
```

Inside the container, copy the stage inputs into `data/` (stage 2) or `export/` (stage 3), make `scripts/settings.R`, and run the commands above. Notes for TREs:

- Patient-level data never leaves its TRE. Only the three `data/anon_*.rds` files move from the hospital TRE to the research TRE, and only `export/` moves on from there.
- `IMPACTfunctions` is not public: put its scripts in the folder named by `functions_paths` in `settings.R`.
- A TRE usually has no internet. Build the image outside and import it, or use an approved package mirror; `quarto install tinytex` and `devtools::install_github()` need access.
- Everything is located relative to the repo (`here::here()`, marked by `.here`), so clone the repo anywhere.
- To test a render against a RAM budget, use `bash scripts/render_limited.sh [--to docx]` (`MEM_GB=1.5` to change the cap; default 2). It sets `R_MAX_VSIZE`, which caps R's memory only. For a hard limit on everything (pandoc, LaTeX, Chrome), run the container with `docker run --memory=2g --memory-swap=2g ...`. Quarto has no memory setting of its own.
- Rendering (stage 3) is the memory-hungry step, which is why it runs apart from the analysis. If a render looks stale, try `quarto render --cache-refresh`.
