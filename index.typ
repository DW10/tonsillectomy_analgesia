// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Intraoperative Opioid Choice in Adult and Paediatric Tonsillectomy: A Retrospective Electronic Patient Record Cohort Study],
  author: "Dylan Whitaker, Yogini H Jani, Steve Harris, Peter Thomas, Alison Carter, James Bedford, Ramani Moonesinghe, Matthew Wilson",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(figure.where(kind: "quarto-float-sfig")).update(0)
  counter(figure.where(kind: "quarto-float-stbl")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Abstract]
<abstract>
#heading(level: 2, numbering: none)[Background]
<background>
Severe pain following tonsillectomy is common and an important cause of delays to discharge and secondary postoperative complications. Clinical guidelines offer a range of perioperative analgesia recommendations but the optimal intraoperative opioid strategy remains unknown. This study aimed to evaluate existing variation in perioperative analgesic management and its impact on postoperative outcomes at a high-volume surgical centre.

#heading(level: 2, numbering: none)[Methods]
<methods>
A retrospective cohort study was performed to identify all patients undergoing tonsillectomy, adenoidectomy or combined adenotonsillectomy over a 7-year period using routinely collected data from the electronic patient record. Medication exposure and outcomes were extracted, and patients grouped on analgesic exposure to simple analgesia (paracetamol, dexamethasone and diclofenac), plus or minus additional morphine, fentanyl or both. Descriptive analysis of the analgesic exposure, treatment groups and multilevel modelling was performed.

#heading(level: 2, numbering: none)[Results]
<results>
3,656 patients were included, of which 2,259 (61.8%) were paediatric patients. 82.9% of adults received all three components of simple analgesia compared to 72.0% of paediatric patients. Fentanyl was the most common intraoperative opioid in the paediatric cohort (95.4% of cases) but adults received a mix of strategies, with 49.0% receiving fentanyl only (n = 685), 22.8% morphine only (n = 318), 17.7% receiving both (n = 247), and 10.5% receiving neither (n = 147). There was no significant difference in the need for recovery opioids between treatment groups for adult patients, however simple analgesia with both morphine and fentanyl resulted in a reduced time in recovery (-42.1 minutes, 95% CI -66.7 to -17.5).

#heading(level: 2, numbering: none)[Conclusions]
<conclusions>
Intraoperative opioid strategies varied for adults undergoing tonsillectomy procedures, but were more homogeneous in paediatric patients. When accounting for patient, surgical and anaesthetic factors, a combined opioid regime of fentanyl and morphine with complete simple analgesia was associated with better odds of same day discharge and shorter time in hospital. This treatment plan was not associated with an increased odds of opioid prescriptions on discharge nor representations to the emergency department. Further work to address the limitations of data quality and possible causality is needed to build evidence for intra-operative opioids in tonsillectomy.

#heading(level: 2, numbering: none)[Keywords:]
<keywords>
Tonsillectomy, Analgesia, Pain, Opioids, Retrospective, Multi-level modelling

= Manuscript
<manuscript>
== Background
<background-1>
Tonsillectomy and adenoidectomy are high-volume surgical procedures. In the UK nearly 30,000 tonsillectomies are performed each year, typically for managing recurrent tonsillitis and/or sleep disordered breathing.@reidReturnTheatrePosttonsillectomy2025@ENTUKTonsillectomy Procedures may be undertaken in combination (adenotonsillectomy) or isolation, depending on the indication, and most are day case procedures.

After tonsillectomy, severe postoperative pain is common. #cite(<gerbershagenPainIntensityFirst2013>, form: "prose") Severe pain in the immediate postoperative period is distressing, delays discharge from hospital and increases healthcare costs. Severe pain after discharge reduces oral intake and increase nausea and vomiting, reducing mechanical debridement of the fibrinous exudate in the tonsillar fossa and increasing the risk of infection and secondary bleeding. Poorly controlled pain, postoperative infection and secondary bleeding are the leading causes of representation to primary care and emergency departments.@ovesenPainBleedingAre2012@tolskaSystematicReviewAnalgesics2019

A recent systematic literature review and meta-analysis by the PROSPECT group generated nine recommendations for pain management across the perioperative period. #cite(<aldamlujiPROSPECTGuidelineTonsillectomy2021>, form: "prose") Pre- and intraoperative recommendations are treatment with paracetamol, a non-steroidal anti-inflammatory (NSAID) drug, and dexamethasone. The group recommend the addition of a non-opioid analgesic (ketamine, Gabapentinoid, or dexmedetomidine), where there was a contraindication to the basic analgesic regimen described. Several studies examined the intraoperative use of tramadol; however, the authors were unable to reach a recommendation for its use due to a lack of available safety data. Recommendations regarding the perioperative use of opioid medications were confined to a suggestion that they should be reserved as rescue agents in the immediate postoperative period, however the authors note a lack of available evidence regarding the effectiveness and safety profile of opioid medications in the intra- and postoperative periods.

Despite the large volume of these procedures undertaken, there remains little data as to the optimal intraoperative analgesic regimen, the comparative effectiveness of different strategies in general, and different approaches to intraoperative opioid use in particular. The increasing availability of routinely collected patient data from electronic patient records (EPR) offers an opportunity to assess perioperative analgesic strategies at scale. Patient, surgical and anaesthetic variables relevant to perioperative pain can now be accessed and incorporated in greater detail than previously possible. In this study we aimed to use routinely collected EPR data to map analgesic practices for adults and children undergoing tonsillectomy and adenotonsillectomy and describe existing variation in practice and explore associations between analgesic strategies and postoperative outcomes, thus contributing evidence of existing practices and to generate hypotheses to inform future research.

