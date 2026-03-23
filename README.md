# tonsillectomy_analgesia
This repository contains the code to produce the dataset and analysis of a manuscript submission to analyse the peri-operative analgesia in tonsillectomy patients.  

> Submission details
>
> The submission is currently pending, to be updated when submitted. 

# Repo instructions:

To fully complete the analysis pipeline you will need the following components that are not supplied in this repo. 

1) Dataset - Not publicly published as psudo-anonomised patient information
2) Dataset cleaning and extraction pipeline - Not publicly available as contains IP of the EPR provider.
3) Functions package - Not published as currently under development under the name `IMPACTfunctions`

If you feel you require any parts of this data/code please contact the [Dylan](https://github.com/DW10)

# How to use

1) Complete the fields in `scripts/settings_EXAMPLE.R` and rename to `settings.R`
2) Run `peri_op_med_dataset.qmd` to produce the study dataset (`df`) that is saved to `/data`
3) Run `peri_op_med_analysis.qmd` and `peri_op_med_supp_matt.qmd` to generate the main tables/figures and supplementary materials respectively. 


# Notes

## Notes on figures and tables
All of the tables and figures are generated dynamically by the code with a few notable exceptions:

Table 1 - Hard coded in markdown in `peri_op_med_analysis.R`
Figure 1 - A mermaid diagram that was exported from the mermaid website online tool. Mermaid code held in comments. 

Various tables in supplementary materials are hard coded in markdown as they are mostly describing constants unchanged in the analysis. 
