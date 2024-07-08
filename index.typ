// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): block.with(
    fill: luma(230), 
    width: 100%, 
    inset: 8pt, 
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
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
  subrefnumbering: "1a",
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
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

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
  if type(it.kind) != "string" {
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
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    new_title_block +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black) = {
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
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: white, width: 100%, inset: 8pt, body))
      }
    )
}

#let article(
  title: none,
  running-head: none,
  authors: none,
  affiliations: none,
  authornote: none,
  abstract: none,
  keywords: none,
  margin: (x: 2.5cm, y: 2.5cm),
  paper: "us-letter",
  font: ("Times New Roman"),
  fontsize: 12pt,
  leading: 2em,
  spacing: 2em,
  first-line-indent: 1.25cm,
  toc: false,
  cols: 1,
  doc,
) = {

  set page(
    paper: paper,
    margin: margin,
    header-ascent: 50%,
    header: grid(
      columns: (1fr, 1fr),
      align(left)[#running-head],
      align(right)[#counter(page).display()]
    )
  )
  
  set par(
    justify: false, 
    leading: leading,
    first-line-indent: first-line-indent
  )

  // Also "leading" space between paragraphs
  show par: set block(spacing: spacing)

  set text(
    font: font,
    size: fontsize
  )

  if title != none {
    align(center)[
      #v(8em)#block(below: leading*2)[
        #text(weight: "bold", size: fontsize)[#title]
      ]
    ]
  }
  
  if authors != none {
    align(center)[
      #block(above: leading, below: leading)[
        #let alast = authors.pop()
        #if authors.len() > 1 {
          // If multiple authors, join appropriately
          for a in authors [
            #a.name#super[#a.affiliations], 
          ] + [and #alast.name#super[#alast.affiliations]]
        } else {
          // If only one author, format a string
          [#alast.name#super[#alast.affiliations]]
        }
      ]
    ]
  }
  
  if affiliations != none {
    align(center)[
      #block(above: leading, below: leading)[
        #for a in affiliations [
          #super[#a.id]#a.name \
        ]
      ]
    ]
  }

  align(
    bottom,
    [
      #align(center, text(weight: "bold", "Author note"))
      #authornote
      // todo: The corresponding YAML field doesn't seem to work, so hacky
      Correspondence concerning this article should be addressed to
      #for a in authors [#if a.note == "true" [#a.name, #a.email]].
    ]
  )
  pagebreak()
  
  if abstract != none {
    block(above: 0em, below: 2em)[
      #align(center, text(weight: "bold", "Abstract"))
      #set par(first-line-indent: 0pt, leading: leading)
      #abstract
      #if keywords != none {[
        #text(weight: "regular", style: "italic")[Keywords:] #h(0.25em) #keywords
      ]}
    ]
  }
  pagebreak()

  /* Redefine headings up to level 5 */
  show heading.where(
    level: 1
  ): it => block(width: 100%, below: leading, above: leading)[
    #set align(center)
    #set text(size: fontsize)
    #it.body
  ]

  show heading.where(
    level: 2
  ): it => block(width: 100%, below: leading, above: leading)[
    #set align(left)
    #set text(size: fontsize)
    #it.body
  ]

  show heading.where(
    level: 3
  ): it => block(width: 100%, below: leading, above: leading)[
    #set align(left)
    #set text(size: fontsize, style: "italic")
    #it.body
  ]

  show heading.where(
    level: 4
  ): it => text(
    size: 1em,
    weight: "bold",
    it.body + [.]
  )

  show heading.where(
    level: 5
  ): it => text(
    size: 1em,
    weight: "bold",
    style: "italic",
    it.body + [.]
  )

  if cols == 1 {
    doc
  } else {
    columns(cols, gutter: 4%, doc)
  }
  
}
#show: doc => article(
  title: "Clinical Psychology Portfolio",
  authors: (
    (
      name: "Kendra Wyant",
      affiliations: "aff-1",
      email: [],
      note: ""
    ),
    
  ),
  affiliations: (
    (
      id: "aff-1",
      name: "Department of Psychology, University of Wisconsin-Madison"
    ),
    
  ),
  doc,
)


