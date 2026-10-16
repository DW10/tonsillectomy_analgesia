# Environment for running the analysis and rendering the book (see README.md, "Docker and TREs").
# rocker/tidyverse already ships R, pandoc and Quarto (>= 1.4 is needed for the Figure S / Table S types).
FROM rocker/tidyverse

RUN apt-get update && apt-get install -y libudunits2-dev libproj-dev libgdal-dev

RUN Rscript -e "install.packages(c('lme4', 'lmerTest', 'broom.mixed', 'ggplot2', 'arrow', 'cli', 'gt', 'ggvenn', 'finalfit', 'tableHTML', 'patchwork', 'ggpubr', 'here', 'remotes', 'UpSetR', 'knitr', 'webshot2', 'grateful', 'renv', 'gridExtra', 'plume', 'googledrive', 'googlesheets4'))"
RUN Rscript -e "devtools::install_github('tgerke/ggconsort')"

# LaTeX for the PDF output
RUN quarto install tinytex --no-prompt

WORKDIR /home/rstudio/tonsillectomy_analgesia
