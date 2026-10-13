# Intraoperative opioid choice in tonsillectomy

Code and manuscript source for a retrospective electronic patient record (EPR) cohort study of intraoperative opioid choice in adult and paediatric tonsillectomy at UCLH. The paper is written as a **Quarto book**: the prose, each figure and table, the supplementary material and all cross-references are rendered from this repository to HTML, Word (docx) and PDF.

> **Submission status:** pending

## What is (and is not) in this repo

| In the repo | Not in the repo (contact [Dylan](https://github.com/DW10)) |
|------------------------------------|------------------------------------|
| Manuscript and supplementary text, figure/table code, rendering set-up | The dataset |
| Dataset construction and analysis scripts | EPR extraction/cleaning pipeline (contains the EPR provider's IP) |
|  | `IMPACTfunctions` helper package (in development) |

## Repo map

| Path | Purpose |
|------------------------------------|------------------------------------|
| `index.qmd` | Abstract |
| `manuscript.qmd` | Manuscript body. Main figures/tables print **in place** (see `<!-- INSERT: label -->` comments) |
| `supplementary_tables_and_figures.qmd` | Supplementary tables and figures (appendix part of the book) |
| `supplementary_materials.qmd` | Supplementary methods, sensitivity analyses and models (appendix part of the book) |
| `references.qmd` | Reference list |
| `_quarto.yml` | Book settings, output formats, cross-reference numbering, authors |
| `pre_render.R` | Runs before every render: clears `export/`, checks analysis outputs, optionally re-runs the analysis |
| `scripts/peri_op_med_dataset.qmd` | Stage 1: build the study dataset from source data (hospital TRE) |
| `scripts/peri_op_med_anon.qmd` | Stage 2: anonymise the dataset |
| `scripts/peri_op_med_analysis.qmd` | Stage 3: compute main + supplementary figures, tables and models |
| `scripts/peri_op_med_supp_mat.qmd` | Stage 4: compute remaining supplementary tables/figures (sensitivity, model diagnostics) |
| `scripts/export_helpers.R` | `load_objects()` / `show_float()` used by the book chapters |
| `scripts/settings_EXAMPLE.R` | Copy to `scripts/settings.R` and fill in paths (git-ignored) |
| `scripts/plume_authors*.R` | Refresh author list from the plume source sheet |
| `data/` | All generated data (git-ignored except `placeholder.md`) |
| `export/figures`, `export/tables` | Generated dump of every figure/table, one file per label (git-ignored) |
| `_book/` | Rendered output (git-ignored) |

## How the pieces fit together

```         
dataset.qmd -> anon.qmd -> analysis.qmd -> supp_mat.qmd -> data/*.rds
                                                             |
                  quarto render:  manuscript.qmd + supplementary_*.qmd read data/*.rds
                                  -> _book/ (html, docx, pdf)  +  export/ (one file per label)
```

The `scripts/` analysis files only **compute**. They save finished `gt` tables and `ggplot`s to `data/*.rds` (named after the figure/table label). The book chapters then print each object in a labelled chunk with a caption. Rendering the book therefore does not need the raw data, only the saved `data/*.rds` files.

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
  |---------------|---------------|---------------|---------------|---------------|
  | `fig-` / `tbl-` | main manuscript | `fig-cap` / `tbl-cap` | `@fig-x` / `@tbl-x` | Figure 1 / Table 1 |
  | `sfig-` / `stbl-` | supplementary (on a Div, see below) | caption = last paragraph of the Div | `@sfig-x` / `@stbl-x` | Figure S1 / Table S1 |
  | `sec-` | headings (`## Title {#sec-x}`) |  | `@sec-x` | Section number |

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

- Mermaid diagrams (`fig-mermaid-groups`, `sfig-dag`) are written in the chapter itself. They are *not* written to `export/` automatically.

## How to run the whole analysis

1.  Copy `scripts/settings_EXAMPLE.R` to `scripts/settings.R` and fill in the paths.

2.  Run `scripts/peri_op_med_dataset.qmd` **inside the hospital TRE** to produce the study dataset in `data/`.

3.  Run `scripts/peri_op_med_anon.qmd` to produce the anonymised dataset (`data/anon_dataset.rds` and sensitivity files). Transfer these to the research TRE.

4.  In the research TRE, compute figures/tables/models and render the book:

    ``` bash
    RUN_ANALYSIS=true quarto render
    ```

    This runs `scripts/peri_op_med_analysis.qmd` then `scripts/peri_op_med_supp_mat.qmd` (via `pre_render.R`), then renders HTML, docx and PDF into `_book/`, and writes every figure and table to `export/figures/` and `export/tables/` named after its label (e.g. `export/figures/fig-venn-adult.png`, `export/tables/tbl-demo-all.docx`).

5.  If `data/*.rds` already exists (e.g. copied from the TRE), render anywhere without data:

    ``` bash
    quarto render                  # all formats
    quarto render --to docx        # one format
    ```

Requires Quarto \>= 1.4 (custom "Figure S"/"Table S" cross-reference types), R, and the packages listed in the `Dockerfile`. Add a `bibliography:` (see `_quarto.yml`) before the first render with citations.

## Docker and working in a TRE

The `Dockerfile` builds an image (R, Quarto, LaTeX and all R packages incl. `ggconsort`) so the analysis is reproducible inside a TRE that allows containers.

``` bash
docker build -t tonsillectomy_analgesia .
docker run --rm -it -v "$PWD":/home/rstudio/tonsillectomy_analgesia tonsillectomy_analgesia bash
```

Inside the container, mount or copy the data into `data/`, make `scripts/settings.R`, and run the commands above. Notes for TREs:

- The dataset never leaves its TRE. Only `data/anon_dataset.rds` (and the sensitivity files) move from the hospital TRE to the research TRE, through the approved export route.
- `IMPACTfunctions` is not public: put its scripts in the folder named by `functions_paths` in `settings.R`.
- A TRE usually has no internet. Build the image outside and import it, or use an approved package mirror; `quarto install tinytex` and `devtools::install_github()` need access.
- Everything is located relative to the repo (`here::here()`), so clone the repo anywhere inside the TRE.
- If a render looks stale, try `quarto render --cache-refresh`.

## 