= Background
<background>
== Personal Statement
<personal-statement>
Students should provide a brief (up to approximately 500 words) personal statement. This statement should include a narrative of their career goals to provide a context for the materials provided in their portfolio. The statement can also provide details regarding current accomplishments and expertise, anticipated accomplishments and/or expertise to be gained in the program and plans to acquire it, obstacles experienced or anticipated, or any other relevant information to contextualize their portfolio or establish themselves as an emerging clinical scientist.

== Supporting documents
<supporting-documents>
- CV
- Transcript

= Research Experiences
<research-experiences>
== Research Statement
<research-statement>
Research statement: Provide in format of tenure portfolio research statement or internship research statement (i.e., Please describe your research experience and interests in 500 words). See appendix on writing a research statement at the end of this document for more details.

== First-Author Publications
<first-author-publications>
For all published or submitted papers, students should report their relative contributions to the conceptualization, design, analysis, and writing in percentages.

== Co-Author Publications
<co-author-publications>
== Oral Presentations
<oral-presentations>
Clinical Lunch and Learn Presentation Title: Personal sensing in clinical research Date: April 7, 2021 Abstract: Personal sensing is a longitudinal method for in situ data collection. Raw personal sensing data streams (e.g., sensor or log data) can be used to create measures that act as indicators of mental health constructs. Thus, paving the way for more accessible and timely treatment and intervention options. However, using personal sensing in clinical settings requires that people accept their use and will sustain the behaviors they require. This presentation provides an overview of the acceptability of various personal sensing data streams individually and in the same context among participants with alcohol use disorder. Future implications of the acceptability of these measures will be discussed in the context of my First Year Project.

2021 PREP Symposium Title: A personal sensing approach to alcohol lapse prediction Date: August 5, 2021 Abstract: Alcohol use disorder is a chronic relapsing disease. People can relapse days, weeks, months, or even years after achieving abstinence. Identifying when an initial lapse will occur is an important goal in preventing lapses, repeated lapses, and relapse. Because of the dynamic nature of lapse risk, traditional treatment, like monthly therapy or biweekly therapy sessions, may not be best suited for monitoring lapse risk and intervening prior to relapse, or a full return to previous drinking behavior. Personal sensing methods offer a tool for capturing fluctuations in lapse risk in real time. One understudied personal sensing method in the substance use literature is cellular communication logs. The present study contextualizes participants’ communications with self-report information about their frequently communicated with contacts and seeks to develop a predictive model to predict when someone is at a high risk of lapsing.

36th Annual First-Year Project Symposium Title: Personal sensing of smartphone communications to support recovery for alcohol use disorder Date: December 3, 2021

== Poster Presentations
<poster-presentations>
- CPA Poster Abstract: Personal sensing may improve digital therapeutics for mental health care. However, further development and use of personal sensing first requires better understanding of its acceptability to people targeted for these mental health applications. Participants (N = 154; 50% female; mean age = 41; 87% White, 97% Non-Hispanic) in early recovery from alcohol use disorder were recruited from the Madison, WI area. Participants engaged with active (EMA, audio check-in, and sleep quality) and passive (geolocation, cellular communication logs, and text message content) personal sensing methods for up to three months. We assessed the acceptability of these methods using both behavioral and self-report measures. The average completion rate for all requested EMAs was 81%. The completion rate for the audio check-in was 55%. Aggregate participant ratings indicated all methods to be significantly more acceptable (all P’s \< .05) compared to neutral across subjective measures of interference, dislike, and willingness to use for one year. Participants did not significantly differ in their dislike of active compared to passive methods (P = .23). However, participants reported a higher willingness to use passive methods for one year compared to active methods (P = .04). These results suggest both active and passive personal sensing methods are generally acceptable to people with alcohol use disorder. Important individual differences were observed both across people and methods which indicate opportunities for future improvements.