== Methods
<methods-1>
=== Design, Setting and Population
<design-setting-and-population>
A single centre, retrospective electronic patient record (EPR) cohort study. Patients who underwent elective tonsillectomy, adenoidectomy, or combined adenotonsillectomy were included. Procedures were identified using relevant OPCS Classification of Interventions and Procedures codes (#ref(<sec-sm-data-spec-procedures>, supplement: [Section])).

Data from the Epic (Epic Systems, Wisconsin) EPR for University College London Hospitals NHS Foundation Trust (UCLH), including The Royal National Throat, Nose and Ear Hospital were evaluated. All patients who admitted for surgery between 1st April, 2019 and 17th June, 2026 were included. Data analysis was undertaken using Python (v3.11.13) and R version 4.4.1 (2024-06-14) (#ref(<sec-sm-analysis-code>, supplement: [Section])).

=== Data Specification
<data-specification>
==== Patient and Surgical Factors
<patient-and-surgical-factors>
Using International Classification of Diseases (10) codes, indicators of relevant medical conditions were extracted from the patient's active medical problem list at the time of the surgical encounter. These included indicators of chronic pain states, preoperative opioid dependence, history of recurrent tonsillitis, sleep disordered breathing or obstructive sleep apnoea (#ref(<sec-sm-data-spec-pmh>, supplement: [Section])). Patients were grouped into adult (≥ 18 years) and paediatric (\< 18 years) cohorts based on age on admission to hospital.

==== Perioperative Analgesic Exposure
<perioperative-analgesic-exposure>
Analgesic medication administration was identified from EPR timestamps within both preoperative medication and intraoperative anaesthetic records. Simple analgesics were defined as paracetamol, any selective or non-selective COX inhibitors and dexamethasone. Opioid medications included morphine, fentanyl, oxycodone, diamorphine or tramadol. Intraoperative use of remifentanil infusions were excluded due to their limited role in postoperative analgesia. Non-opioid analgesics examined included clonidine, ketamine and magnesium. Dexmedetomidine is not routinely used at UCLH perioperatively. For each medication, route of administration and dose were extracted across three phases of care: 1) Preoperatively -- four hours before procedure start, 2) Intraoperatively -- start of anaesthesia to end of procedure, and 3) Postoperatively -- from entry into recovery area to time of hospital discharge. Combined opioid dosing was calculated using oral morphine equivalents (OME, milligrams) using standard methods (#ref(<sec-sm-analysis-code>, supplement: [Section])). For paediatric patients, doses were adjusted for weight and presented as milligrams per kilogram (mg kg-1).

==== Intraoperative Analgesic Strategy
<intraoperative-analgesic-strategy>
To explore the prevalence and effectiveness of different analgesic strategies and the perioperative use of opioids, four clinically relevant treatment groups were predefined (#ref(<fig-mermaid-groups>, supplement: [Figure])). Group 1 represents a simple analgesic strategy without opioids (in line with current PROSPECT guidance) and includes patients administered paracetamol during the pre or intraoperative phases), a NSAID and dexamethasone. Group 2 and 3 include patients receiving simple analgesia plus an intraoperative opioid (morphine or fentanyl respectively). Group 4 represents patients who received simple analgesia with both morphine and fentanyl intraoperatively. Patients receiving non-opioid analgesics (clonidine, ketamine, magnesium) were analysed separately.

#figure([
#box(image("figures/fig-mermaid-groups.png"))
], caption: figure.caption(
position: bottom, 
[
#strong[Flow chart of treatment group criteria.] Flowchart describing logic for eligibility for the treatment groups depending on the medications received.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-mermaid-groups>


=== Outcome Measures
<outcome-measures>
The primary outcome measure was rescue opioid medication, defined as the administration of any opioid drug within three hours of the end of the procedure and recording dose and frequency of administration. This was chosen as a quantitative measure of intraoperative analgesic effectiveness during the immediate postoperative period. A sensitivity analysis was conducted to assess different time cut-offs for opioid administration within the initial recovery period (#ref(<sec-sm-sensitivity-opioid>, supplement: [Section])). Secondary outcomes were chosen to reflect a range of process and effectiveness measures directly relevant to tonsillectomy patients. These were: time spent in first-stage recovery (a key determinant of patient flow for day case procedures and influenced by over or under administration of analgesia) and numerical pain score at rest (0-4) for the first three postoperative hours. Length of hospital admission was calculated from day of procedure to hospital discharge. The number and details of opioid prescriptions for postoperative analgesia on hospital discharge were extracted and grouped into ‘weak' or ‘strong' opioids as per World Health Organisation definitions (#ref(<sec-sm-data-spec-discharge>, supplement: [Section])). Data pertaining to return to theatre and re-presentation to the UCLH emergency department within 7, 14 and 30 postoperative days and in-hospital, 30 day and one year mortality were also reported where available.

=== Statistical Analysis
<statistical-analysis>
The variables listed were described using absolute numbers (percentages) for categorical variables, parametrically distributed variables are shown as means (standard deviations and medians (interquartile ranges) are presented for non-parametric variables. Descriptions for analgesic exposure, perioperative analgesic strategy and outcome variables are presented, stratified by adult and paediatric cohorts, and surgical subgroups. Multilevel modelling was used to investigate the association between analgesic strategy the primary and secondary outcomes, accounting for clinically relevant co-variants selected using expert domain knowledge and directed acyclic graphs (#ref(<sec-sm-modelling-dag>, supplement: [Section])). Models were constructed for each outcome measure, with anaesthetic consultant identity incorporated as a random effect. Where the anaesthetic consultant identifier was not associated with five or more cases, these were excluded following a sensitivity analysis (#ref(<sec-sm-sensitivity-group-size>, supplement: [Section])).

== Results
<results-1>
=== Study Population
<study-population>
3,656 patients had a surgical encounter matching the predefined OPCS codes during the study period. #ref(<tbl-demo-all>, supplement: [Table]) shows the demographics of both adult and paediatric cohorts.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 4,
  align: (left,left,left,left,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adult cohort], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Paediatric cohort],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Total encounters (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1397 (38.2)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[2259 (61.8)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Age (years)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[29.00 (23.00 to 38.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[7.00 (5.00 to 10.00)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Height (cm)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[168.47 (162.48 to 176.98)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[122.98 (110.46 to 140.48)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Weight (kg)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[74.40 (63.20 to 89.75)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[24.40 (18.80 to 37.30)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Sex], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[Female], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[903 (64.6)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1002 (44.4)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Male], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[494 (35.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1257 (55.6)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Gender Identity], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[Female], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[36 (64.3)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[2 (50.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Male], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20 (35.7)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (50.0)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Ethnicity], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[White], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[562 (60.2)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[777 (46.1)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Asian], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[103 (11.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[278 (16.5)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Black], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[96 (10.3)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[269 (16.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mixed], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56 (6.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[149 (8.8)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Other], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[117 (12.5)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[213 (12.6)],
)}
], caption: figure.caption(
position: top, 
[
#strong[Demographics table - All patients.] Participant baseline demographics and clinical history stratified by adult and paediatric cohorts. Categorical data as number (%). IQR (Interquartile Range), EPR (Electronic Patient Record). Missing data count and proportion of total cohort presented
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-demo-all>


Isolated tonsillectomy was the most common procedure in the adult cohort (n = 1,247, 89.3%; #ref(<tbl-demo-adult>, supplement: [Table])), whilst paediatric patients predominantly underwent adenotonsillectomy (n = 1,292, 57.2%; #ref(<stbl-demo-paed>, supplement: [Table S])).

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 6,
  align: (left,left,left,left,left,left,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Tonsillectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adenoidectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adenotonsillectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Total],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Total encounters (%)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[1247 (89.3)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[111 (7.9)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[39 (2.8)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1397],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Age (years)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[29.00 (24.00 to 38.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[27.00 (21.00 to 35.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[27.00 (21.50 to 35.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[29.00 (23.00 to 38.00)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Height (cm)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[167.99 (162.56 to 176.98)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[170.99 (162.79 to 178.99)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[163.99 (157.36 to 172.24)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[168.47 (162.48 to 176.98)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Weight (kg)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[74.00 (63.00 to 88.45)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[78.50 (67.25 to 95.50)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[83.00 (72.00 to 95.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[74.40 (63.20 to 89.75)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Sex], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Female], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[806 (64.6)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[67 (60.4)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[30 (76.9)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[903 (64.6)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Male], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[441 (35.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[44 (39.6)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9 (23.1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[494 (35.4)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Gender Identity], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Female], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[27 (58.7)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[6 (85.7)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[3 (100.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[36 (64.3)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Male], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19 (41.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1 (14.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20 (35.7)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Ethnicity], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[White], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[510 (61.3)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[38 (47.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[14 (63.6)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[562 (60.2)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Asian], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[86 (10.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15 (18.8)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (9.1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[103 (11.0)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Black], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[77 (9.3)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16 (20.0)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3 (13.6)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[96 (10.3)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mixed], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[49 (5.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5 (6.2)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (9.1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56 (6.0)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Other], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[110 (13.2)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6 (7.5)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1 (4.5)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[117 (12.5)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[ASA physical status], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[587 (47.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[56 (50.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[13 (34.2)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[656 (47.3)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[578 (46.6)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[46 (41.8)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[22 (57.9)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[646 (46.5)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[75 (6.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8 (7.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3 (7.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[86 (6.2)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Chronic Tonsillitis EPR Diagnosis], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Yes], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[905 (72.6)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[96 (86.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[37 (94.9)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1038 (74.3)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Obstructive Sleep Apnoea EPR Diagnosis], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Yes], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[175 (14.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[13 (11.7)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[13 (33.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[201 (14.4)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Opioid dependance EPR Diagnosis], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Yes], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Chronic Pain EPR Diagnosis], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Yes], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[6 (0.5)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[6 (0.4)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Procedure Length (minutes)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[34.00 (24.00 to 48.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[44.00 (23.00 to 66.50)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[45.00 (33.00 to 58.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[35.00 (25.00 to 49.00)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Coblation technique], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Yes], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[38 (3.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1 (0.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[4 (10.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[43 (3.1)],
)}
], caption: figure.caption(
position: top, 
[
#strong[Demographics table - Adult patients.] Participant and surgical data for adult cohort stratified by surgical procedure group. Categorical data as number (%). IQR (Interquartile Range), EPR (Electronic Patient Record).
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-demo-adult>


Across all surgical procedures, 1,038 (74.3%) adults and 2,026 (89.7%) children had an EPR diagnosis of chronic tonsillitis. A diagnosis of OSA was recorded in 201 (14.4%) adults and 1,241 (54.9%) children. \
There was less Coblation use recorded in adult patients compared with children (n = 43 (3.1%) and n = 1,344 (59.5%) respectively).

=== Analgesic Exposure
<analgesic-exposure>
All intraoperative analgesic administration is shown in #ref(<tbl-analgesic-adult>, supplement: [Table]) (adult) and #ref(<stbl-analgesic-paed>, supplement: [Table S]) (paediatric) for each surgical procedure group.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 6,
  align: (left,left,left,left,left,left,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Tonsillectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adenoidectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adenotonsillectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Total],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Paracetamol (including oral premedications)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[1206 (96.7)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[102 (91.9)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[39 (100.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1347 (96.4)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Diclofenac], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[1081 (86.7)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[86 (77.5)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[35 (89.7)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1202 (86.0)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Dexamethasone], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[1228 (98.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[106 (95.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[38 (97.4)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1372 (98.2)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Clonidine], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[38 (3.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1 (0.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[2 (5.1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[41 (2.9)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Ketamine], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[35 (2.8)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[35 (2.5)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Magnesium], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[83 (6.7)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[9 (8.1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[4 (10.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[96 (6.9)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Tramadol], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Oxycodone], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Diamorphine], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Fentanyl], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[833 (66.8)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[70 (63.1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[29 (74.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[932 (66.7)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Fentanyl, Intraoperative Administration, Dose (µg)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[100.00 (100.00 to 150.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[100.00 (100.00 to 100.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[100.00 (100.00 to 200.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[100.00 (100.00 to 150.00)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Morphine], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[551 (44.2)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[2 (1.8)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[12 (30.8)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[565 (40.4)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Morphine, Intraoperative Administration, Dose (mg)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[10.00 (5.00 to 10.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[5.00 (5.00 to 5.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[8.00 (5.00 to 10.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[10.00 (5.00 to 10.00)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Intra-operative opioids given], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[1139 (91.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[72 (64.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[39 (100.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1250 (89.5)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Total intraoperative opioid dose (OME, mg)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[30.00 (20.00 to 40.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[20.00 (20.00 to 20.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[30.00 (20.00 to 37.50)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[30.00 (20.00 to 40.00)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Treatment group], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[76 (8.1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[27 (36.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[103 (9.9)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[232 (24.7)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1 (1.3)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8 (26.7)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[241 (23.1)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[448 (47.7)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[47 (62.7)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21 (70.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[516 (49.4)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[183 (19.5)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1 (3.3)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[184 (17.6)],
)}
], caption: figure.caption(
position: top, 
[
#strong[Anaesthetic management - Adults.] Intraoperative analgesia administration for adult patients stratified by surgical group. OME, Oral Morphine Equivalent.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-analgesic-adult>


==== Simple Analgesia -- Paracetamol, NSAID, Dexamethasone
<simple-analgesia-paracetamol-nsaid-dexamethasone>
Across the adult population, 82.9% (n = 1,158) of patients received a standard simple analgesia combination of paracetamol, diclofenac and dexamethasone (#ref(<fig-venn-adult>, supplement: [Figure]) (A)). Of those that did not receive all three medications, the most common omission was diclofenac (#ref(<fig-venn-adult>, supplement: [Figure]) (B)). In the paediatric cohort 72.0% (n = 1,627) of patients received complete simple analgesia (#ref(<sfig-venn-paed>, supplement: [Figure S]) (A)). \
Paracetamol was given in 98.8% (n = 2,232) of paediatric cases, of which 20.2% (n = 456) was received as an oral dose prior to theatre (#ref(<sfig-venn-paed>, supplement: [Figure S]) (B)). Oral pre-dosing was not common in the adult cohort (4.7%, n = 65), but overall perioperative use was similarly high (96.4%, n = 1,347). There was no use of selective COX-2 inhibitor drugs during the study period.

#figure([
#box(image("manuscript_files/figure-typst/fig-venn-adult-1.svg", alt: "Venn diagrams of adult intraoperative medications"))
], caption: figure.caption(
position: bottom, 
[
#strong[Venn diagrams of adult intraoperative medications.] Distributions of complete intra-operative simple analgesia and intraoperative opioid administration in adults (A). Venn diagram to show the breakdown of the simple analgesia (B) and opioids given (C)
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-venn-adult>


==== Opioid Analgesia
<opioid-analgesia>
89.5% (n = 1,250) of adult patients and 98.3% (n = 2,221) of paediatric patients received a strong opioid medication intraoperatively (#ref(<sec-sm-data-spec-intra-op-meds>, supplement: [Section])). #ref(<tbl-analgesic-adult>, supplement: [Table]) (adult) and #ref(<stbl-analgesic-paed>, supplement: [Table S]) (paediatric) show the breakdown of opioid medication use across each surgical procedure group. \
Across all procedures, a single opioid strategy with fentanyl was most common in children, accounting for 95.4% of cases (n = 2,156; #ref(<sfig-venn-paed>, supplement: [Figure S]) C). Adults received a mix of strategies, with 49.0% (n = 685) receiving fentanyl only, 22.8% (n = 318) morphine only, 17.7% (n = 247) receiving both and 10.5% (n = 147) receiving neither, illustrated in #ref(<fig-venn-adult>, supplement: [Figure]) C). The median intraoperative opioid dose administered to adults was 30mg (OME, IQR = 20-40mg). Patients receiving a regimen of simple analgesia plus morphine only received a median 30mg OME (IQR 15-30mg), contrasting with 20mg OME (IQR 20-30mg) in fentanyl only group, and 50mg (IQR 41-50mg) in the combined opioid group (#ref(<sfig-opioid-histogram-adult>, supplement: [Figure S])). Paediatric patients received a median fentanyl dose of 1.14 mcg.kg-1 (IQR = 0.99 -- 1.85 mcg.kg-1) and a median morphine dose of 0.10 mg.kg-1 (IQR = 0.06 -- 0.10 mg.kg-1).

No patients received oxycodone, diamorphine or tramadol intraoperatively.

==== Non-Opioid Analgesics -- Clonidine, Ketamine, Magnesium
<non-opioid-analgesics-clonidine-ketamine-magnesium>
The use of non-opioid analgesics was generally low across both adult and paediatric cohorts (#ref(<sfig-venn-adjuncts>, supplement: [Figure S])). 4.3% (n = 157) of patients received either clonidine, ketamine and or magnesium. Clonidine was used in 2.9% (n = 41) of adult cases and 0.1% (n = 3) of paediatric cases, whilst ketamine was used in 2.5% (n = 35) of adult cases and 0.0% (n = 1) of paediatric cases. Magnesium was used in 6.9% (n = 96) adult cases and 0.2% (n = 4) paediatric cases.

==== Combined Analgesic Strategies
<combined-analgesic-strategies>
Across the adult cohort, the most common analgesic combination seen was Group 3 (n = 516, 36.9% of all adult patients), followed by Group 2 (n = 241, 17.3%) and Group 4 (n = 184, 13.2%)(#ref(<tbl-analgesic-adult>, supplement: [Table])). #ref(<fig-upset-adult>, supplement: [Figure]) shows the relative distribution of the different possible combinations of intraoperative analgesic agents.

#figure([
#box(image("data/upset_adult.png", alt: "UpSet graph of the combinations of adult intraoperative analgesia"))
], caption: figure.caption(
position: bottom, 
[
#strong[UpSet graph of the combinations of adult intraoperative analgesia.] Distribution of the different analgesic combinations for adults patients. Upper vertical bar graph showing the total count of each combination of analgesia with treatment groups coloured. Lower left horizontal bar graph showing the total count of patients receiving each specific medication.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-upset-adult>


Across the paediatric cohort less heterogeneity in the analgesic combinations was observed (#ref(<sfig-upset-paed>, supplement: [Figure S])). The commonest strategy was Group 3 (n = 1,538, 68.1%), followed by Group 4 (n = 52, 2.3%). 28.0% (n = 632) of the paediatric cohort did not receive a complete combination of simple analgesia (paracetamol, NSAID and dexamethasone).

=== Outcomes
<outcomes>
Across all surgical procedure groups, 55.7% (n = 778) of adult patients required rescue opioid administration in the first three postoperative hours, compared to 4.0% (n = 90) of children. In adults, the median dose of rescue opioid administered was 20mg (OME, IQR = 12.0-20mg), of which 98% was administered as fentanyl (n = 762). The breakdown of administration across each surgical procedure group and secondary outcome measures are shown in #ref(<tbl-outcome-adult>, supplement: [Table]) (adult) and #ref(<stbl-outcome-paed>, supplement: [Table S]) (paediatric).

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 6,
  align: (left,left,left,left,left,left,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Tonsillectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adenoidectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adenotonsillectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Total],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Administration of rescue opioids], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[709 (56.9)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[45 (40.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[24 (61.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[778 (55.7)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Administration of rescue morphine], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[23 (1.8)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[23 (1.6)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Administration of rescue fentanyl], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[693 (55.6)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[45 (40.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[24 (61.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[762 (54.5)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Administration of rescue opioids, (OME mg)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[20.00 (12.00 to 20.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[20.00 (12.00 to 20.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[20.00 (12.00 to 20.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[20.00 (12.00 to 20.00)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Time in Stage 1 recovery (mins)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[71.00 (46.36 to 102.68)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[65.18 (40.81 to 90.11)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[77.63 (62.19 to 98.97)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[70.97 (46.16 to 101.41)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Pain score at rest 3hrs post-op (Median)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[1.00 (0.00 to 2.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0.50 (0.00 to 1.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1.00 (0.00 to 2.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1.00 (0.00 to 2.00)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Length of Stay (days)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0.44 (0.38 to 0.56)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0.36 (0.30 to 0.44)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0.42 (0.37 to 0.76)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0.43 (0.38 to 0.55)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Same day discharge], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[951 (76.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[92 (82.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[29 (74.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1072 (76.7)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Paracetamol on discharge], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[643 (51.6)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[12 (10.8)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[25 (64.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[680 (48.7)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[NSAID on discharge], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[770 (61.7)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[11 (9.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[25 (64.1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[806 (57.7)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Strong opioid perscribed on discharge], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[19 (1.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[19 (1.4)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[New strong opioids on discharge], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (NaN)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (NaN)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (NaN)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (NaN)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Weak opioid on discharge], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[1070 (85.8)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[23 (20.7)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[31 (79.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1124 (80.5)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Return to theatre within 7 days], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[7 (0.6)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[7 (0.5)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Return to theatre within 14 days], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[15 (1.2)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[15 (1.1)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Return to theatre within 30 days], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[19 (1.5)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[19 (1.4)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Represented to ED before 7 days], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[167 (13.4)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[4 (3.6)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[2 (5.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[173 (12.4)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Represented to ED before 14 days], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[229 (18.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[8 (7.2)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[6 (15.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[243 (17.4)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Represented to ED before 30 days], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[235 (18.8)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[9 (8.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[6 (15.4)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[250 (17.9)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Died during admission], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[1 (0.1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1 (0.1)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Mortality (90 days)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[1 (0.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1 (0.1)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Mortality (1 year)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[4 (0.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[4 (0.3)],
)}
], caption: figure.caption(
position: top, 
[
#strong[Adult outcomes.] Outcome data for adult patients stratified by surgical group. Return to theatre at UCLH and representation to UCLH emergency department only, cumulative measures at each time point. Eligible medications for discharge measured as classified in #ref(<sec-sm-data-spec>, supplement: [Section]).
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-outcome-adult>


Adults spent a median 71.0 minutes (IQR = 46.2 -- 101.4 minutes) in first stage recovery, with 76.7% (n = 1,072) going to be discharged home the same day. The median length of stay from admission to hospital discharge was 0.43 days (IQR = 0.38-0.55). Most adults (80.5%, n = 1,124) received a weak opioid prescription on discharge. 19 (1.4%) adult patients received a strong opioid prescription on discharge, all of which were continuations of an existing preoperative opioid prescription. There were no newly initiated strong opioid prescriptions. Children spent a median 27.6 minutes (IQR = 18.6 -- 37.5 minutes) in first stage recovery, with 94.4% (n = 2,132) going on to be discharged the same day. 33.6% (n = 760) were discharged with paracetamol, 30.9% (n = 699) with an NSAID, with 33 (1.5%) receiving a weak opioid prescription and 5 (0.2%) receiving a strong opioid prescription; of which all were a continuation of a pre-admission strong opioid. \
Rates of return to theatre were low with 1.4% (n = 19) of adults and 0.3% (n = 7) paediatric cases returning within 30 days. 1 adult patient died during the surgical encounter. Across the whole study sample, the representation rate to the study centre's emergency department (ED) within 30 days was 10.4% (n = 380), 17.9% (n = 250) in adults and 5.8% (n = 130) in children. A manual review of 50 randomly selected cases representing to the ED showed that 52% (n =26) were related to bleeding, 38% (n = 19) related to pain control, 4% (n = 2) with symptoms of infection. Three patients represented for reasons unrelated to surgery. Of the 50 cases reviewed, 55% (n = 26) were admitted to hospital for further treatment.

=== Association of Analgesic Strategy with Outcomes
<association-of-analgesic-strategy-with-outcomes>
For the primary outcome measure, unadjusted (rescue analgesia and analgesic group) and adjusted models (incorporating clinically relevant covariates as fixed effects) are presented. #ref(<sfig-consort-modelling>, supplement: [Figure S]) shows the composition of adult and paediatric cohorts used for model construction and the distribution of the associated treatment groups. Given the lack of observed variation in the analgesic and opioid practices for the paediatric cohort, this analysis was confined to the adult cohort.

==== Adults
<adults>
After applying exclusion criteria, 975 patients were included in the analysis. The most common analgesic group was 3 (n = 474, 48.6%), followed by 2 (n = 232, 23.8%), 4 (n = 170, 17.4%) and 1 (n = 99, 10.2%). \
An unadjusted generalised linear mixed effects model (model 1) examining the association of rescue opioid administration with analgesic group (using group 1 as a reference) and nested by anaesthetic consultant identity demonstrated a 63.3% chance of receiving rescue opioids in recovery for patients who did not receive any intraoperative opioid (group 1). Group 4 (simple analgesia plus morphine and fentanyl) demonstrated a significant negative association (OR 0.283, 95% CI 0.165-0.486). Anaesthetist identity accounted for 5.0% (SD 22%) of the observed variation in the unadjusted model. \
After adjusting for age, sex, surgical procedure type, ASA, chronic pain history, procedure length, use of a Coblation technique and intraoperative opioid dose (model 2), the association observed for Group 4 was no longer significant (OR 0.418, 95% CI 0.16-1.09). Variation associated with the individual anaesthetist was 4.1% (SD 20%).

The same model parameters were used to evaluate the secondary outcomes (#ref(<sfig-forrest-plot>, supplement: [Figure S])). Treatment group 4 showed a reduced time in recovery (-42.1 minutes, 95% CI -66.7 to -17.5) and an increased, but not significant, odds ratio of 3.17 of same day discharge (95% CI 0.961 to 10.5). Modelling of pain scores was not possible due to the lack of distribution in data and the model of presentations to the emergency department was non-significant with low confidence (#ref(<sec-sm-modelling>, supplement: [Section])).

== Discussion
<discussion>
This single-centre, retrospective EPR cohort study investigated the intraoperative use of opioid medications in adult and paediatric patients undergoing tonsillectomy and adenotonsillectomy. Using routinely collected electronic patient data for 3,656 patients we were able to examine patient, surgical and anaesthetic variables relating to perioperative analgesic management and intraoperative opioid administration. The majority of patients (76.2%, n = 2,785) received the combination of simple analgesia recommended by the current PROSPECT guidelines (paracetamol, NSAID, and dexamethasone). Additionally, 94.9% of adults and children received an intraoperative opioid medication. In children, most (95.4%, n = 2,156) received a single opioid regimen of fentanyl, at a median dose of 1.14 mcg.kg-1 (IQR 0.99-1.85 mcg.kg-1). Opioid strategies in adults were less uniform, with 49.0% (n = 685) receiving a fentanyl-only strategy, 22.8% (n = 318) receiving morphine only, and 17.7% (n = 247) receiving both.

To investigate the association between opioid technique and immediate postoperative outcomes, patients were categorised into one of four treatment groups based on the receipt of full simple analgesia, simple analgesia plus a single opioid (fentanyl or morphine) and simple analgesia plus both opioid medications. Patients who received additional non-opioid analgesia were excluded. Due to the lack of opioid variation in the paediatric cohort this analysis was confined to adults. Patients in the combined opioid group received a higher median dose (50mg vs.~20mg vs.~30mg OME) compared with the morphine and fentanyl-only groups respectively, indicating clinicians had different dosing strategies in addition to opioid preferences.

Multilevel modelling, accounting for the individual anaesthetic consultant and adjusting for a range of clinically relevant patient, surgical and anaesthetic covariates revealed no statistically significant association between type of opioid and receipt of rescue analgesia in the first three postoperative hours compared to the simple analgesia only group. However, the fentanyl-only (23.4 minutes 95% CI 6.8 -- 40.0) and combined opioid groups (42.1 minutes, 95% CI 17.5 -- 66.7) were associated with less time in recovery. In addition, the morphine only group was associated with better odds of being discharged home on the day of surgery (Group 2 OR 2.27, 1.02-5.06), potentially suggesting that fentanyl is effective in the short-term, but a morphine-containing opioid strategy may have benefits extending beyond the initial recovery period. Intraoperative opioid treatment group was not associated with chance of receiving a strong opioid prescription on discharge from hospital, or representation to the hospitals' ED in the first seven postoperative days. Given that tonsillectomy and adenotonsillectomy are associated with high rates of representation compared with other day case procedures #cite(<powellTonsillectomyComplicationsAdults2026>, form: "prose"), this suggests intraoperative opioid strategy is unlikely to influence pain control in the days following surgery.

In general, there is a lack of evidence supporting the optimal intraoperative analgesic strategy for both and adult and paediatric tonsillectomy. Most focuses on the safety and effectiveness of postoperative analgesia, or the evaluation of specific intraoperative agents and techniques, such as intracapsular drug infiltration@dalEfficacyIntravenousPeritonsillar2007@teunkensBupivacaineInfiltrationChildren2019@akkayaComparisonIntravenousPeritonsillar2009, or intravenous methadone. #cite(<bondergaardmIntraoperativeMethadonePostoperative2025>, form: "prose") Whilst the prevailing zeitgeist appears to be towards opioid minimisation, or opioid free techniques, responding to concerns around side effects such as postoperative nausea and vomiting, sedation, or tolerance and hyperalgesia associated with ultra-short acting agents like remifentanil, there remains little evidence of what is most effective. #cite(<shanthannaPerioperativeOpioidAdministration2021>, form: "prose") Our findings suggest that anaesthetists in both adult and paediatric routinely use opioids intraoperatively, but there is variation in how these medications are used, particularly in adults.

Bøndergaard and colleagues examined the effectiveness of intravenous methadone (24-48 hour half-life) versus 3 mcg.kg-1 fentanyl administered on induction of anaesthesia. Their randomised trial of 120 adult patients undergoing elective bilateral tonsillectomy revealed lower immediate postoperative opioid requirements across the first five postoperative days. There were no between group differences in sedation or time to discharge, however the methadone group was associated with significantly higher rates of postoperative nausea and vomiting. #cite(<bondergaardIntraoperativeMethadonePostoperative2025>, form: "prose") We found no studies directly comparing the effectiveness and safety of intraoperative morphine and fentanyl regimens in adult patients. Given these are the two most commonly used intraoperative opioid analgesic agents in the UK (excluding the use of remifentanil for its lack of postoperative analgesic benefit), it would make sense to identify the optimal treatment choice here. Our study results raise the interesting question as to the potential superiority of a dual analgesic approach, combining both fentanyl and morphine. In a recent large study by Santa Cruz Mercardo et al, higher intraoperative opioid administration was also associated with lower immediate and long term opioid use postoperatively. #cite(<santacruzmercadoAssociationIntraoperativeOpioid2023>, form: "prose")

This dual approach might harness the relative differences in time taken to reach peak effect site concentration for each agent (fentanyl: rapid onset of action, duration of effect 30-45min; morphine: 15-30min onset time, 4-6 hour duration of action). Fentanyl is frequently used as a co-induction agent, to facilitate airway placement and blunt the initial response to surgery, with morphine being delivered later during the procedure to provide both intra- and postoperative analgesia. This rational should apply equally to the combined use of remifentanil and morphine, which may have been captured in Treatment Group 2. It is possible that the difference in effect observed between groups 2 and 4 might relate to use of remifentanil, resulting in postoperative hyperalgesia. The benefit of an intraoperative opioid strategy which incorporates this concept of pharmacokinetic layering has, to the authors' knowledge, yet to be examined in this surgical group.

Our study has several strengths. We have demonstrated the practicality of using a data ecosystem and study pipeline specifically designed to reduce the barriers to using highly granular, routinely collected electronic patient data to map current and historical practice and address specific questions around care variation and treatment effectiveness. This pipeline is sustainable and will support repeated analyses as the eligible population continues to grow over time.

By using structured EPR data, we have been able to include variables relevant to perioperative analgesic management, but which are often difficult to include in observational studies of this type. These include patient (pre-existing chronic pain or opioid use), surgical (procedure length, use of Coblation technique) and anaesthetic (intra- and postoperative analgesic use) specific variables. By incorporating these with the individual anaesthetist's preferences using a multilevel modelling approach, we can move closer to a fuller picture of clinical decision making for smaller patient subgroups. Finally, the application of these principles to a large dataset of over 3,000 patients may help address some of the deficiencies inherent to a retrospective observational approach.

There are important limitations to this study. This is a single centre study and despite the relatively large sample size compared with similar work, this limits the generalisability of our findings. EPR-based studies are at high risk of bias through several mechanisms. Despite capturing relevant variables in greater detail than previously possible in similar work 7, there remain key components missing. In particular, patient data such as ethnicity was associated with a significant degree of missingness (#ref(<sec-sm-missing-data>, supplement: [Section])). In addition, it was not possible to reliably determine anaesthetic technique, in particular, discerning between volatile and total intravenous techniques, which may significantly influence both the intraoperative opioid administration practice and postoperative recovery. Finally, whilst the use of Coblation was reliably coded via a specific procedure code (#ref(<sec-sm-data-spec-procedures>, supplement: [Section])), alternative surgical approaches such as blunt dissection, or diathermy were not coded, existing only as unstructured data within the operation record. Further, there are additional variables relating to surgical technique which are also unstructured and were not included in the analysis, such as the extent of surgical dissection (intra versus extra-capsular), which will also influence postoperative pain and recovery, a limitation noted in previous studies. #cite(<keltiePaediatricTonsillectomyEngland2021>, form: "prose")

Given the lack of accounting for unmeasured confounding using a multilevel modelling approach, we make no causal judgements on the associations described. We also acknowledge limitations in our outcome measures, in particular the imposition of a 3-hour time cut for rescue opioid administration, given there is no defined transition point between phases of recovery. A sensitivity analysis exploring different time cut-offs for defining rescue opioid administration can be found in #ref(<sec-sm-sensitivity-opioid>, supplement: [Section]). Further, we were only able to capture re-presentation to the study centres' ED. Reported figures are therefore likely an underestimate as they do not reflect patients presenting to other hospitals or primary care. Future work should focus on addressing these limitations. In particular, improving quality of intraoperative and outcome data as described. Given the subjective nature of both pain descriptors and recovery from surgery, patient reported outcome measures should also be defined and incorporated into future analyses. The lack of clear answer on optimal intraoperative analgesic technique should also form the basis of future randomised trials going forward.

In conclusion, adult and paediatric tonsillectomy and adenotonsillectomy patients in this cohort study commonly received an intraoperative opioid, in the absence of evidence-based guidance on the optimal intraoperative opioid strategy. Whilst opioid use in paediatric patients was uniform, adults showed greater variation, with a corresponding association to variation in immediate postoperative outcomes after correcting for key patient, surgical and anaesthetic variables.

#heading(level: 1, numbering: none)[References]
<references>
#block[
] <refs>
#show: appendices.with("Supplementary material", hide-parent: true)
#heading(level: 1, numbering: none)[Supplementary material]
= Tables and Figures
<sec-sm-tables-figures>
== Supplementary Tables
<supplementary-tables>
#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 6,
  align: (left,left,left,left,left,left,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Tonsillectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adenoidectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adenotonsillectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Total],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Total encounters (%)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[438 (19.4)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[529 (23.4)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1292 (57.2)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[2259],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Age (years)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[10.00 (7.00 to 13.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[8.00 (6.00 to 10.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[6.00 (5.00 to 8.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[7.00 (5.00 to 10.00)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Height (cm)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[141.57 (120.49 to 160.98)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[130.37 (114.04 to 146.43)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[118.18 (108.00 to 130.48)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[122.98 (110.46 to 140.48)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Weight (kg)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[37.10 (22.80 to 57.15)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[27.45 (20.00 to 41.35)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[22.00 (17.71 to 30.17)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[24.40 (18.80 to 37.30)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Sex], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Female], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[250 (57.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[204 (38.6)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[548 (42.4)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1002 (44.4)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Male], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[188 (42.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[325 (61.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[744 (57.6)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1257 (55.6)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Gender Identity], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Female], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[2 (100.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[2 (50.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Male], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (100.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (50.0)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Ethnicity], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[White], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[171 (52.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[176 (43.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[430 (45.3)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[777 (46.1)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Asian], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[60 (18.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[71 (17.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[147 (15.5)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[278 (16.5)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Black], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[30 (9.1)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[77 (18.8)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[162 (17.1)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[269 (16.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mixed], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21 (6.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[32 (7.8)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[96 (10.1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[149 (8.8)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Other], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[46 (14.0)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[53 (13.0)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[114 (12.0)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[213 (12.6)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[ASA physical status], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[246 (56.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[315 (60.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[494 (38.6)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1055 (47.1)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[187 (42.8)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[201 (38.5)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[781 (61.1)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1169 (52.2)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4 (0.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6 (1.1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4 (0.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14 (0.6)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Chronic Tonsillitis EPR Diagnosis], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Yes], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[356 (81.3)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[477 (90.2)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1193 (92.3)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[2026 (89.7)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Obstructive Sleep Apnoea EPR Diagnosis], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Yes], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[111 (25.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[153 (28.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[977 (75.6)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1241 (54.9)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Opioid dependance EPR Diagnosis], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Yes], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Chronic Pain EPR Diagnosis], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Yes], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Procedure Length (minutes)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[26.00 (19.00 to 35.75)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[24.00 (16.00 to 36.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[32.00 (24.00 to 43.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[30.00 (21.00 to 40.00)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Coblation technique], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Yes], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[241 (55.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[140 (26.5)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[963 (74.5)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1344 (59.5)],
)}
], caption: figure.caption(
position: bottom, 
[
#strong[Demographics table - Paediatric patients.] Participant and surgical data for paediatric cohort stratified by surgical procedure group. Categorical data as number (%). IQR (Interquartile Range), EPR (Electronic Patient Record).
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-demo-paed>


#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 6,
  align: (left,left,left,left,left,left,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Tonsillectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adenoidectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adenotonsillectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Total],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Paracetamol (including oral premedications)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[435 (99.3)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[519 (98.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1278 (98.9)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[2232 (98.8)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Diclofenac], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[306 (69.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[370 (69.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[969 (75.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1645 (72.8)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Dexamethasone], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[437 (99.8)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[520 (98.3)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1280 (99.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[2237 (99.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Clonidine], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[3 (0.2)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[3 (0.1)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Ketamine], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1 (0.2)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1 (0.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Magnesium], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[1 (0.2)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1 (0.2)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[2 (0.2)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[4 (0.2)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Tramadol], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Oxycodone], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Diamorphine], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Fentanyl], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[429 (97.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[511 (96.6)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1278 (98.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[2218 (98.2)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Fentanyl, Intraoperative Administration, Dose (µg)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[50.00 (30.00 to 80.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[30.00 (25.00 to 50.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[30.00 (21.00 to 45.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[34.00 (25.00 to 50.00)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Fentanyl, Intraoperative Administration, Dose (µg.kg-1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[1.30 (1.00 to 1.86)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1.01 (0.94 to 1.56)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1.20 (1.00 to 1.91)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1.14 (0.99 to 1.85)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Morphine], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[28 (6.4)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[37 (2.9)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[65 (2.9)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Morphine, Intraoperative Administration, Dose (mg)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[5.00 (3.00 to 7.75)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[NA (NA to NA)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1.80 (1.40 to 3.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[2.50 (1.50 to 5.00)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Morphine, Intraoperative Administration, Dose (mg.kg-1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0.09 (0.08 to 0.11)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[NA (NA to NA)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0.10 (0.06 to 0.10)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0.10 (0.06 to 0.10)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Intra-operative opioids given], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[432 (98.6)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[511 (96.6)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[1278 (98.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[2221 (98.3)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Total intraoperative opioid dose (OME, mg)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[10.00 (6.00 to 16.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[6.00 (5.00 to 10.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[6.00 (4.45 to 9.09)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[7.00 (5.00 to 10.00)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Total intraoperative opioid dose (OME, mg.kg-1)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0.28 (0.20 to 0.39)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0.20 (0.19 to 0.31)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0.25 (0.20 to 0.39)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0.24 (0.20 to 0.38)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Treatment group], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[5 (1.6)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[15 (4.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[12 (1.3)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[32 (2.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (0.7)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (0.1)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[280 (91.8)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[348 (95.9)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[910 (95.2)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1538 (94.7)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18 (5.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[34 (3.6)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[52 (3.2)],
)}
], caption: figure.caption(
position: bottom, 
[
#strong[Anaesthetic management - Paediatrics.] Intraoperative analgesia administration for paediatric patients stratified by surgical group. OME, Oral Morphine Equivalent. Weight based dosed calculated where patient weight available.
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-analgesic-paed>


#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 6,
  align: (left,left,left,left,left,left,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Tonsillectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adenoidectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Adenotonsillectomy], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Total],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Administration of rescue opioids], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[41 (9.4)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[8 (1.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[41 (3.2)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[90 (4.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Administration of rescue morphine], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[17 (3.9)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[4 (0.8)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[29 (2.2)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[50 (2.2)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Administration of rescue fentanyl], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[24 (5.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[4 (0.8)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[14 (1.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[42 (1.9)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Administration of rescue opioids, (OME mg)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[4.94 (3.00 to 10.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[7.80 (4.75 to 12.88)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[3.36 (2.00 to 5.00)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[4.20 (2.50 to 7.42)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Administration of rescue opioids, (OME mg.kg-1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0.14 (0.07 to 0.20)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0.10 (0.09 to 0.16)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0.10 (0.10 to 0.15)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0.11 (0.08 to 0.19)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Time in Stage 1 recovery (mins)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[28.79 (20.00 to 38.68)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[27.52 (18.68 to 35.28)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[27.23 (18.07 to 38.29)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[27.58 (18.64 to 37.54)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Pain score at rest 3hrs post-op (Median)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0.50 (0.00 to 1.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0.00 (0.00 to 0.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0.00 (0.00 to 1.00)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0.00 (0.00 to 1.00)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Length of Stay (days)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Median (IQR)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0.44 (0.38 to 0.49)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0.40 (0.35 to 0.46)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0.43 (0.38 to 0.48)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0.43 (0.37 to 0.48)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Same day discharge], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[415 (94.7)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[519 (98.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1198 (92.7)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[2132 (94.4)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Paracetamol on discharge], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[176 (40.2)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[127 (24.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[457 (35.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[760 (33.6)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[NSAID on discharge], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[167 (38.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[106 (20.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[426 (33.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[699 (30.9)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Strong opioid perscribed on discharge], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[5 (0.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[5 (0.2)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[New strong opioids on discharge], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (NaN)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (NaN)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (NaN)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (NaN)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Weak opioid on discharge], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[23 (5.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[2 (0.4)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[8 (0.6)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[33 (1.5)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Return to theatre within 7 days], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[1 (0.2)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1 (0.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[2 (0.1)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Return to theatre within 14 days], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[2 (0.5)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[4 (0.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[6 (0.3)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Return to theatre within 30 days], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[2 (0.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[1 (0.2)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[4 (0.3)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[7 (0.3)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Represented to ED before 7 days], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[27 (6.2)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[7 (1.3)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[58 (4.5)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[92 (4.1)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Represented to ED before 14 days], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[33 (7.5)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[11 (2.1)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[70 (5.4)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[114 (5.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Represented to ED before 30 days], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[38 (8.7)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[14 (2.6)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[78 (6.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[130 (5.8)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Died during admission], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)],
  table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[Mortality (90 days)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, fill: rgb("#f2f2f2"), stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)],
  table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[Mortality (1 year)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[N (%)], table.cell(align: horizon + left, stroke: (left: (paint: black, thickness: 0.75pt), top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)], table.cell(align: horizon + left, stroke: (top: (paint: black, thickness: 1.5pt)))[0 (0.0)],
)}
], caption: figure.caption(
position: bottom, 
[
#strong[Paediatric outcomes.] Outcome data for paediatric patients stratified by surgical group. Return to theatre at UCLH and representation to UCLH emergency department only, cumulative measures at each time point. Eligible medications for discharge measured as classified in #ref(<sec-sm-data-spec>, supplement: [Section]).
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-outcome-paed>


== Supplementary Figures
<supplementary-figures>
#figure([
#box(image("supplementary_tables_and_figures_files/figure-typst/chunk-sfig-venn-paed-1.svg", alt: "Venn diagrams of paediatric intraoperative medications"))

], caption: figure.caption(
position: bottom, 
[
#strong[Venn diagrams of paediatric intraoperative medications.] Distributions of complete intra-operative simple analgesia and intraoperative opioid administration in paediatrics (A). Venn diagram to show the breakdown of the simple analgesia (B) and opioids given (C)
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-venn-paed>


#figure([
#box(image("supplementary_tables_and_figures_files/figure-typst/chunk-sfig-venn-paracetamol-1.svg", alt: "Venn diagram of paracetamol administration"))

], caption: figure.caption(
position: bottom, 
[
#strong[Venn diagram of paracetamol administration.] Venn diagram of distributions of paracetamol given intraoperatively as defined as being given on the intraoperative medication administration record compared to doses of paracetamol given in the 3 hours pre-operatively for the adult cohort (A) and paediatric cohorts (B) respectively.
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-venn-paracetamol>


#figure([
#box(image("supplementary_tables_and_figures_files/figure-typst/chunk-sfig-venn-adjuncts-1.svg", alt: "Venn diagram of analgesia adjuncts administration"))

], caption: figure.caption(
position: bottom, 
[
#strong[Venn diagram of analgesia adjuncts administration.] Distributions of magnesium, ketamine and clonidine given intraoperatively for the adult cohort (A) and paediatric cohorts (B) respectively.
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-venn-adjuncts>


#figure([
#box(image("supplementary_tables_and_figures_files/figure-typst/chunk-sfig-opioid-histogram-adult-1.svg", alt: "Distribution of adult intraoperative opioid dose"))

], caption: figure.caption(
position: bottom, 
[
#strong[Distribution of adult intraoperative opioid dose.] Histogram with marginal rug plot of individual doses of total intra-operative OME doses across adult patients in treatment groups 2,3 and 4.
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-opioid-histogram-adult>


#figure([
#box(image("supplementary_tables_and_figures_files/figure-typst/chunk-sfig-opioid-histogram-paed-1.svg", alt: "Distribution of paediatric intraoperative opioid dose"))

], caption: figure.caption(
position: bottom, 
[
#strong[Distribution of paediatric intraoperative opioid dose.] Histogram with marginal rug plot of individual doses of total intra-operative OME doses across paediatric patients in treatment groups 2,3 and 4.
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-opioid-histogram-paed>


#figure([
#box(image("data/upset_paed.png", alt: "Combinations of paediatric intraoperative analgesia"))

], caption: figure.caption(
position: bottom, 
[
#strong[Combinations of paediatric intraoperative analgesia.] Distribution of different analgesic combinations for paediatric patients. Upper vertical bar graph showing the total count of each combination of analgesia with treatment groups coloured. Lower left horizontal bar graph showing the total count of patients receiving each specific medication.
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-upset-paed>


= Supplementary materials
<sec-sm-materials>
== Data specification
<sec-sm-data-spec>
=== Surgical procedure classification
<sec-sm-data-spec-procedures>
Surgical technique was assessed using the procedure codes recorded for each case using the OPSC-4.9 version as described in #ref(<stbl-surgical-criteria>, supplement: [Table S]). For each case, the procedure was included into a group if one of the eligible OPSC codes was identified (Inclusive of all 3-digit codes within each 2-digit code) and then subsequently removed if an exclusion code was also present. To exclude concurrent procedures within the mouth where the tonsils may additionally be removed (such as a glossectomy or mandibular resection), the remainder of the F chapter was excluded across the simple procedure groups. The use of coblation and electrocautery were determined with the same method and then added as a feature to each procedure. The three surgical groups were checked to ensure mutual exclusivity.

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.header([Surgical Group], [Eligible OPSC codes], [Exclusion OPSC codes],),
  table.hline(),
  [Tonsillectomy], [F34, F35], [E20, F0:F33, F36:F99],
  [Adenoidectomy], [E20], [F34, F35, F0:F33, F36:F99],
  [Adenotonsillectomy], [F34, F35, E20], [F0:F33, F36:F99, Patients already identified in tonsillectomy and adenoidectomy cohorts.],
  [Coblation], [Y10.1, F34.7, F35.2], [],
  [Electrocautery], [Y10.2, Y11.1], [Y10.1],
)
], caption: figure.caption(
position: bottom, 
[
#strong[Criteria for surgical cohort eligibility.]
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-surgical-criteria>


Only where a technique is explicitly coded is it auditable. For example, all ENT procedures are set up with electrocautery (diathermy) as standard, but only in cases where explicit mention is made in the surgical operation note are the coded then captures and auditable. Thus, surgical technical may be significantly underestimating the true prevalence.

=== Past medical history
<sec-sm-data-spec-pmh>
For a patient to be considered as ‘positive' for a previous medical condition their problem list was searched for eligible ICD-10-5th edition codes, where a 3-digit code was provided, this included all of the 4-digit codes inclusive, unless the 4-digit code was provided in the exclusion ICD codes.

#figure([
#table(
  columns: 3,
  align: (left,left,left,),
  table.header([Past medical history item], [Eligible ICD codes], [Exclusion ICD codes],),
  table.hline(),
  [Chronic Pain], [R52], [R52.0],
  [Opioid Dependence], [F11], [],
  [Chronic Tonsillitis], [J35], [J35.8],
  [Sleep apnoea], [G47.3], [],
)
], caption: figure.caption(
position: bottom, 
[
#strong[Eligibility for past medical history filtering on ICD10 codes.]
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-pmh-criteria>


=== Intra-operative medications
<sec-sm-data-spec-intra-op-meds>
Broadly the majority of preparations provided on the intra-operative MAR were intravenous preparations but there are a few examples of oral medications being given. All medication doses in theatre were converted to mg and if given in discrete doses within a theatre episode where pooled to produce the total intra-operative dose.

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.header([Medication group (if applicable)], [Medication], [Medication preparation],),
  table.hline(),
  [], [Paracetamol], [paracetamol 1g/100ml solution for infusion, paracetamol 500mg/50ml solution for infusion vial, paracetamol 500mg tablets, paracetamol 500mg suppository, paracetamol 250mg/5ml suspension sugar-free, paracetamol 250mg/5ml oral suspension],
  [NSAIDs], [Diclofenac\*], [diclofenac sodium 75mg/3ml injection, diclofenac sodium 100mg suppository, diclofenac sodium 50mg suppository],
  [], [Dexamethasone], [dexamethasone 6.6mg/2ml injection, dexamethasone 2mg tablet],
  [], [Tramadol], [tramadol 100mg/2ml injection],
  [], [Clonidine], [clonidine 150microgram/1ml injection, clonidine 25microgram tablets],
  [], [Ketamine], [ketamine 50mg/5ml injection preservative-free, ketamine 200mg/20ml injection, ketamine 100mg/2mL, ketamine 500mg/10ml injection],
  [], [Magnesium], [magnesium sulfate in 100 ml in normal saline, magnesium sulfate in 250 ml in normal saline],
  [Strong opioid], [Morphine], [morphine sulfate 10mg/1ml solution for injection ampoule, morphine sulfate 1mg/ml injection, morphine sulfate 10mg/5ml oral solution],
  [], [Oxycodone], [oxycodone hydrochloride 10mg/1ml injection, oxycodone hydrochloride 20mg/2ml injection, oxycodone hydrochloride 50mg/1ml injection, oxycodone 100mg/50ml pca solution for infusion, oxycodone hydrochloride 5mg/5ml oral solution sugar-free],
  [], [Fentanyl], [fentanyl 100microgram/2ml injection, fentanyl 2000mcg/100ml pca infusion],
  [], [Diamorphine], [diamorphine hydrochloride 5mg powder for solution for injection, diamorphine hydrochloride 10mg powder for solution for injection],
)
], caption: figure.caption(
position: bottom, 
[
#strong[Formulations for intraoperative medications.]
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-intra-op-formulations>


\* Note: Diclofenac is the only NSAID used within UCLH theatres. A review of Aspirin, Naproxen, Celecoxib and ibuprofen revealed no intra-operative administrations across the cohort.

=== Discharge medications
<sec-sm-data-spec-discharge>
Discharge medications were counted if there were prescribed on the discharge paperwork, regardless if they were dispensed from hospital pharmacy, sent to the community pharmacy or patients were instructed to purchase over the counter. Specific formulations of discharge medications have not been provided as clinicians will prescribe a generic medication and dose regime and formulation details are not provided on the discharge paperwork.

#figure([
#table(
  columns: (50%, 50%),
  align: (left,left,),
  table.header([Medication group], [Medications generic name],),
  table.hline(),
  [Paracetamol], [paracetamol],
  [NSAID's\*], [Ibuprofen, Diclofenac sodium, Naproxen, Etoricoxib, Celecoxib],
  [Strong opioid], [morphine sulfate, oxycodone hydrochloride, buprenorphine, fentanyl, diamorphine hydrochloride],
  [Weak opioid], [codeine phosphate, dihydrocodeine, co-dydramol (dihydrocodeine and paracetamol), co-codamol (codeine and paracetamol), tramadol],
)
], caption: figure.caption(
position: bottom, 
[
#strong[Formulations for discharge medications.]
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-discharge-formulations>


\* Aspirin was not included as the primary intention is usually not for post-operative analgesia

== Missing data
<sec-sm-missing-data>
The level of missing data for each of the key variables were assessed as reported in #ref(<stbl-missing-data>, supplement: [Table S]). All other variables had no missing values. Extracted variables for past medical history and medications administered required a past medical history and medication administration record to be able to assess, there was no missing records so these fields have no missing variables. It is noted by the authors the limitations of accuracy of the medical record. Where missing data exists for computed variables there was a missing variable during the computation, hence the resulting value being #NormalTok("NA"); (for example if a patient did not have any pain scores recorded within 3 hours post-op the median value is not computable and thus missing).

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (left,right,right,right,right,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); variable], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    Adults
    ]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    Paediatrics
    ]],
    table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Count], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Percentage (%)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Count], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Percentage (%)],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Total count], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 1397], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); ---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 2259], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); ---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Height (cm)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[572], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[40.94%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[351], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15.54%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Weight (kg)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[570], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[40.80%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.93%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Sex], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.00%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.00%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Gender Identity], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1341], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[95.99%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2255], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[99.82%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ethnicity], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[463], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33.14%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[573], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25.37%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ASA physical status], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.64%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.93%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Fentanyl, Intraoperative Administration, Dose (µg)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[465], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33.29%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[41], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.81%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Fentanyl, Intraoperative Administration, Dose (µg.kg-1)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[800], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57.27%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[61], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.70%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Morphine, Intraoperative Administration, Dose (mg)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[832], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[59.56%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2194], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[97.12%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Morphine, Intraoperative Administration, Dose (mg.kg-1)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1062], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[76.02%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2195], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[97.17%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Total intraoperative opioid dose (OME, mg)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[147], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10.52%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[38], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.68%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[353], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25.27%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[635], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28.11%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Administration of rescue opioids, (OME mg)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[620], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[44.38%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2170], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[96.06%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Time in Stage 1 recovery (mins)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[43], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.08%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.71%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Pain score at rest 3hrs post-op (Median)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[246], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17.61%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1656], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[73.31%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mortality (90 days)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[36], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.58%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[87], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.85%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mortality (1 year)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[206], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.75%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[439], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19.43%],
)}
], caption: figure.caption(
position: bottom, 
[
TODO: caption to be supplied by the authors.
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-missing-data>


== Oral morphine equivalence
<sec-sm-ome>
For each medication the routes were grouped and a conversion value attributed using the standard equivalence table provided by Neilsen et al. Oral morphine equivalence (OME) was then calculated as a weighted sum using the standard OME equation. $  & upright("for") med i in { 1 \, . . . \, n }\
upright("OME") & = d_(upright("ref")) + sum_(i in N) \( c_i d_i \)\
\
 &  & d_(upright("ref")) = upright("dose of reference medication")\
 &  & d_i = upright("dose of medication")\
 &  & c_i = upright("conversion value of medication")\
 &  & N = upright("non-referance medications") $ Distributions and mean dose sum of each opioid within each treatment group are described within the results.

== Analysis code
<sec-sm-analysis-code>
Data was extracted from the EPR and stored in a proprietary data model in the parquet format. Extraction code is not provided as it contains intellectual property of the EPR provider Epic, Wisconsin.

The dataset was cleaned to remove known issues by the script #NormalTok("import_proccess.qmd");.

The tonsillectomy dataset was produced by the script #NormalTok("peri_op_med_dataset.qmd");.

The analysis was performed by the script #NormalTok("peri_op_med_analysis.qmd"); and supplementary analysis and materials in #NormalTok("peri_op_med_supp_mat.qmd");.

The code is held at the following github repository #link("https://github.com/DW10/tonsillectomy_analgesia")

== Sensitivity analysis
<sec-sm-sensitivity>
=== Rescue opioid administration
<sec-sm-sensitivity-opioid>
The time to first post-operative opioid was extracted for all patients, and a sensitivity analysis was performed to establish the best cut off time as show in the #ref(<stbl-sens-rescue-opioid>, supplement: [Table S]) and #ref(<sfig-sens-rescue-opioid>, supplement: [Figure S]). A threshold time of 3 hours was selected given the clinical rational of any inter-operative analgesia plan would include adequate analgesic for this period and any opioids administered within 3 hours would represent inadequate analgesic effect.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 4,
  align: (right,right,right,right,),
  table.header(table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Time (hours)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Patients receiving 1 or more doses (N)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Proportion of patients who received an opioid (%)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Proportion of all patients (%)],),
  table.hline(),
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.11], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.11],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.22], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.22],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[316], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33.40], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33.40],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[663], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[70.08], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[70.08],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[800], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[84.57], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[84.57],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[868], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[91.75], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[91.75],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[890], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[94.08], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[94.08],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[898], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[94.93], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[94.93],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[908], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[95.98], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[95.98],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[912], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[96.41], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[96.41],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[916], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[96.83], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[96.83],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6.0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[922], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[97.46], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[97.46],
)}
], caption: figure.caption(
position: bottom, 
[
TODO: caption to be supplied by the authors.
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-sens-rescue-opioid>


#figure([
#box(image("supplementary_materials_files/figure-typst/chunk-sfig-sens-rescue-opioid-1.svg", alt: "Cumulative density of opioid administration times in recovery"))

], caption: figure.caption(
position: bottom, 
[
#strong[Cumulative density of opioid administration times in recovery.] Cumulative density plot of the administration times of opioid medications from the end of surgery to the first dose given for patient that received an opioid within 6 hours of surgery. Gray filled area depicts the density distribution and dotted line denotes the time cut off point of 3 hours.
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-sens-rescue-opioid>


=== Presentation to the emergency department
<sec-sm-sensitivity-ed>
All of the subsequent presentations to the UCLH emergency department within 35 days was extracted for the patients. Primary reason for attendance was not extracted and where patients attended more than once within the 40 day period the first presentation was used. A sensitivity analysis was performed to understand the distribution of the data against the clinically benchmarked timepoints of 7, 14 and 30 days. #ref(<stbl-sens-ed>, supplement: [Table S]) and #ref(<sfig-sens-ed>, supplement: [Figure S]) depict the proportion of presentations across important timepoints.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 4,
  align: (right,right,right,right,),
  table.header(table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Time (Days)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Patients attending the emergency department (N)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Proportion of patients who presented within 35 days (%)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Proportion of all patients (%)],),
  table.hline(),
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NaN], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NaN], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NaN], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NaN], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NaN], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NaN], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NaN], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NaN], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[30], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NaN], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[35], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NaN], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
)}
], caption: figure.caption(
position: bottom, 
[
TODO: caption to be supplied by the authors.
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-sens-ed>


#figure([
#box(image("supplementary_materials_files/figure-typst/chunk-sfig-sens-ed-1.svg", alt: "Cumulative density of time to presentation to the emergency department"))

], caption: figure.caption(
position: bottom, 
[
#strong[Cumulative density of time to presentation to the emergency department.] Cumulative density plot of the of the time to presentation at the emergency department (ED) from the discharge date to the ED visit time. Gray filled area depicts the density distribution and dotted line denotes the time point of 7,14 and 30 days.
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-sens-ed>


=== Multi-level modelling group size threshold
<sec-sm-sensitivity-group-size>
To account for inter-clinician difference in practices, multi-level modelling has been used. To balance the power of the model against the generalisability a threshold of case size has been used.

Clinicians who have performed fewer than 5 cases for adult patients across the whole study period were deemed not experienced enough to impart personalised differences in practice to the care and thus were removed from the modelling.

A threshold of 5 was chosen from the sensitivity #ref(<stbl-sens-group-size>, supplement: [Table S]) and #ref(<sfig-sens-group-size>, supplement: [Figure S]).

The maximum threshold values test was 70 due to failure of model convergence beyond this value.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (8.33%, 8.33%, 8.33%, 8.33%, 8.33%, 8.33%, 8.33%, 8.33%, 8.33%, 8.33%, 8.33%, 8.33%),
  align: (right,right,right,right,right,right,right,right,right,right,right,center,),
  table.header(table.cell(align: bottom + right, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Theshold value], table.cell(align: bottom + right, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Patients included (N)], table.cell(align: bottom + right, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Clinicans included (N)], table.cell(align: center, colspan: 3, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    Beta of Treatment group (Log Odds)
    ]], table.cell(align: center, colspan: 3, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    Standard Error of Treatment group
    ]], table.cell(align: bottom + right, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Variance from Clinician], table.cell(align: bottom + right, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); AIC], table.cell(align: bottom + center, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Model convergence],
    table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 3], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 4], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 3], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 4],),
  table.hline(),
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,397.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[89.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.05], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.15], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.25], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.24], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.27], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.06], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,395.78], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TRUE],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,367.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[59.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.04], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.15], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.26], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.24], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.27], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.06], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,372.96], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TRUE],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,324.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[40.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.04], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.04], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.20], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.26], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.24], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.27], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.06], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,331.97], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TRUE],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,258.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.07], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.04], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.20], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.26], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.25], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.28], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.04], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,272.54], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TRUE],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,244.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[23.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.07], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.05], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.19], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.26], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.25], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.28], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.04], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,258.22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TRUE],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,219.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.11], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.10], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.14], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.26], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.25], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.28], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.04], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,241.61], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TRUE],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,148.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.07], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.06], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.07], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.27], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.25], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.29], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.02], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,179.18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TRUE],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[30.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,077.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.06], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.03], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.06], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.27], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.26], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.29], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.03], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,129.89], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TRUE],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[40.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,047.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.08], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.06], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.10], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.28], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.26], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.30], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.03], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,096.01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TRUE],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[50.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,047.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.08], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.06], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.10], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.28], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.26], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.30], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.03], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,096.01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TRUE],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[60.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[990.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.06], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.07], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.12], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.28], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.27], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.30], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.04], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,033.15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TRUE],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[70.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[729.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.41], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.39], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.69], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.32], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.29], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.37], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.00], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[762.13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[FALSE],
)}
], caption: figure.caption(
position: bottom, 
[
Table of model performance of the unadjusted multilevel model of primary outcome (rescue opioids) with varying threshold levels
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-sens-group-size>


#figure([
#box(image("supplementary_materials_files/figure-typst/chunk-sfig-sens-group-size-1.svg", alt: "Plot of sensitivity analysis of multi-level threshold"))

], caption: figure.caption(
position: bottom, 
[
#strong[Plot of sensitivity analysis of multi-level threshold.] Upper plot, line chart of odds ratio with 95% confidence interval bands for differing clinical group size threshold values.Lower plot, line chart of AIC over threshold values with number of clinicians included shower per point.
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-sens-group-size>


== Modelling
<sec-sm-modelling>
=== Cohort for modelling
<cohort-for-modelling>
#ref(<sfig-consort-modelling>, supplement: [Figure S]) shows the eligibility of patient groups for modelling.

#figure([
#box(image("supplementary_materials_files/figure-typst/chunk-sfig-consort-modelling-1.svg", alt: "Consort diagram demonstrating patient inclusion for modelling"))

], caption: figure.caption(
position: bottom, 
[
#strong[Consort diagram demonstrating patient inclusion for modelling.] Consort diagram demonstrating the eligibility of patient groups for modelling
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-consort-modelling>


=== Directed acyclic graph
<sec-sm-modelling-dag>
A direct acyclic graph was generated using expert domain konwledge to understand and specific the suitable co-variants for the associational model.

#figure([
#box(image("figures/sfig-dag.png"))
], caption: figure.caption(
position: bottom, 
[
TODO: caption to be supplied by the authors. (Old placeholder caption was: 'A simple workflow diagram showing step A leading to step B.')
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-dag>


=== Models parameters
<sec-sm-model-parameters>
#figure([
#table(
  columns: (16.67%, 16.67%, 16.67%, 16.67%, 16.67%, 16.67%),
  align: (left,left,left,left,left,left,),
  table.header([Model Number], [Cohort], [Outcome], [Multi-level by primary anaesthetist], [Co-variants], [Notes],),
  table.hline(),
  [0], [Adult], [Recovery opioids], [No], [Nil], [],
  [1], [Adults], [Recovery opioids], [Yes], [Nil], [],
  [2], [Adults], [Recovery opioids], [Yes], [age, sex, surgical cohort, ASA, history of chronic pain, procedure length and use of coblation], [],
  [3], [Adults], [Time in recovery], [Yes], [], [],
  [4], [Adults], [Same discharge], [Yes], [], [],
  [5], [Adults], [Opioid on discharge], [Yes], [], [Model fails to converge],
  [6], [Adults], [Return to ED at 7 days], [Yes], [], [Model fails to converge],
)
], caption: figure.caption(
position: bottom, 
[
#strong[TODO: caption to be supplied by the authors.]
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-model-parameters>


The following secondary outcomes were not modelled with the associated justification:

- Length of admission (Days) -- Same day discharge has been modelled as a logistic regression instead due to the multi-modal disruption of length of admission.

- Median pain score -- Significant number of missing data as pain scores not being collected in recovery, only on the ward.

- Discharge medications -- Medication prescriptions at the point of discharge likely represent the variation in discharging clinician rather than anaesthetic clinician

- Return to theatre-- Lack of distribution of outcome

- Re-presentation -- Lack of distribution of outcome

- Deaths -- Lack of distribution of outcome

=== Multilevel modelling
<multilevel-modelling>
An ANOVA was performed between model 0 (without multi-level modelling) and model 1 (with multi-level modelling) to establish the difference in model performance

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 8,
  align: (right,right,right,right,right,right,right,right,),
  table.header(table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); npar], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); AIC], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); BIC], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); logLik], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); deviance], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Chisq], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Df], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Pr(\>Chisq)],),
  table.hline(),
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1297.392], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1316.922], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-644.6960], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1289.392], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1297.667], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1322.079], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-643.8336], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1287.667], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.724714], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.1890873],
)}
], caption: figure.caption(
position: bottom, 
[
#strong[ANOVA of Model 0 and Model 1.]
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-model-anova>


=== Treatment group effects
<treatment-group-effects>
#figure([
#box(image("supplementary_materials_files/figure-typst/chunk-sfig-forrest-plot-1.svg", alt: "Combined forest plots of treatment group effect for outcome measures"))

], caption: figure.caption(
position: bottom, 
[
#strong[Combined forest plots of treatment group effect for outcome measures.] Left to right: 1) unadjusted association between treatment group and rescue opioid administration (model 1), 2) adjusted association between treatment group and rescue opioid administration (model 2), 3) adjusted association between treatment group and time spent in recovery, 4) adjusted association between treatment group and same day discharge from hospital.
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-forrest-plot>


=== Results of Model 1
<sec-sm-model-1>
In Model 1 the variance explained by the anaesthetist ID was 5.0%

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 8,
  align: (left,right,right,right,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 8, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); ],
    table.cell(align: center, colspan: 8, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Cohort: Adult (unadjusted) Outcome: Recovery opioids],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Term], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Coefficient], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Standard error], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); z value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); p value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Odds Ratio], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); OR 95% CI Lower], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); OR 95% CI Upper],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\(Intercept)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.546], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.228], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.400], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0164], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.727], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.105], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.697],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.111], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.260], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.425], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.6710], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.895], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.538], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.491],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.064], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.244], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.261], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.7939], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.938], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.582], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.513],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.262], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.276], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−4.580], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.283], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.165], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.486],
)}
], caption: figure.caption(
position: bottom, 
[
#strong[Fixed effects of model 1.]
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-model-1-fixed>


#figure([
#box(image("supplementary_materials_files/figure-typst/chunk-sfig-model-1-random-1.svg", alt: "Random effects of model 1"))

], caption: figure.caption(
position: bottom, 
[
#strong[Random effects of model 1.]
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-model-1-random>


=== Results of Model 2
<sec-sm-model-2>
In Model 1 the variance explained by the anaesthetist ID was 4.1%

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 8,
  align: (left,right,right,right,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 8, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); ],
    table.cell(align: center, colspan: 8, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Cohort: Adult (adjusted) Outcome: Recovery opioids],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Term], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Coefficient], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Standard error], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); z value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); p value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Odds Ratio], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); OR 95% CI Lower], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); OR 95% CI Upper],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\(Intercept)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.035], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.345], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.998], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0027], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.816], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.431], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.540],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.062], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.347], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.180], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.8574], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.940], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.476], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.855],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.130], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.338], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.385], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.6999], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.139], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.587], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.210],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.872], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.490], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.779], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.0753], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.418], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.160], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.093],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Age (years)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.003], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.007], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.359], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.7194], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.997], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.984], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.011],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Sex: Male], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.388], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.147], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−2.633], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0085], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.678], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.508], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.906],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Cohort: Adenoidectomy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.972], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.283], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−3.434], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0006], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.378], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.217], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.659],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Cohort: Adenotonsillectomy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.230], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.410], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.562], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.5742], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.794], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.356], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.774],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ASA: 2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.186], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.149], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.247], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.2124], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.204], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.899], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.613],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ASA: 3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.804], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.416], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.931], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.0535], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.234], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.988], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.051],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Chronic pain EPR diagnosis], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16.663], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[256.003], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.065], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9481], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17,246,029.420], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,402,715,160,700,723,036,991,085,236,294,291,222,509,907,398,686,037,744,012,270,541,774,420,156,692,178,477,797,837,346,132,154,155,918,370,517,607,311,201,282,249,445,059,944,771,087,740,661,532,664,219,839,845,972,394,937,020,114,226,193,982,581,458,489,460,882,747,848,551,010,650,420,099,940,352.000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Procedure length (Minutes)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.002], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.003], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.661], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.5083], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.998], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.991], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.004],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Coblation], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.049], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.398], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−2.636], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0084], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.350], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.161], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.764],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Intra-operative opioid dose (OME mg)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.014], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.009], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.574], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.1154], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.986], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.969], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.003],
)}
], caption: figure.caption(
position: bottom, 
[
#strong[Fixed effects of model 2.]
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-model-2-fixed>


#figure([
#box(image("supplementary_materials_files/figure-typst/chunk-sfig-model-2-random-1.svg", alt: "Random effects of model 2"))

], caption: figure.caption(
position: bottom, 
[
#strong[Random effects of model 2.]
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-model-2-random>


=== Results of Model 3
<sec-sm-model-3>
In Model 3 the standard deviation of the variance explained by the anaesthetist ID was 2.33 minutes.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 8,
  align: (left,right,right,right,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 8, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); ],
    table.cell(align: center, colspan: 8, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Cohort: Adult (adjusted) Outcome: Time in recovery (minutes)],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Term], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Coefficient], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Standard error], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); z value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Degrees of freedom], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); p value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 95% CI Lower], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 95% CI Upper],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\(Intercept)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[96.209], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8.580], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.213], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[386.260], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[79.339], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[113.079],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−15.384], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8.725], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.763], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[584.869], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.078], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−32.520], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.753],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−23.416], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8.439], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−2.775], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[635.784], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.006], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−39.987], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−6.845],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−42.086], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12.534], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−3.358], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[733.664], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.001], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−66.692], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−17.479],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Age (years)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.100], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.178], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.563], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[915.766], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.574], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.249], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.450],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Sex: Male], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.693], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.789], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.447], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[844.423], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.655], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−9.129], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.743],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Cohort: Adenoidectomy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−20.622], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7.486], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−2.755], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[892.167], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.006], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−35.313], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−5.930],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Cohort: Adenotonsillectomy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−8.130], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10.898], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.746], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[923.363], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.456], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−29.517], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.258],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ASA: 2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.249], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.836], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.368], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[898.743], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.172], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−2.279], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12.777],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ASA: 3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[27.098], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9.866], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.747], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[919.897], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.006], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7.735], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[46.461],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Chronic pain EPR diagnosis], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.969], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[27.232], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.219], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[924.724], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.827], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−47.475], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[59.414],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Procedure length (Minutes)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.012], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.086], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.136], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[920.494], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.892], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.181], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.157],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Coblation], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.505], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9.967], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.051], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[925.878], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.960], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−19.056], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20.066],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Intra-operative opioid dose (OME mg)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.154], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.228], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.675], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[446.042], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.294], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.603],
  table.hline(),
  table.footer(table.cell(colspan: 8)[p value\'s calculated using Satterthwaite\'s approximation],),
)}
], caption: figure.caption(
position: bottom, 
[
#strong[Fixed effects of model 3.]
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-model-3-fixed>


#figure([
#box(image("supplementary_materials_files/figure-typst/chunk-sfig-model-3-random-1.svg", alt: "Random effects of model 3"))

], caption: figure.caption(
position: bottom, 
[
#strong[Random effects of model 3.]
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-model-3-random>


=== Results of Model 4
<sec-sm-model-4>
In Model 4 the variance explained by the anaesthetist ID was 25.2%

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 8,
  align: (left,right,right,right,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 8, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); ],
    table.cell(align: center, colspan: 8, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Cohort: Adult (adjusted) Outcome: Same day discharge],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Term], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Coefficient], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Standard error], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); z value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); p value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Odds Ratio], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); OR 95% CI Lower], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); OR 95% CI Upper],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\(Intercept)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.794], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.409], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.389], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6.011], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.699], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.391],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.820], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.409], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.007], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0448], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.271], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.019], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.059],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.611], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.395], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.548], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.1217], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.843], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.850], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.998],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.155], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.610], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.894], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.0582], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.173], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.961], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10.482],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Age (years)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.002], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.008], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.192], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.8474], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.998], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.982], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.015],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Sex: Male], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.371], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.178], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−2.081], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0375], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.690], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.487], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.979],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Cohort: Adenoidectomy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.278], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.420], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.041], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0024], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.588], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.575], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8.177],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Cohort: Adenotonsillectomy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.014], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.492], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.029], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9768], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.986], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.376], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.585],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ASA: 2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.338], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.185], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.829], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.0674], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.713], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.496], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.025],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ASA: 3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.646], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.412], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−3.998], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0001], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.193], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.086], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.432],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Chronic pain EPR diagnosis], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.018], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.194], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.015], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9880], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.982], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.095], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10.192],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Procedure length (Minutes)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.018], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.004], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−4.538], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.982], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.975], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.990],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Coblation], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.310], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.566], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.548], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.5838], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.364], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.449], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.139],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Intra-operative opioid dose (OME mg)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.011], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.024], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9810], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.978], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.022],
)}
], caption: figure.caption(
position: bottom, 
[
#strong[Fixed effects of model 4.]
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-model-4-fixed>


#figure([
#box(image("supplementary_materials_files/figure-typst/chunk-sfig-model-4-random-1.svg", alt: "Random effects of model 4"))

], caption: figure.caption(
position: bottom, 
[
#strong[Random effects of model 4.]
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-model-4-random>


=== Results of Model 5
<sec-sm-model-5>
In Model 5 the variance explained by the anaesthetist ID was 0.0%

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 8,
  align: (left,right,right,right,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 8, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); ],
    table.cell(align: center, colspan: 8, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Cohort: Adult (adjusted) Outcome: Opioids on discharge],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Term], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Coefficient], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Standard error], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); z value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); p value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Odds Ratio], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); OR 95% CI Lower], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); OR 95% CI Upper],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\(Intercept)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−24.131], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,747.732], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.002], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9984], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Inf],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18.902], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,747.732], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.002], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9987], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[161,872,469.179], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Inf],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18.763], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,747.732], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.002], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9987], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[140,889,946.846], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Inf],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18.443], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,747.732], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.002], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9987], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[102,260,208.641], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Inf],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Age (years)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.054], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.032], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.676], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.0937], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.055], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.991], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.124],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Sex: Male], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.268], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.085], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.168], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.2428], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.282], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.034], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.362],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Cohort: Adenoidectomy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−35.426], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,108,195.936], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.0000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Inf],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Cohort: Adenotonsillectomy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−37.725], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13,013,560.905], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.0000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Inf],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ASA: 2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.220], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.913], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.337], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.1812], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.295], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.049], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.766],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ASA: 3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−45.321], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,447,390.845], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.0000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Inf],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Chronic pain EPR diagnosis], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−35.964], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33,676,253.936], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.0000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Inf],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Procedure length (Minutes)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.006], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.021], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.282], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.7780], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.006], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.966], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.047],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Coblation], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−33.222], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12,121,752.973], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.0000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Inf],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Intra-operative opioid dose (OME mg)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.015], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.046], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.319], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.7497], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.985], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.901], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.078],
)}
], caption: figure.caption(
position: bottom, 
[
#strong[Fixed effects of model 5.]
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-model-5-fixed>


#figure([
#box(image("supplementary_materials_files/figure-typst/chunk-sfig-model-5-random-1.svg", alt: "Random effects of model 5"))

], caption: figure.caption(
position: bottom, 
[
#strong[Random effects of model 5.]
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-model-5-random>


=== Results of Model 6
<sec-sm-model-6>
In Model 6 the variance explained by the anaesthetist ID was 6.7%

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 8,
  align: (left,right,right,right,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 8, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); ],
    table.cell(align: center, colspan: 8, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Cohort: Adult (adjusted) Outcome: Presentation to emergency department within 7 days],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Term], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Coefficient], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Standard error], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); z value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); p value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Odds Ratio], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); OR 95% CI Lower], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); OR 95% CI Upper],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\(Intercept)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.251], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.495], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−2.526], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0115], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.286], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.108], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.755],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.019], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.496], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.038], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9695], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.981], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.371], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.592],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.039], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.483], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.081], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9356], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.040], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.403], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.682],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Treatment group 4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.658], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.721], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.912], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.3616], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.518], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.126], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.129],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Age (years)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.018], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.011], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.699], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.0893], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.982], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.962], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.003],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Sex: Male], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.100], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.213], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.467], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.6406], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.105], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.727], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.678],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Cohort: Adenoidectomy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.479], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.623], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−2.376], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0175], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.228], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.067], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.772],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Cohort: Adenotonsillectomy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.460], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.032], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−1.415], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.1572], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.232], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.031], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.756],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ASA: 2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.047], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.207], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.226], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.8214], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.048], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.699], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.572],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ASA: 3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.734], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.760], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.966], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.3339], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.480], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.108], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.127],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Chronic pain EPR diagnosis], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.885], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.198], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.739], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.4599], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.424], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.232], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25.375],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Procedure length (Minutes)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.005], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.004], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9968], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.990], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.010],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Coblation], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−14.444], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[362.041], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.040], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9682], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[78,822,125,137,534,361,928,301,625,501,438,453,285,514,137,540,345,737,809,912,876,469,785,903,132,926,720,178,742,846,887,992,591,595,491,155,192,313,195,174,792,047,902,159,847,274,472,471,453,547,011,572,751,347,387,568,453,607,950,986,566,774,657,066,017,152,467,242,072,639,781,306,646,785,239,564,482,895,420,554,450,246,068,414,540,706,707,615,436,296,314,379,785,492,258,673,554,435,631,742,976.000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Intra-operative opioid dose (OME mg)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.002], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.013], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.163], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.8707], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.002], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.977], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.027],
)}
], caption: figure.caption(
position: bottom, 
[
#strong[Fixed effects of model 6.]
]), 
kind: "quarto-float-stbl", 
supplement: "Table S", 
)
<stbl-model-6-fixed>


#figure([
#box(image("supplementary_materials_files/figure-typst/chunk-sfig-model-6-random-1.svg", alt: "Random effects of model 6"))

], caption: figure.caption(
position: bottom, 
[
#strong[Random effects of model 6.]
]), 
kind: "quarto-float-sfig", 
supplement: "Figure S", 
)
<sfig-model-6-random>





#bibliography(("references.bib"))

