FROM rocker/tidyverse

RUN apt-get update && apt-get install -y libudunits2-dev libproj-dev libgdal-dev

RUN Rscript -e "install.packages(c('lme4', 'broom.mixed', 'ggplot2', 'arrow','cli','gt', 'broom.mixed', 'ggvenn', 'finalfit', 'tableHTML', 'patchwork', 'ggconsort', 'arrow', 'lme4', 'ggpubr'))"