== Workshops
<workshops>
Introduction to Structural Equation Modeling Workshop Instructors: Daniel Bauer, Ph.D.~& Patrick Curran, Ph.D. Date: May 10 – 12, 2021 Summary: A three-day workshop focused on the application and interpretation of statistical models that are designed for the analysis of multivariate data with latent variables. Although the traditional multiple regression model is a powerful analytical tool within the social sciences, this is also highly restrictive in a variety of ways. Not only are all variables assumed to have no measurement error, but it is also limited to a single dependent variable with unidirectional effects. The structural equation model (SEM) generalizes the linear regression model to include multiple dependent variables, reciprocal effects, indirect effects, and the estimation and removal of measurement error through the inclusion of latent variables. The SEM is a general framework that allows for the empirical testing of research hypotheses in ways not otherwise possible. In this workshop we provide an introduction to SEM that includes path analysis, confirmatory factor analysis, and structural equation models with latent variables, and which focuses on both establishing a conceptual understanding of the model and how it is applied in practice.

== Near Future Directions (include in slide deck not portfolio)
<near-future-directions-include-in-slide-deck-not-portfolio>
- submit lag paper by end of month
- propose dissertation in Spring

= Clinical Experiences
<clinical-experiences>
== Clinical Orientation Statement
<clinical-orientation-statement>
Internship clinical orientation statement: Please describe your theoretical orientation and how this influences your approach to case conceptualization and intervention. You may use de-identified case material to illustrate your points if you choose. 500 word limit

== Practicum Experiences
<practicum-experiences>
Descriptions of clinical practicum experiences: Brief description should include the name and dates for the practicum, brief description of the client population and other relevant details (e.g., interventions, modalities). This should include documentation of clinical hours (per internship categories) and available/completed supervisor evaluations.

== Certification by Clinical Director
<certification-by-clinical-director>
== Assessment Report
<assessment-report>
Provide integrative or other assessment reports after appropriate de-identification. Do not include raw data from assessments.

== \#\#\# Near Future Directions (include in slide deck not portfolio)
<near-future-directions-include-in-slide-deck-not-portfolio-1>
- VA

= Diversity Experiences
<diversity-experiences>
== Diversity Statement
<diversity-statement>
== Workshops
<workshops-1>
Empowering people to break the bias habit: Evidenced-based approaches to reducing bias and creating inclusion Speaker: Will Cox, Ph.D. Description: 3-hour workshop to introduce academic audiences to the concepts of implicit or unconscious biases and assumptions about diverse groups of people by treating the application of such biases as a "habit." Participants will uncover their own biases, discover the underlying concepts and language used in the psychological and social psychological literature to describe such processes, participate in interactive discussions about the potential influence of implicit or unconscious bias in their department/unit, and learn evidence-based strategies for reducing the application of these biases.

== Mentorship and Committees
<mentorship-and-committees>
+ Maximizing Access to Research Careers Alumni Mentor Program Date: Fall 2020 – Spring 2022 Mentee: Christopher Creighton, CSUF – Fullerton, CA

+ PREP Alumni Mentor Program Date: Summer 2021 Mentee: Olivia Sutton, Westminster College – Salt Lake City, UT

+ Clinical Area Antiracism and Academic Training Committee Member Date: Fall 2020 – Spring 2021

+ PREP Research Mentor, includes summer DELTA training (provide syllabus)

== Near Future Directions (include in slide deck not portfolio)
<near-future-directions-include-in-slide-deck-not-portfolio-2>
- Project SHORT Mentor

= Teaching Experiences
<teaching-experiences>
- guest lecture
- led lecture discussion on explanatory methods in IAML, co-led weekly lab
- materials for GLM
- Grading papers and open ended exams and providing feedback on writing for 2 classes since 2021

== Near Future Directions (include in slide deck not portfolio)
<near-future-directions-include-in-slide-deck-not-portfolio-3>
- TA IAML and GLM

= References
<references>
#block[
] <refs>



#bibliography("portfolio.bib")

