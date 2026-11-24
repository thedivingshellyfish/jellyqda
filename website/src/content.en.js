/* ---------- 1. Content: interview types ---------- */
// st = fit with the degree of structure (2 good fit, 1 possible, 0 rather not)
// lg = fit with the analysis logic; good/ok = typical analysis methods
const IV = {
  pzi: {
    em: "🎯", name: "Problem-centred interview", by: "Witzel",
    short: "Subjective views on a socially relevant problem: narration and targeted follow-up questions take turns.",
    wissen: "Experiences, views and reasons for action regarding a clearly defined problem.",
    pos: [.42, .52],
    st: { offen: 1, halboffen: 2, strukturiert: 0 },
    stNote: { offen: "Works if you keep the guide in your head as a memory aid – but the PCI needs your prior knowledge as a frame.", halboffen: "Made for this: the guide is a scaffold, narratives get room.", strukturiert: "Fixed questions prevent the probing on which the PCI depends." },
    lg: { de: 1, in: 1, mix: 2, ab: 1 },
    lgNote: "Witzel explicitly describes the PCI as an interplay of induction and deduction – deductive-inductive is the norm.",
    ablauf: [["Short questionnaire", "socio-demographics first, so they don't disturb the talk"], ["Narrative prompt", "open entry into the problem"], ["General probing", "deepen narratives: “What exactly happened?”"], ["Specific probing", "mirroring, comprehension questions, confrontation if needed"], ["Ad-hoc questions", "guide topics not yet covered"], ["Postscript", "right after: impressions, atmosphere, anything striking"]],
    achten: ["Your prior knowledge is allowed and wanted – but as a <b>sensitising concept</b>, not as hypotheses you test.", "The guide is a memory aid, not a questionnaire: keep the order flexible.", "Don't phrase comprehension questions suggestively (use “So you mean that …?” sparingly).", "Write the postscript straight after the interview – it becomes a document memo in jellyqda."],
    auswertung: "Main categories can come from the guide topics, subcategories emerge from the material. Typical: Kuckartz’s content-structuring QCA, or a combination of Mayring’s structuring and summarising analysis.",
    good: ["kuckartz_s", "mayring_s", "mayring_z", "thema"], ok: ["gt", "kuckartz_t", "kuckartz_e", "flick"]
  },
  exp_theo: {
    em: "🧠", name: "Theory-generating expert interview", alt: "sometimes called “theorising” expert interview", by: "Bogner, Littig & Menz; Meuser & Nagel",
    short: "Experts as holders of interpretive knowledge – the aim is a theory of their views and logics of action.",
    wissen: "Interpretive knowledge: the experts’ subjective relevances, rules, views and interpretations – often implicit, not easy to ask for directly.",
    pos: [.4, .55],
    st: { offen: 1, halboffen: 2, strukturiert: 0 },
    stNote: { offen: "Possible if you work very exploratively – but without a guide, comparing experts becomes hard.", halboffen: "Good fit: the guide ensures comparability and a competent appearance, yet leaves room for interpretations.", strukturiert: "Interpretive knowledge shows in reasons and examples – fixed questions cut exactly that off." },
    lg: { de: 0, in: 2, mix: 2, ab: 1 },
    lgNote: "Theory should emerge from the material. Inductive or deductive-inductive (main topics from the guide, concepts from the material) fit; purely deductive contradicts the aim.",
    ablauf: [["Access & role", "Who counts as an expert, and why? Justify your sampling"], ["Opening", "position, tasks, career"], ["Guide blocks", "open questions on problems and decisions"], ["Follow-up", "reasons, examples, counter-examples"], ["Closing", "“What haven’t we talked about?”"], ["Postscript", "note the interaction and how they saw you"]],
    achten: ["Don’t just ask for facts (“How does X work?”), ask for <b>reasons and judgements</b> (“Why do you think that makes sense?”) – that is where interpretive knowledge lies.", "Reflect on how the experts see you (co-expert, layperson, critic …) – it shapes their answers. Note it in the postscript.", "Small fields = easy to recognise: consistently pseudonymise position, organisation and anecdotes.", "Justify the expert status in your methods section (knowledge by position, experience, responsibility)."],
    auswertung: "The aim is building concepts and theory: code close to the text (in vivo, too), then compare themes across all interviews and abstract step by step. The classic choice is Meuser & Nagel; grounded theory or Kuckartz with a strong inductive part also fit.",
    good: ["meuser", "gt", "kuckartz_s"], ok: ["mayring_z", "thema", "kuckartz_t"]
  },
  exp_sys: {
    em: "🗂️", name: "Systematising expert interview", by: "Bogner, Littig & Menz; Gläser & Laudel",
    short: "Experts as a source of exclusive factual and process knowledge – as complete and comparable as possible.",
    wissen: "Technical and process knowledge: procedures, responsibilities, events only they know about.",
    pos: [.6, .78],
    st: { offen: 0, halboffen: 2, strukturiert: 1 },
    stNote: { offen: "Without a guide you will end up missing information you systematically need.", halboffen: "Good fit: a theory-based guide with room to probe for details.", strukturiert: "Possible if the field is already well known – but you lose unexpected information." },
    lg: { de: 2, in: 0, mix: 2, ab: 0 },
    lgNote: "You are looking for information on theoretically defined dimensions – deductive with an open category system (new values may be added).",
    ablauf: [["Theory & variables", "What exactly do you need to know?"], ["Guide", "topic blocks per dimension"], ["Interview", "focused, with follow-up on details"], ["Cross-check", "note contradictions between sources"]],
    achten: ["A theory-based, complete guide – every question should belong to one dimension of your study.", "Compare statements of different experts (triangulation) and record contradictions in memos.", "Don’t ask for judgements too early, or they colour the factual account."],
    auswertung: "Information is extracted from the text along categories defined in advance (extraction after Gläser & Laudel) – the category system stays open for new values. Alternatively Mayring’s structuring content analysis.",
    good: ["glaeser", "mayring_s", "kuckartz_s"], ok: ["kuckartz_e", "meuser"]
  },
  exp_expl: {
    em: "🧭", name: "Exploratory expert interview", by: "Bogner, Littig & Menz",
    short: "First orientation in a new field – often a pilot study for a guide or hypotheses.",
    wissen: "Context knowledge about a field that is still unknown: Who matters? What are the issues?",
    pos: [.2, .5],
    st: { offen: 2, halboffen: 2, strukturiert: 0 },
    stNote: { offen: "Good fit: you know little yet – let them explain the field.", halboffen: "Good fit: a rough topic list helps you not to forget anything important.", strukturiert: "Too early: you don’t know the field well enough for fixed questions." },
    lg: { de: 0, in: 2, mix: 1, ab: 1 },
    lgNote: "Exploratory means gaining topics from the material – inductive.",
    ablauf: [["Sketch the field", "actors, topics, terms"], ["Open conversation", "rough topic list"], ["Notes / protocol", "a transcript is not always needed"], ["Result", "sharpen the guide or the research question"]],
    achten: ["Label it as a pilot study – the results rarely stand as findings on their own.", "Ask broadly and collect the field’s own terms (they become your in-vivo codes later).", "A detailed interview protocol may be enough – jellyqda imports it like a transcript."],
    auswertung: "Collect and organise topics and terms inductively, e.g. summarising after Mayring or with a thematic analysis. The result is often a better interview guide.",
    good: ["mayring_z", "thema", "kuckartz_s"], ok: ["gt"]
  },
  narrativ: {
    em: "📖", name: "Narrative interview", by: "Schütze",
    short: "One long improvised narrative, e.g. the person’s life story – the interviewees decide on structure and relevance.",
    wissen: "How experiences build up and the process structures of the life course, as they show in the narrative.",
    pos: [.02, .14],
    st: { offen: 2, halboffen: 0, strukturiert: 0 },
    stNote: { offen: "The only way: the narrative must not be steered by questions.", halboffen: "A guide in the main part destroys the improvised narrative. Questions only come afterwards.", strukturiert: "Contradicts the method fundamentally." },
    lg: { de: 0, in: 1, mix: 0, ab: 2 },
    lgNote: "Narrative interviews are usually analysed reconstructively (sequentially, abductively). Simply assigning categories cuts the narrative into pieces.",
    ablauf: [["Narrative prompt", "one single, well-prepared opening question"], ["Main narrative", "don’t interrupt, just listen actively"], ["Immanent questions", "follow up gaps in the narrative"], ["Exmanent questions", "your own topics, why-questions"], ["Balancing phase", "the narrator’s own theories"]],
    achten: ["Pilot the narrative prompt – it decides the whole interview.", "Endure pauses, don’t interrupt, don’t judge.", "Plan plenty of time; transcribe precisely (pauses, breaks, emphasis), because the analysis starts from the form.", "Interpret in a group if you can (interpretation workshop)."],
    auswertung: "Narrative analysis: distinguish text types (narration, description, argumentation), interpret sequence by sequence, then compare contrastively. jellyqda helps with marking sequences and with memos – the actual interpretation happens in your head and in the group.",
    good: ["narration", "gt", "doku"], ok: ["thema"]
  },
  episodisch: {
    em: "🧩", name: "Episodic interview", by: "Flick",
    short: "Combines narratives of concrete situations with questions about concepts and definitions.",
    wissen: "Episodic knowledge (experiences in situations) and semantic knowledge (concepts, relationships).",
    pos: [.3, .5],
    st: { offen: 1, halboffen: 2, strukturiert: 0 },
    stNote: { offen: "Works, but switching deliberately between narratives and concept questions needs a guide.", halboffen: "Good fit: a guide with narrative prompts and definition questions.", strukturiert: "Narratives of situations need space – fixed questions are too narrow." },
    lg: { de: 1, in: 1, mix: 2, ab: 1 },
    lgNote: "Flick’s thematic coding works case by case and then comparatively, with a thematic structure developed from the material – usually deductive-inductive.",
    ablauf: [["Explain the principle", "“I will keep asking you to tell me about situations”"], ["Narrative prompts", "“Tell me about a situation when …”"], ["Concept questions", "“What do you associate with …?”"], ["Everyday life & change", "routines, changes"], ["Closing", "feedback, postscript"]],
    achten: ["Explain the principle at the start, otherwise people only answer in the abstract.", "Switch deliberately between situation and definition.", "Ask for concrete examples when answers stay general."],
    auswertung: "Thematic coding (Flick): first describe and code each case on its own, then build a shared thematic structure and compare cases – the summary grid and case comparison in jellyqda fit this well.",
    good: ["flick", "kuckartz_s", "thema"], ok: ["mayring_z", "gt"]
  },
  fokussiert: {
    em: "🎬", name: "Focused interview", by: "Merton & Kendall",
    short: "All interviewees experience the same stimulus (film, text, situation) – the interview asks about their reactions to it.",
    wissen: "Subjective reactions and interpretations of a shared stimulus that you analysed beforehand.",
    pos: [.5, .72],
    st: { offen: 0, halboffen: 2, strukturiert: 1 },
    stNote: { offen: "Without a guide you lose the link to the stimulus.", halboffen: "Good fit: a guide derived from the stimulus analysis, open to unexpected reactions.", strukturiert: "Possible, but Merton & Kendall explicitly stress non-direction and range." },
    lg: { de: 2, in: 1, mix: 2, ab: 0 },
    lgNote: "The stimulus analysis produces assumptions and categories – often deductive or deductive-inductive.",
    ablauf: [["Analyse the stimulus", "assumptions about its effects"], ["Guide", "derived from the analysis"], ["Show the stimulus", "shared situation"], ["Interview", "unstructured → increasingly structured"]],
    achten: ["Quality criteria after Merton & Kendall: non-direction, specificity, range, depth and personal context.", "Ask for specific reactions (“Which scene …?”), not general opinions."],
    auswertung: "Fix categories from the stimulus analysis in advance (structuring), add unexpected reactions inductively.",
    good: ["mayring_s", "kuckartz_s"], ok: ["thema", "kuckartz_e"]
  },
  leitfaden: {
    em: "📋", name: "Semi-structured interview (general)", alt: "guided interview / interview with a topic guide", by: "Helfferich; Brinkmann & Kvale",
    short: "The all-rounder in theses: topic blocks, open questions, flexible follow-ups.",
    wissen: "Experiences, assessments and reasons regarding topics fixed in advance.",
    pos: [.45, .8],
    st: { offen: 0, halboffen: 2, strukturiert: 1 },
    stNote: { offen: "Then it is closer to a narrative interview – check whether that fits your question.", halboffen: "Good fit: as open as possible, as structured as necessary.", strukturiert: "Possible if comparability matters more than depth." },
    lg: { de: 1, in: 1, mix: 2, ab: 0 },
    lgNote: "Guide topics provide main categories, answers provide subcategories – deductive-inductive is the obvious choice.",
    ablauf: [["Guide via the SPSS principle", "collect, check, sort, subsume"], ["Pilot", "at least one test interview"], ["Interview", "narrative prompt per block, then follow-ups"], ["Postscript", "right after"]],
    achten: ["Develop the guide with Helfferich’s SPSS principle (German: <b>S</b>ammeln, <b>P</b>rüfen, <b>S</b>ortieren, <b>S</b>ubsumieren – collect, check, sort, subsume).", "Open narrative prompts instead of yes/no questions.", "Pilot the guide and adapt it – document the changes."],
    auswertung: "Kuckartz’s content-structuring QCA or Mayring’s structuring content analysis with inductive additions.",
    good: ["kuckartz_s", "mayring_s", "mayring_z", "thema"], ok: ["kuckartz_t", "kuckartz_e", "gt", "glaeser"]
  },
  gruppe: {
    em: "👥", name: "Group discussion / focus group", by: "Bohnsack; Krueger & Casey",
    short: "Several people discuss an opening stimulus – revealing collective orientations or a range of opinions.",
    wissen: "Collective orientations (group discussion) or a spectrum of opinions (focus group).",
    pos: [.12, .5],
    st: { offen: 2, halboffen: 2, strukturiert: 0 },
    stNote: { offen: "Good fit for group discussions: a self-sustaining discussion is the goal.", halboffen: "Good fit for focus groups with a moderation guide.", strukturiert: "Fixed questions in turn = several individual interviews, the group is lost." },
    lg: { de: 1, in: 2, mix: 2, ab: 2 },
    lgNote: "Collective orientations are analysed reconstructively (documentary method); focus groups usually with content analysis.",
    ablauf: [["Opening stimulus", "open question or stimulus"], ["Self-sustaining discussion", "the moderator holds back"], ["Immanent questions", ""], ["Exmanent questions", "missing topics"]],
    achten: ["Decide clearly: is the group or the individual the unit of analysis?", "Transcribe with unique speaker labels (Am, Bf …) – jellyqda turns them into segments.", "Moderate with restraint, gently slow down dominant speakers."],
    auswertung: "Reconstructively with the documentary method (formulating and reflecting interpretation), or with Kuckartz’s content analysis for focus groups.",
    good: ["doku", "kuckartz_s", "thema"], ok: ["mayring_z", "mayring_s"]
  }
};

/* ---------- Degree of openness ---------- */
const ST = {
  offen: {
    em: "🌊", name: "Open (narrative)", short: "One narrative prompt, hardly any guidance. Interviewees structure the talk themselves.",
    frage: "“Please tell me how it came about that you … – everything that matters to you.”",
    folgen: ["Material varies a lot in length and structure; topics appear in unpredictable places.", "An inductive or reconstructive analysis is the obvious choice.", "A category system fixed in advance rarely fits."],
    seg: "Segments by <b>paragraphs</b> (or later by hand, by units of meaning) – speaker turns are rare and very long.",
    segmode: "blankline", lg: { de: 0, in: 2, mix: 1, ab: 2 }
  },
  halboffen: {
    em: "🧵", name: "Semi-open (guide-based)", short: "A guide with topic blocks and open questions, flexible order, follow-ups allowed.",
    frage: "“How do you experience working together in your team?” – then: “Could you tell me about an example?”",
    folgen: ["Guide topics give a scaffold for main categories, answers give subcategories.", "Careful: answers on a topic don’t only appear after “their” question – code the whole interview, not just question–answer pairs.", "Deductive-inductive is the norm."],
    seg: "Segments by <b>speaker turn</b> (<code>[00:01:12] R: …</code>) – each answer is one segment.",
    segmode: "speaker", lg: { de: 1, in: 2, mix: 2, ab: 1 }
  },
  strukturiert: {
    em: "🧱", name: "Structured (fixed guide)", short: "Fixed questions in a fixed order, possibly with answer options.",
    frage: "“Question 4: How satisfied are you with … – please give a short reason.”",
    folgen: ["High comparability, little depth and surprise.", "Deductive categories are the obvious choice; frequencies become tempting – but they still need qualitative interpretation.", "Close to a standardised survey: check whether a questionnaire would fit better."],
    seg: "Segments by <b>speaker turn</b>; each answer belongs to one question.",
    segmode: "speaker", lg: { de: 2, in: 1, mix: 1, ab: 0 }
  }
};

/* ---------- Analysis logic ---------- */
const LG = {
  de: { em: "⬇️", name: "Deductive", cls: "de", short: "Categories come in advance from theory, literature or the guide – then you apply them to the material.",
    wann: "When there is a sound theory and you want to apply, test or refine it.",
    risiko: "You only find what you look for. New things slip through – plan an “other” category and memos for surprises.",
    tools: "Coding guideline, code system set up in advance, code all search hits, code matrix" },
  in: { em: "⬆️", name: "Inductive", cls: "in", short: "Categories emerge step by step from the material.",
    wann: "When a field is under-researched or the interviewees’ perspective is the focus.",
    risiko: "It never works entirely without prior knowledge. Make yours explicit and don’t drown in hundreds of tiny codes – condense regularly.",
    tools: "In-vivo codes, memos, merging codes, Mayring table, word frequencies, keyword in context" },
  mix: { em: "🔁", name: "Deductive-inductive", cls: "mix", short: "Main categories in advance (e.g. from the guide), subcategories from the material.",
    wann: "The most common route for semi-structured interviews and in theses.",
    risiko: "Separate clearly in your methods section: which categories existed beforehand, which emerged from the material? The jellyqda audit trail helps.",
    tools: "Codes + subcodes, coding guideline, in vivo, summary grid, case comparison" },
  ab: { em: "🌀", name: "Abductive / reconstructive", cls: "ab", short: "Sequential interpretation: from a surprising finding to an explanatory hypothesis – and back to the material.",
    wann: "For narrative interviews and group discussions, when implicit structures of meaning are to be reconstructed.",
    risiko: "Coding is only an aid here. Interpretation needs time, sequential analysis and ideally an interpretation group.",
    tools: "Codes as bookmarks for sequences, passage memos, report with margin column for the interpretation group" }
};

/* ---------- Analysis methods ---------- */
// x: 0 deductive … 1 inductive; y: 0 descriptive/content-analytic … 1 reconstructive; sup: jellyqda support 2/1/0
const PR = {
  mayring_z: { name: "Summarising content analysis", by: "Mayring", short: "Mayring sum.", x: .84, y: .06, la: "l", sup: 2, lg: { de: 0, in: 2, mix: 2, ab: 0 },
    what: "The material is reduced step by step until a manageable, inductively built category system remains.",
    steps: ["Define units of analysis (coding, context and recording unit)", "Paraphrase: content briefly in your own words", "Generalise to the chosen level of abstraction", "First reduction: delete what means the same", "Second reduction: bundle into categories", "Check the category system against the original material"],
    jq: "Mayring table (Analysis → Summary) with paraphrase and generalisation per coding; reduction = building and merging codes.",
    lit: ["mayring"] },
  mayring_s: { name: "Structuring content analysis", by: "Mayring", short: "Mayring struct.", x: .12, y: .32, la: "r", sup: 2, lg: { de: 2, in: 0, mix: 1, ab: 0 },
    what: "Theory-driven categories are applied to the material with a coding guideline (content, type or scaling structuring).",
    steps: ["Define the structuring dimensions based on theory", "Determine the category system and its values", "Coding guideline: definition, anchor example, coding rule", "Trial run: mark the relevant passages", "Revise categories and guideline", "Main run and preparing the results"],
    jq: "Coding guideline right at the code (book icon), anchor examples with one click from the text, code matrix for preparing results.",
    lit: ["mayring"] },
  kuckartz_s: { name: "Content-structuring QCA", by: "Kuckartz & Rädiker", short: "Kuckartz CS", x: .4, y: .2, la: "r", sup: 2, lg: { de: 1, in: 1, mix: 2, ab: 0 },
    what: "Main categories deductive, subcategories inductive, several coding cycles, then case-based and category-based analysis.",
    steps: ["Initial work with the text: read, highlight, memos, case summaries", "Develop main categories (usually from guide/theory)", "First coding cycle with the main categories", "Build subcategories inductively from the material", "Second coding cycle with the refined system", "Simple and complex analyses (tables, case comparisons)", "Write up results and document the procedure"],
    jq: "Memos, codes + subcodes, summary grid for thematic case summaries, code matrix and case comparison.",
    lit: ["kuckartz"] },
  kuckartz_t: { name: "Type-building QCA", by: "Kuckartz & Rädiker", short: "Kuckartz types", x: .38, y: .62, la: "l", sup: 1, lg: { de: 1, in: 1, mix: 2, ab: 1 },
    what: "Cases are grouped along an attribute space so that types emerge that are similar within and different between each other.",
    steps: ["Define the attribute space (relevant categories/variables)", "Code and summarise cases", "Group cases, build types", "Describe types, choose prototypical cases", "Check relations between types and variables"],
    jq: "Coding, document variables and case comparison, yes; the actual type building you do in a spreadsheet (export to Excel).",
    lit: ["kuckartz"] },
  kuckartz_e: { name: "Evaluative QCA", by: "Kuckartz & Rädiker", short: "Kuckartz eval.", x: .22, y: .46, la: "r", sup: 2, lg: { de: 2, in: 0, mix: 2, ab: 0 },
    what: "Passages are assessed and coded with values (e.g. high/medium/low).",
    steps: ["Define evaluative categories and their values", "Code passages to the category", "Assign values per case, rules for borderline cases", "Compare cases and groups"],
    jq: "Values as subcodes (e.g. “Strain › high”), coding rule in the coding guideline, case comparison by variables.",
    lit: ["kuckartz"] },
  glaeser: { name: "Qualitative content analysis by extraction", by: "Gläser & Laudel", short: "Gläser/Laudel", x: .08, y: .08, la: "r", sup: 2, lg: { de: 2, in: 0, mix: 2, ab: 0 },
    what: "Information is taken from the text and assigned to theoretically derived categories – the category system stays open.",
    steps: ["Derive categories from theory and research question", "Read the text, extract relevant information", "Assign information to categories (allow new values)", "Process and analyse the extracted information"],
    jq: "Set up codes in advance, use the paraphrase field as “extraction”, export codings as a table.",
    lit: ["glaeser"] },
  meuser: { name: "Analysis after Meuser & Nagel", by: "Meuser & Nagel", short: "Meuser/Nagel", x: .76, y: .54, la: "l", sup: 2, lg: { de: 0, in: 2, mix: 1, ab: 1 },
    what: "Developed for expert interviews: paraphrase and code close to the text, compare thematically, then conceptualise sociologically.",
    steps: ["Transcription (thematically relevant passages)", "Paraphrase the passages", "Code with headings close to the text (the interviewees’ terms)", "Thematic comparison across all interviews", "Sociological conceptualisation", "Theoretical generalisation"],
    jq: "Paraphrase field, in-vivo codes for headings close to the text, merging codes during the thematic comparison, code matrix.",
    lit: ["meuser", "bogner"] },
  gt: { name: "Grounded theory", by: "Glaser & Strauss; Strauss & Corbin; Charmaz", short: "Grounded theory", x: .9, y: .64, la: "l", sup: 1, lg: { de: 0, in: 2, mix: 0, ab: 2 },
    what: "Theory emerges from the data through constant comparison; data collection and analysis alternate (theoretical sampling).",
    steps: ["Open coding: break concepts open", "Axial coding: relations around key categories", "Selective coding: core category", "Memos from the very start", "Constant comparison", "Theoretical sampling until saturation"],
    jq: "Coding, in vivo, code and project memos, moving and merging codes. Theoretical sampling you plan outside – you can import new interviews at any time.",
    lit: ["strauss"] },
  thema: { name: "Reflexive thematic analysis", by: "Braun & Clarke", short: "Thematic an.", x: .64, y: .27, la: "r", sup: 2, lg: { de: 1, in: 2, mix: 2, ab: 1 },
    what: "Themes are actively developed by the researcher – inductively or theory-driven, in six phases.",
    steps: ["Familiarise yourself with the data", "Generate codes", "Construct initial themes", "Review and develop themes", "Define and name themes", "Write up"],
    jq: "Codes, code memos as theme definitions, merging codes, report.",
    lit: ["braun"] },
  flick: { name: "Thematic coding", by: "Flick", short: "Flick", x: .56, y: .4, la: "r", sup: 2, lg: { de: 1, in: 1, mix: 2, ab: 0 },
    what: "For comparative studies: first single-case analysis with a short description, then a shared thematic structure for comparing cases.",
    steps: ["Short description of each case", "Case-based coding", "Thematic structure from the first cases", "Analyse further cases with it and adapt the structure", "Case comparison"],
    jq: "Document memo as case description, summary grid, case comparison by variables.",
    lit: ["flick"] },
  narration: { name: "Narrative analysis", by: "Schütze", short: "Narrative an.", x: .82, y: .84, la: "l", sup: 0, lg: { de: 0, in: 1, mix: 0, ab: 2 },
    what: "Reconstructs process structures of the life course from the formal and content structure of the narrative.",
    steps: ["Formal text analysis: separate narrative from other passages", "Structural description of content", "Analytical abstraction", "Knowledge analysis (the narrator’s own theories)", "Contrastive comparison", "Theoretical model"],
    jq: "Only as support: mark sequences as codes, interpretations as passage memos, report with margin column for interpretation groups.",
    lit: ["schuetze"] },
  doku: { name: "Documentary method", by: "Bohnsack", short: "Documentary m.", x: .6, y: .94, la: "l", sup: 0, lg: { de: 0, in: 1, mix: 0, ab: 2 },
    what: "Distinguishes what is said (immanent meaning) from how it is said (documentary meaning) to reconstruct frames of orientation.",
    steps: ["Thematic course", "Formulating interpretation", "Reflecting interpretation (organisation of discourse)", "Case description", "Comparative analysis and type building"],
    jq: "Only as support: mark passages, interpretations in memos, segments by speaker turn for the organisation of discourse.",
    lit: ["bohnsack"] }
};

/* ---------- Research aims (step 1) ---------- */
const ZI = {
  pruefen: { em: "🔬", name: "Apply or test a theory", short: "There is a model or concept you want to test or refine against your material.", iv: ["leitfaden", "exp_sys", "fokussiert", "pzi"], lg: "de" },
  verstehen: { em: "💬", name: "Understand experiences and views", short: "How do people experience a problem, how do they justify what they do?", iv: ["pzi", "leitfaden", "episodisch"], lg: "mix" },
  experten: { em: "🧠", name: "Use the knowledge of experts", short: "You talk to people because of their position or experience in a field.", iv: ["exp_theo", "exp_sys", "exp_expl"], lg: "mix" },
  theorie: { em: "🌱", name: "Develop new theory / concepts", short: "You want to explain how something works – and have no ready-made model yet.", iv: ["exp_theo", "narrativ", "pzi"], lg: "in" },
  erkunden: { em: "🧭", name: "Explore a new field", short: "You know little so far and want to get your bearings (e.g. a pilot study).", iv: ["exp_expl", "leitfaden"], lg: "in" },
  biografie: { em: "📖", name: "Reconstruct biographies or processes", short: "How did something develop in people’s lives?", iv: ["narrativ", "episodisch"], lg: "ab" },
  gruppe: { em: "👥", name: "Collective orientations / range of opinions", short: "What does a group share? Which opinions exist?", iv: ["gruppe"], lg: "mix" }
};

/* ---------- 2. Basics ---------- */
const MOD = [
  { id: "qda", icon: "🔎", color: "#38bdf8", title: "What is qualitative data analysis?", blurb: "Understanding instead of measuring: principles, aims and how it differs from statistics.",
    body: () => `
<div class="md"><p>Qualitative data analysis (QDA) opens up <b>meanings</b>: How do people interpret their world, how do they justify their actions, which patterns show across several cases? It is usually based on texts – interview transcripts, field notes, documents.</p></div>
${vis("quali")}
<div class="md"><p><b>Four principles</b> you will find in almost every textbook:</p><ul>
<li><b>Openness</b> – to the unexpected and to what matters to the interviewees.</li>
<li><b>Communication</b> – data emerge in conversation; you are part of the situation.</li>
<li><b>Process</b> – research question, categories and sampling may evolve.</li>
<li><b>Reflexivity</b> – your role, prior knowledge and decisions are made explicit.</li></ul></div>
${box("tip", "💡", "Question first, then method", "The method follows from the research question, not the other way round. The compass helps you connect question, interview type and analysis coherently.")}
${box("warn", "⚠️", "Careful with frequencies", "jellyqda shows numbers (codings per code, percentages in the report). In qualitative research they describe the distribution in your material – they are no evidence of prevalence in a population.")}`,
    quiz: [
      { q: "What is the main aim of qualitative data analysis?", o: ["Secure frequencies statistically", "Understand meanings and patterns", "Test hypotheses with significance tests", "Analyse samples as large as possible"], a: 1, ex: "It is about meaning, interpretations and patterns – not statistical generalisation." },
      { q: "In jellyqda, “motivation” appears in 7 of 10 interviews. What may you conclude?", o: ["70 % of all employees are motivated", "The topic was widely present in your material", "Motivation is the most important factor", "Nothing, numbers are forbidden in QDA"], a: 1, ex: "Numbers describe your material. They are allowed, but not representative." }
    ] },
  { id: "logik", icon: "🔁", color: "#a78bfa", title: "Inductive, deductive, abductive", blurb: "Where do the categories come from? The key decision – with an interactive diagram.",
    body: () => `
<div class="md"><p>The central question of every analysis: <b>Where do your categories come from?</b></p></div>
${vis("logik")}
<div class="tblwrap"><table class="tbl"><tr><th>Logic</th><th>Categories come from …</th><th>typical methods</th></tr>
<tr><td><span class="tag de">deductive</span></td><td>theory, literature, interview guide</td><td>Mayring structuring, Gläser & Laudel, Kuckartz evaluative</td></tr>
<tr><td><span class="tag in">inductive</span></td><td>the material itself</td><td>Mayring summarising, Meuser & Nagel, grounded theory</td></tr>
<tr><td><span class="tag mix">deductive-inductive</span></td><td>both: main categories in advance, subcategories from the material</td><td>Kuckartz content-structuring, Flick, thematic analysis</td></tr>
<tr><td><span class="tag ab">abductive</span></td><td>surprising findings that need a new explanation</td><td>grounded theory, narrative analysis, documentary method</td></tr></table></div>
${box("tip", "💡", "Purely inductive doesn’t exist", "Nobody reads a transcript without prior knowledge. What matters is making it explicit – e.g. in a project memo “My prior knowledge” in jellyqda, before you start coding.")}
${box("jq", "🪼", "In jellyqda", "Deductive: set up codes in advance + coding guideline. Inductive: mark text → <b>In vivo</b>, organise later by moving and merging codes. Everything can be undone (Ctrl+Z) and is in the audit trail.")}`,
    quiz: [
      { q: "You create codes from the topic blocks of your guide and add subcodes while reading. That is …", o: ["purely deductive", "purely inductive", "deductive-inductive", "abductive"], a: 2, ex: "Main categories in advance, subcategories from the material: the classic mixed approach." },
      { q: "Which jellyqda function is typically inductive?", o: ["Filling in the coding guideline in advance", "In-vivo code", "Code all search hits", "Case comparison"], a: 1, ex: "In vivo turns the interviewees’ own words into the code." }
    ] },
  { id: "prozess", icon: "🗺️", color: "#34d399", title: "The research process", blurb: "From the question to the methods section – and where jellyqda helps.",
    body: () => `
<div class="md"><p>Qualitative research rarely runs in a strictly linear way. A plan still helps – above all to start analysing in time.</p></div>
${vis("prozess")}
${box("tip", "💡", "Start analysing early", "Code the first interview before you have conducted them all. You will see whether your guide works, and your postscript is still fresh.")}
${box("warn", "⚠️", "Time planning", "A rule of thumb from practice: transcription takes several times the length of the interview, and analysis almost always takes longer than planned. Build in buffers.")}`,
    quiz: [
      { q: "When is a good time to start coding?", o: ["Only when all interviews are transcribed", "After the first interviews", "After writing up the results", "Before developing the guide"], a: 1, ex: "Early coding improves guide and sampling – in grounded theory it is even required." }
    ] },
  { id: "interviews", icon: "🎙️", color: "#f472b6", title: "Interview types & openness", blurb: "From narrative to structured: which type for which question – and what “guide-based” actually means.",
    body: () => `
<div class="md"><p>Interview types differ above all in <b>how strongly you structure the conversation</b> and <b>which kind of knowledge</b> you want to collect. Tap a row for details.</p></div>
${vis("spektrum")}
${box("tip", "💡", "“Guide-based” is not a degree of openness", "The term describes the instrument, not the openness: there are semi-open guides (flexible order, lots of room for narratives) and structured ones (fixed questions). Most textbooks mean the semi-open one when they say semi-structured interview.")}
${box("warn", "⚠️", "Openness shapes the analysis", "The more open the data collection, the less a rigid category system fixed in advance fits. Analysing a narrative interview purely deductively throws away exactly what you conducted it for.")}
<div class="btnrow"><a class="btn primary" href="#/compass">${ICON.compass} Choose your type in the compass</a></div>`,
    quiz: [
      { q: "Which interview depends on an uninterrupted improvised narrative?", o: ["Problem-centred interview", "Narrative interview", "Systematising expert interview", "Focused interview"], a: 1, ex: "Schütze’s narrative interview: let them tell first, questions only afterwards." },
      { q: "You want to reconstruct the interpretive knowledge of managers. What fits best?", o: ["Systematising expert interview", "Theory-generating expert interview", "Standardised questionnaire", "Focused interview"], a: 1, ex: "Interpretive knowledge (views, logics of action) is the core of the theory-generating expert interview." }
    ] },
  { id: "verfahren", icon: "🧭", color: "#fbbf24", title: "Map of methods", blurb: "Mayring, Kuckartz, Meuser & Nagel, grounded theory … where does each one sit?",
    body: () => `
<div class="md"><p>The map orders methods along two axes: <b>where the categories come from</b> (deductive ↔ inductive) and <b>how deeply you interpret</b> (descriptive content analysis ↔ reconstructive). The colour shows how well jellyqda supports the method. Tap a dot.</p></div>
${vis("karte")}
${box("tip", "💡", "A simplification", "The positions are rough – many methods can be applied more deductively or more inductively. What matters is that you justify your approach and document the steps of the chosen method transparently.")}`,
    quiz: [
      { q: "Which method was developed specifically for expert interviews?", o: ["Narrative analysis", "Analysis after Meuser & Nagel", "Documentary method", "Thematic analysis"], a: 1, ex: "Meuser & Nagel: paraphrase → headings → thematic comparison → conceptualisation → generalisation." },
      { q: "Paraphrase → generalisation → reduction belongs to …", o: ["Mayring’s summarising content analysis", "Grounded theory", "Gläser & Laudel", "Kuckartz’s evaluative QCA"], a: 0, ex: "These are the steps of summarising content analysis – in jellyqda the Mayring table." }
    ] },
  { id: "kategorien", icon: "🌳", color: "#fb923c", title: "Codes, categories & coding guideline", blurb: "What a good category system looks like – and why anchor examples are gold.",
    body: () => `
<div class="md"><p>A <b>code</b> is a label for a passage. Codes together form a <b>category system</b> – in jellyqda a code tree with codes and subcodes, each family in its own colour, connected by a “thread”.</p></div>
${vis("baum")}
<div class="md"><p><b>Coding guideline</b> – the three columns that make every category transparent:</p></div>
<div class="tblwrap"><table class="tbl"><tr><th>Category</th><th>Definition</th><th>Anchor example</th><th>Coding rule</th></tr>
<tr><td><b>Team climate › Support</b></td><td>Statements about concrete help from colleagues</td><td>“In our team everyone helps everyone.” (R3, para. 12)</td><td>Only help actually experienced, not wishes. Wishes → “Need for support”</td></tr></table></div>
<div class="md mt"><p><b>Good categories are …</b></p><ul>
<li><b>distinct</b> – a passage clearly fits one category or the other (if not: sharpen the coding rule),</li>
<li><b>on one level</b> – subcodes of a family are of the same kind (not “Conflicts” next to “Interview 3”),</li>
<li><b>manageable</b> – a few well-defined main categories rather than 200 loose codes,</li>
<li><b>documented</b> – definition and changes are kept in code memos.</li></ul></div>
${box("tip", "💡", "Define units of analysis", "What is the smallest unit you code (word, sentence, unit of meaning)? How much context may you draw on? Decide briefly and state it in your methods section. Segments help in jellyqda: “whole segment” codes one speaker turn at once.")}
${box("jq", "🪼", "In jellyqda", "The book icon at a code opens the coding guideline. Click a coded passage → “As anchor example for …”. Definition and rule appear as a hint above the code while you code.")}`,
    quiz: [
      { q: "Two coders assign the same passage to different categories. What helps most?", o: ["Create more codes", "Sharpen the coding rule and anchor examples", "Ignore the passage", "Only count frequencies"], a: 1, ex: "Coding rules settle borderline cases, anchor examples show the prototype." }
    ] },
  { id: "mayring", icon: "🪜", color: "#c084fc", title: "Summarising after Mayring", blurb: "Paraphrase → generalisation → reduction – click through an example.",
    body: () => `
<div class="md"><p>Summarising content analysis condenses material step by step. Click through the four stages – this is what it later looks like in jellyqda’s <b>Mayring table</b>.</p></div>
${vis("mayring")}
${box("tip", "💡", "Fix the level of abstraction first", "How general should the generalisation be? “Missing mentor” or “need for support”? Set the level before you generalise, and stick to it.")}
${box("warn", "⚠️", "Don’t skip the final check", "At the end, check whether the reduced category system still represents the original material. Clicking a row of the Mayring table jumps to the passage in the document.")}`,
    quiz: [
      { q: "“Would quit without her colleagues” is …", o: ["a paraphrase", "a generalisation", "a category", "an anchor example"], a: 0, ex: "Content briefly in your own words, still close to the individual case – a paraphrase." }
    ] },
  { id: "kuckartz", icon: "⭕", color: "#22d3ee", title: "Kuckartz: 7 phases", blurb: "Content-structuring QCA – around the research question.",
    body: () => `
<div class="md"><p>Content-structuring QCA after Kuckartz & Rädiker is the standard in many theses. The phases circle around the research question – you don’t go round in a rigid loop, you keep coming back to it. Tap a phase.</p></div>
${vis("kreis")}
${box("jq", "🪼", "Case-based summaries", "Kuckartz recommends thematic case summaries per category and case. That is exactly what the <b>summary grid</b> (code × document) in jellyqda is for.")}`,
    quiz: [
      { q: "Where do subcategories typically emerge in Kuckartz’s approach?", o: ["In advance from theory", "Inductively from the material after the first coding cycle", "From word frequencies", "Only when writing up"], a: 1, ex: "Phase 4: subcategories are built inductively from the already roughly coded material." }
    ] },
  { id: "guete", icon: "✅", color: "#4ade80", title: "Quality criteria & reflexivity", blurb: "How qualitative research convinces – without fetishising reliability coefficients.",
    body: () => `
<div class="md"><p>Qualitative research has its own quality criteria. Frequently cited are the core criteria after <b>Steinke</b>:</p><ul>
<li><b>Intersubjective comprehensibility</b> – document the process, disclose rules, interpret in groups.</li>
<li><b>Indication</b> – do question, method and analysis fit together? (exactly what the compass checks)</li>
<li><b>Empirical grounding</b> – back up claims with passages.</li>
<li><b>Limitation</b> – name the limits of generalisability.</li>
<li><b>Coherence</b> – don’t smooth over contradictions, work with them.</li>
<li><b>Relevance</b> – what does the study contribute?</li>
<li><b>Reflected subjectivity</b> – your role in the research process.</li></ul></div>
${box("tip", "💡", "Consensual coding", "Two people code the same interviews, discuss the differences and sharpen the coding rules. The conversation about disagreements is often worth more than an agreement score.")}
${box("warn", "⚠️", "Intercoder agreement", "jellyqda currently does not compute agreement coefficients. If your supervisor requires a value: export the codings as a table and compare them elsewhere – or agree with your supervisor whether consensual coding is enough.")}
${box("jq", "🪼", "Documentation for free", "Every action is in the audit trail with a timestamp: <code>qda_export(\"audit\")</code>. Codebook, coding guideline and memos go into the report – ideal for appendix and methods section.")}`,
    quiz: [
      { q: "Which criterion checks whether research question, method and analysis fit together?", o: ["Relevance", "Indication", "Limitation", "Coherence"], a: 1, ex: "Indication of the research process: is the approach appropriate to the subject?" }
    ] },
  { id: "ethik", icon: "🔒", color: "#f87171", title: "Transcription, data protection & ethics", blurb: "Consent, pseudonymisation and a transcript format jellyqda understands.",
    body: () => `
<div class="md"><p>Interview data are personal and often sensitive. Three things should be settled before analysis starts:</p><ol>
<li><b>Informed consent</b> – purpose, storage, deletion, right to withdraw; documented in writing.</li>
<li><b>Pseudonymisation</b> – replace names, places, companies, rare positions. Be especially thorough with experts: small fields make people recognisable.</li>
<li><b>Secure storage</b> – raw data separate from the key list, no upload to cloud services without an agreement.</li></ol></div>
<div class="md"><p><b>Transcript format</b> from which jellyqda builds segments by speaker turn:</p></div>
${vis("transkript")}
${box("tip", "💡", "Fix transcription rules", "Simple or detailed transcript? Smooth out dialect? Note pauses? Fix the rules in advance (e.g. after Dresing & Pehl) and state them in the methods section. Reconstructive methods need more detail than a content analysis.")}
${box("jq", "🪼", "Why jellyqda helps here", "Fully offline: no cloud, no uploads, the app only runs on your computer. A project is one file; backups go outside the project folder. Interview data don’t belong in Git – the bundled <code>.gitignore</code> excludes them.")}`,
    quiz: [
      { q: "What needs especially thorough pseudonymisation in expert interviews?", o: ["Only the name", "Name, organisation, position and recognisable anecdotes", "Nothing, experts speak publicly", "Only the timestamps"], a: 1, ex: "In small fields, the position alone often identifies a person." }
    ] }
];

/* ---------- 3. jellyqda step by step ---------- */
const TOUR = [
  { t: "Install", tag: "start", img: [], txt: "You need R 4.0 or later, ideally with RStudio (both free). Then one single line in the R console – the script installs everything, checks the installation and tells you what to do next.",
    r: 'source("https://raw.githubusercontent.com/thedivingshellyfish/jellyqda/main/install_jellyqda.R")',
    tips: ["On Linux, PDF/Word import needs system libraries once – the script names the right command."] },
  { t: "Create a project & start the app", tag: "start", img: [["01-uebersicht.png", "The interface: documents, code system, document browser, memos"]], txt: "A project is one single file (<code>*.jellyqda</code>). Every action is saved immediately.",
    r: 'library(jellyqda)\nqda_open("my-thesis.jellyqda")  # create or reopen\nqda_app(lang = "en")              # start the app in the browser',
    tips: ["To try it without your own data: the example interview in the package or the fictitious transcripts in the <code>demo/</code> folder."] },
  { t: "Import transcripts & variables", tag: "beide", img: [["03-dokumente-import.png", "Import by dialog or drag and drop"]], txt: "Import on the left under <b>Documents</b> (.txt, .md, .docx, .pdf). The text is “frozen” at import – markings never drift. You need variables such as role, sector or age group later for case comparison.",
    r: 'qda_import(c("interview_01.docx", "interview_02.docx"), segments = "speaker")\nqda_source_set_var(1, "Role", "Project lead")',
    tips: ["Set variables right at import – adding them later for 20 interviews is tedious.", "Pseudonymise <b>before</b> importing: the text is deliberately unchangeable afterwards."] },
  { t: "Check segments", tag: "beide", img: [["09-segmentleiste.png", "Split and merge segments"]], txt: "Segments are the basic units of your text: by paragraphs or by speaker turns (<code>[00:01:12] R: …</code>). Splitting and merging takes one click into the text.",
    r: 'qda_segments_set(1, "speaker")   # change the rule for document 1', tips: ["Open interviews: rather paragraphs. Semi-structured interviews: speaker turns."] },
  { t: "Build the code system", tag: "de", img: [["05-codesystem.png", "Code tree with codes, subcodes and thread"]], txt: "In the <b>Code System</b>, create main categories with “+ Code” and below them “+ Subcode”. Double-click renames, the colour dot colours the whole family. With a deductive approach this is where your category system from theory or guide takes shape.",
    r: 'qda_code_add("Team climate")\nqda_code_add("Support", parent = "Team climate")\nqda_code_set_color("Team climate", "#009E73")', tips: ["With an inductive approach you start almost empty – codes emerge while reading."] },
  { t: "Code", tag: "beide", img: [["06-markieren-aktionsleiste.png", "Mark text → coding bar"], ["08-coding-leiste.png", "Click a coding: recode, comment, Mayring fields"]], txt: "Mark text, click a code, done. With the keyboard: <b>Ctrl+1…9</b> picks the code, then <b>1…9</b> the subcode. Clicking an existing coding opens the coding bar: recode, comment, paraphrase, anchor example.",
    r: 'qda_code(source = 1, segment = 3, code = "Support")             # whole segment\nqda_code(source = 1, start = 120, end = 340, code = "Team climate") # character range', tips: ["Overlapping codings are grey with a number – hovering shows all of them."] },
  { t: "Write memos", tag: "beide", img: [["10-memos.png", "Four kinds of memos, with filter and search"]], txt: "Four kinds: passage (<b>Ctrl+M</b>), document (e.g. your postscript), code (definition, coding rule) and project (e.g. “My prior knowledge”, method decisions).",
    r: 'qda_memo_add("Postscript: relaxed atmosphere, R3 seemed pressed for time", source = 1, title = "Postscript")\nqda_memo_add("Only code explicit statements", code = "Support", title = "Coding rule")', tips: ["Memos are your research diary – gold for the methods section later."] },
  { t: "Coding guideline", tag: "de", img: [["26-kodierleitfaden.png", "Definition, anchor examples, coding rule"]], txt: "Hover over a code → <b>book icon</b>. Definition, anchor examples (one per line) and coding rule. Take anchor examples straight from the text: click a coding → “As anchor example for …”.",
    r: 'qda_code_guide("Support",\n  definition = "Concrete help from colleagues, actually experienced",\n  rule = "Only experienced help; wishes -> Need for support")', tips: ["After the trial run (10–50 % of the material), revise the guideline – the audit trail documents the change."] },
  { t: "Condense inductively", tag: "in", img: [["27-codes-zusammenfuehren.png", "Merge codes"]], txt: "<b>In vivo</b> in the coding bar turns the marked text itself into a code. Later: rename, move under another code as a subcode, merge similar codes (arrow icon). Everything reversible with Ctrl+Z.",
    r: 'qda_code_move("missing mentor", parent = "Need for support")\nqda_code_merge("nobody to ask", into = "missing mentor")', tips: ["Condense regularly – tidy up after every second or third interview."] },
  { t: "Code search hits", tag: "de", img: [["28-auto-codieren.png", "Code all hits at once"]], txt: "Search at the bottom centre, then “Code all N hits with …” – just the word or the whole segment. One Ctrl+Z takes them all back.",
    r: 'qda_autocode("colleague", code = "Team climate", scope = "segment")', tips: ["Don’t trust it blindly: review the hits via the code afterwards and delete what doesn’t fit. Auto-coding doesn’t replace reading."] },
  { t: "Mayring table", tag: "in", img: [["32-mayring.png", "Paraphrase and generalisation for all codings"]], txt: "<b>Analysis → Summary (Mayring)</b>: all codings with their passage and one field each for paraphrase and generalisation. Saved when you leave a field; exportable as CSV for Excel.",
    r: 'qda_coding_set_summary(12, paraphrase = "Would quit without her colleagues",\n                       generalization = "Team as a reason to stay")', tips: ["Paraphrases also appear in the report’s margin column next to the interview."] },
  { t: "Compare & summarise cases", tag: "beide", img: [["29-fallvergleich.png", "Case comparison in the code matrix"], ["16-summary-grid.png", "Summary grid: one summary per code and document"]], txt: "<b>Code matrix</b> (codes × documents); under “Columns” a case comparison by variable, e.g. role. The <b>summary grid</b> holds thematic summaries per code and case – ideal for Kuckartz and Flick.",
    r: 'qda_matrix()\nqda_case_matrix("Role")\nqda_summary_set("Team climate", 1, "R1 experiences the team as a key resource …")', tips: ["Matrix numbers show where to read more closely – not what “holds true”."] },
  { t: "Word frequencies & keyword in context", tag: "in", img: [["30-worthaeufigkeiten.png", "Most frequent words, without filler words"], ["31-stichwort-im-kontext.png", "Keyword in context (KWIC)"]], txt: "<b>Analysis → Word frequencies</b> (also within one code only) and <b>Keyword in context</b>: every occurrence of a term with the text to its left and right. One click jumps to the passage.",
    r: 'qda_words(n = 30, code = "Motivation")\nqda_kwic("family")', tips: ["Good for discovering field terms and cross-checking – not a substitute for coding."] },
  { t: "Report & export", tag: "beide", img: [["33-bericht-randspalte-a4.png", "Report with margin column, print-ready on A4"]], txt: "<b>Report</b> opens a new tab, print-ready on A4: code system with frequencies, codebook, memos, coded passages and all interviews with a margin column. The <b>Export</b> menu gives CSV, Excel and Word.",
    r: 'qda_export("all")       # CSV/Excel/Word/HTML into exports/\nqda_export("codebook")  # codebook for the appendix', tips: ["Codebook and coding guideline in the appendix – that ticks several quality criteria at once."] },
  { t: "Undo, backup & audit trail", tag: "start", img: [["17-rueckgaengig.png", "Undo and redo for everything"]], txt: "<b>Ctrl+Z / Ctrl+Y</b> for everything. Backups automatically every 25 actions and on click, as a ZIP outside the project folder. The audit trail records every action with a timestamp.",
    r: 'qda_backup()\nqda_export("audit")   # audit trail for the methods section', tips: ["Before big changes (merging, auto-coding) quickly press Ctrl+S – it creates a restore point."] }
];

/* ---------- 4. Checklists, glossary, literature ---------- */
const CHECK = [
  { id: "vor", t: "Before data collection", em: "📝", items: ["Research question(s) written down precisely", "Interview type chosen with reasons (compass!)", "Sampling: who, how many, why? Access sorted", "Guide developed (SPSS principle) and piloted", "Consent form and information sheet prepared", "Recorder tested, spare battery packed", "Postscript template ready", "Prior knowledge noted (becomes a project memo)"] },
  { id: "trans", t: "Transcription", em: "⌨️", items: ["Transcription rules fixed and noted", "Consistent speaker labels (I, R1, R2 …)", "Timestamps as [hh:mm:ss] at the start of each turn", "Names, places, organisations pseudonymised", "Key list stored separately and securely", "Transcript proofread against the audio"] },
  { id: "ana", t: "Analysis in jellyqda", em: "🪼", items: ["Project created, transcripts imported", "Document variables (role, group …) set", "Postscripts added as document memos", "Units of analysis defined", "Category system documented with a coding guideline", "Trial coding done and guideline revised", "Method decisions recorded in project memos", "Material fully coded (progress: qda_stats())", "Backup in a second place"] },
  { id: "bericht", t: "Report & methods section", em: "📄", items: ["Procedure described step by step (method + source)", "Origin of categories disclosed (deductive/inductive)", "Codebook and coding guideline in the appendix", "Findings backed by quotes (interview, paragraph/timestamp)", "Frequencies interpreted with care", "Limitations of the study named", "Own role reflected"] }
];
const GLOSS = [
  ["Abduction", "Inference from a surprising finding to a new explanatory hypothesis, which is then checked against the material."],
  ["Anchor example", "Typical passage that shows a category prototypically – part of the coding guideline."],
  ["Audit trail", "Record of all analysis steps with timestamps. In jellyqda: qda_export(\"audit\")."],
  ["Axial coding", "Grounded theory: working out relations between categories around an axis category."],
  ["Case comparison", "Comparing code frequencies or content between groups of cases, e.g. by role. In jellyqda in the code matrix."],
  ["Category", "Concept bundling several passages under a shared aspect. Often used synonymously with code."],
  ["Code", "Label for a passage. In jellyqda: codes and subcodes in the code tree."],
  ["Coding", "One concrete assignment of a code to a passage."],
  ["Coding guideline", "Table with definition, anchor example and coding rule per category (German: Kodierleitfaden)."],
  ["Coding rule", "Rule for deciding borderline cases between categories."],
  ["Deductive", "Categories are derived in advance from theory, literature or the guide and applied to the material."],
  ["Generalisation", "Mayring: lifting a paraphrase to a fixed level of abstraction."],
  ["Grounded theory", "Research style in which theory is developed from the data through constant comparison (Glaser & Strauss)."],
  ["In-vivo code", "Code whose name is a term used by the interviewees themselves."],
  ["Inductive", "Categories emerge step by step from the material."],
  ["Intercoder agreement", "Measure of how similarly two people code. Alternative: consensual coding with discussion of disagreements."],
  ["Interpretive knowledge", "Subjective relevances, views and interpretations of experts – the subject of the theory-generating expert interview."],
  ["KWIC", "Keyword in context: every occurrence of a word with its surrounding text."],
  ["Memo", "Note on a passage, document, code or project; records ideas and decisions."],
  ["Narrative prompt", "Open question meant to trigger a narrative (“Please tell me about …”)."],
  ["Paraphrase", "The content of a passage briefly in your own words."],
  ["Pilot interview", "Test interview to try out the guide and narrative prompts."],
  ["Postscript", "Notes right after the interview on atmosphere, anything striking and non-verbal aspects."],
  ["Probing", "PCI: general probing (deepen narratives) and specific probing (mirroring, comprehension questions, confrontation)."],
  ["Pseudonymisation", "Replacing identifying details with placeholders; the key is kept separately."],
  ["Reconstructive", "Methods that work out implicit structures of meaning sequentially (e.g. narrative analysis, documentary method)."],
  ["Reduction", "Mayring: deleting generalisations that mean the same and bundling similar ones into categories."],
  ["Saturation", "The point at which new cases bring no new insights for the categories."],
  ["Segment", "In jellyqda: basic unit of a document, by paragraphs or speaker turns."],
  ["Sensitising concept", "Prior knowledge that guides attention without fixing the view (Blumer)."],
  ["SPSS principle", "Guide development after Helfferich: collect, check, sort, subsume (German: Sammeln, Prüfen, Sortieren, Subsumieren)."],
  ["Summary grid", "Table code × document with thematic summaries."],
  ["Theoretical sampling", "Grounded theory: choosing further cases based on the state of the emerging theory."],
  ["Triangulation", "Combining several data sources, methods or perspectives."]
];
const LIT = {
  mayring: "Mayring, P. (2014). <i>Qualitative content analysis: Theoretical foundation, basic procedures and software solution</i>. Klagenfurt (open access, SSOAR).",
  kuckartz: "Kuckartz, U. & Rädiker, S. (2023). <i>Qualitative content analysis: Methods, practice and software</i> (2nd ed.). Sage.",
  witzel: "Witzel, A. & Reiter, H. (2012). <i>The problem-centred interview</i>. Sage.",
  bogner: "Bogner, A., Littig, B. & Menz, W. (Eds.) (2009). <i>Interviewing experts</i>. Palgrave Macmillan.",
  meuser: "Meuser, M. & Nagel, U. (2009). The expert interview and changes in knowledge production. In A. Bogner, B. Littig & W. Menz (Eds.), <i>Interviewing experts</i> (pp. 17–42). Palgrave Macmillan.",
  glaeser: "Gläser, J. & Laudel, G. (2013). Life with and without coding: Two methods for early-stage data analysis in qualitative research aiming at causal explanations. <i>Forum Qualitative Social Research, 14</i>(2), Art. 5.",
  helfferich: "Helfferich, C. (2011). <i>Die Qualität qualitativer Daten</i> (4th ed.). VS Verlag. (German; source of the SPSS principle)",
  brinkmann: "Brinkmann, S. & Kvale, S. (2015). <i>InterViews: Learning the craft of qualitative research interviewing</i> (3rd ed.). Sage.",
  schuetze: "Schütze, F. (1983). Biographieforschung und narratives Interview. <i>Neue Praxis, 13</i>(3), 283–293. (German original of the narrative interview)",
  flick: "Flick, U. (2018). <i>An introduction to qualitative research</i> (6th ed.). Sage. (episodic interview, thematic coding)",
  merton: "Merton, R. K. & Kendall, P. L. (1946). The focused interview. <i>American Journal of Sociology, 51</i>(6), 541–557.",
  strauss: "Corbin, J. & Strauss, A. (2015). <i>Basics of qualitative research</i> (4th ed.). Sage.",
  charmaz: "Charmaz, K. (2014). <i>Constructing grounded theory</i> (2nd ed.). Sage.",
  braun: "Braun, V. & Clarke, V. (2006). Using thematic analysis in psychology. <i>Qualitative Research in Psychology, 3</i>(2), 77–101.",
  bohnsack: "Bohnsack, R., Pfaff, N. & Weller, W. (Eds.) (2010). <i>Qualitative analysis and documentary method in international educational research</i>. Barbara Budrich.",
  krueger: "Krueger, R. A. & Casey, M. A. (2015). <i>Focus groups: A practical guide for applied research</i> (5th ed.). Sage.",
  steinke: "Steinke, I. (2004). Quality criteria in qualitative research. In U. Flick, E. von Kardorff & I. Steinke (Eds.), <i>A companion to qualitative research</i> (pp. 184–190). Sage.",
  dresing: "Dresing, T. & Pehl, T. (2015). <i>Manual (on) transcription: Transcription conventions, software guides and practical hints for qualitative researchers</i> (3rd English ed.). Marburg."
};
const IVLIT = { pzi: ["witzel"], exp_theo: ["bogner", "meuser"], exp_sys: ["bogner", "glaeser"], exp_expl: ["bogner"], narrativ: ["schuetze"], episodisch: ["flick"], fokussiert: ["merton"], leitfaden: ["helfferich", "brinkmann"], gruppe: ["bohnsack", "krueger"] };

/* ---------- 5. Interface: texts, diagram labels, plan ---------- */
const IMG = "../img/";
const UI = {
  lang: "en", other: { href: "../de/assistenz/", label: "DE", title: "Deutsche Version" },
  title: "jellyqda Assistant", tagline: "Qualitative research – step by step",
  tabs: ["Home", "Compass", "Basics", "jellyqda", "More"],
  fit: ["rather not", "possible", "good fit"], rec: "recommended", toGoal: "matches your aim",
  sup: ["support only", "partly", "well supported"], supPre: "jellyqda: ",
  back: "Back", next: "Next", copy: "Copy", copied: "Copied ✓", themeToggle: "Switch light/dark", textLabel: "Text",
  shotMissing: "Screenshot appears on the project website",
  steps: ["Aim", "Interview", "Openness", "Logic", "Method", "Roadmap"],
  komp: {
    title: "Research compass", sub: "Five steps to a coherent approach", showPlan: "Show roadmap",
    q: {
      zi: ["What do you want to find out?", "Pick what comes closest to your research interest. It’s only a starting point – you can change everything later."],
      iv: ["What kind of interview are you conducting?", "Tap a type to learn more.", 'Marked <span class="fit r">recommended</span>: what fits your aim.'],
      st: ["How open is your interview?", "Rated for: "],
      lg: ["Where do your categories come from?", "The analysis logic. Rated by interview type and openness."],
      pr: ["Which method will you use for analysis?", "Sorted by fit with your choices."]
    }
  },
  det: { ivFor: "Obvious interview types", lgFor: "Obvious logic", after: "after", wissen: "What kind of knowledge?", ablauf: "Procedure", achten: "Watch out for",
    ausw: "What this means for the analysis", next: "Next step", nextSt: "Choose the degree of structure. For this type:", beispiel: "Example question",
    seg: "Segments in jellyqda", wann: "When it makes sense", risiko: "Watch out for", tools: "Matching jellyqda tools", steps: "Steps", injq: "In jellyqda" },
  plan: {
    notAll: "Please complete all steps first.", title: "Your roadmap", stimmig: "coherent",
    verdict: ["Something grinds here: look at the red parts of the thread and consider whether another combination fits better.", "Coherent overall – justify your choice at the yellow points in your methods section.", "Interview type, openness, logic and method mesh well."],
    pdf: "Save as PDF (A4)", restart: "Start again", pdfHint: "In the print dialog, choose “Save as PDF”. The layout is prepared for A4.",
    faden: "The thread of your decisions", fadenLegend: 'The line between two points shows how well they fit: <span class="fit g">good</span> <span class="fit o">justify</span> <span class="fit b">reconsider</span>',
    nodes: ["Aim", "Interview type", "Openness", "Analysis logic", "Method"], change: "change",
    goalOk: "Fits your aim.", goalNo: "Not the most obvious type for your aim – justify your choice.",
    achten: "⚠️ What to watch out for", sup0: (n) => "jellyqda supports " + n + " only as a tool for marking and note-taking – the sequential interpretation happens outside, ideally in an interpretation group.",
    stepsT: "🪜 Steps: ", jq: "🪼 Your path in jellyqda", allSteps: "All functions step by step with screenshots →",
    method: "✍️ Building block for your methods section", methodNote: "A starting point, not a finished text. Replace placeholders in [square brackets] and back them up with sources.",
    lit: "📚 Further reading", litNote: "Please check editions before citing.",
    printTitle: "Research roadmap", printMade: "Created with the jellyqda Assistant on ", printUrl: "thedivingshellyfish.github.io/jellyqda/assistant/"
  },
  home: {
    progress: "done", heroDone: "Your roadmap is ready 🎉", heroNew: "Where are you right now?",
    heroText: "The compass guides you from your research question via the interview type to a fitting analysis method – and shows what that means in jellyqda.",
    kpi: ["Basics", "jellyqda steps", "Checklists"], start: " Start the compass", cont: " Continue the compass", seePlan: " View roadmap",
    startWith: "Where would you like to start?",
    tiles: [["Research compass", "Interview type, openness, logic, method – with a fit check and a roadmap as A4 PDF."], ["Basics", "Inductive & deductive, Mayring, Kuckartz, quality criteria – with diagrams and mini quizzes."], ["jellyqda step by step", "From installation to the A4 report – with screenshots and R code."], ["Checklists", "Before data collection, transcription, analysis, methods section."]],
    faq: "Popular questions",
    faqs: [["#/basics/logik", "🔁", "Inductive or deductive – what suits me?", "with an interactive diagram"], ["#/basics/interviews", "🎙️", "Open, semi-open, guide-based – what’s the difference?", "interview types at a glance"], ["#/basics/verfahren", "🧭", "Mayring, Kuckartz or Meuser & Nagel?", "map of methods"], ["#/basics/mayring", "🪜", "How does paraphrase → generalisation → reduction work?", "click through"], ["#/more/glossar", "🔤", "What does … actually mean?", " terms in the glossary"]]
  },
  foot: 'jellyqda is free (MIT) and runs fully offline · <a href="../">Project website</a> · <a href="https://github.com/thedivingshellyfish/jellyqda">GitHub</a> · <a href="https://github.com/thedivingshellyfish/jellyqda/blob/main/docs/wiki/Home.md">Wiki</a> · <a href="#/more/set">Privacy</a>',
  basics: { title: "Basics", read: (a, b) => a + " of " + b + " read", quiz: "Quiz", quizT: "🎯 Quick check", right: "Correct! ", wrong: "Not quite. ", mark: " Mark as read", isRead: " Read", good: "Well done ✓", crumb: "Basics" },
  tour: { title: "jellyqda step by step", done: (a, b) => a + " of " + b + " done", step: "Step", asR: "The same as R code:", tip: "Tip", isDone: " Done", doneNext: " Done & next",
    more: 'In full detail: <a href="https://github.com/thedivingshellyfish/jellyqda/blob/main/docs/wiki/Home.md">Wiki</a> · <a href="../dev/reference/">R reference</a>',
    tags: { start: ["n", "Basics"], beide: ["mix", "inductive & deductive"], de: ["de", "rather deductive"], in: ["in", "rather inductive"] } },
  more: { title: "More", sub: "Checklists, glossary, literature, privacy & settings", tabs: [["check", "Checklists"], ["glossar", "Glossary"], ["lit", "Literature"], ["set", "Data & settings"]],
    search: "Search a term …", noHit: "No match.", litHint: "A selection to get started. Please check editions before citing.",
    theme: "Appearance", themeSub: "Light, dark or like your system", themes: [["auto", "Auto"], ["light", "Light"], ["dark", "Dark"]],
    wipe: "Delete stored data", wipeSub: "Remove compass choices, quiz answers, checklists and completed steps from this browser", wipeBtn: " Delete",
    wipeQ: "Really delete all data this page has stored in your browser?", wiped: "Deleted",
    privT: "🔒 Where your data is kept",
    priv: "<p>This page <b>sets no cookies</b> and has <b>no tracking</b>. So that your progress is still there next time, it is kept in your <b>browser’s local storage</b> (<code>localStorage</code>) – technically similar to a cookie, but it is never sent to a server.</p><p>Only this is stored: your compass choices, quiz answers, ticked checklists and steps, and the appearance (light/dark). No names, no research data.</p><p>The data stays on this device and in this browser. In a private window it is discarded when you close it. You can delete it at any time below or in your browser settings (“Clear site data”).</p>",
    noStore: "Your browser currently doesn’t allow local storage (e.g. private window). The page still works, but forgets your progress when you close it."
  },
  notice: { t: "No cookies, no tracking.", d: "Your progress is only stored locally in your browser.", ok: "Got it", more: "Learn more" },
  check: { tot: "Checklists" }
};

const VISTX = {
  quali: { head: ["", "qualitative", "quantitative"], rows: [["Aim", "understand, reconstruct", "measure, explain, test"], ["Data", "texts, images, observations", "numbers, standardised answers"], ["Sample", "small, purposively chosen", "large, ideally random"], ["Procedure", "open, circular", "standardised, linear"], ["Generalisation", "to theory / types", "to a population"]] },
  logik: { layers: [["Theory & prior knowledge", "literature, interview guide"], ["Categories", "codes & subcodes"], ["Material", "transcripts, notes"]],
    l: { ableiten: "derive", anwenden: "apply", buendeln: "bundle", verall: "generalise", haupt: ["main", "categories"], sub: ["sub-", "categories"], schaerfen: "sharpen", ab1: "surprise → hypothesis", ab2: "check against material" },
    aria: "Diagram ",
    txt: { de: "<b>Deductive:</b> theory provides the categories, you apply them to the material with a coding guideline.", in: "<b>Inductive:</b> passages become codes, codes become categories, categories become concepts.", mix: "<b>Deductive-inductive:</b> main categories come from theory or the guide (blue), subcategories emerge from the material (violet).", ab: "<b>Abductive:</b> a surprising finding calls for a new explanation, which you check against the material – a cycle." } },
  spek: { axis: ["open", "semi-open", "structured"], cap: "Dot = typical degree of structure, dashed = usual range.", wissen: "Knowledge:", take: " Use in the compass" },
  karte: { aria: "Map of analysis methods", x: ["◀ deductive", "inductive ▶"], y: ["descriptive ▶", "◀ reconstructive"], cap: "Tap a dot to see the method." },
  prozess: { P: [["Research question & prior knowledge", "sharpen the question, disclose prior knowledge", "Project memo"], ["Sampling & access", "who, how many, why?", ""], ["Guide & pilot", "SPSS principle, test interview", ""], ["Data collection", "interview + postscript", "Document memo"],
      ["Transcription", "rules, pseudonymisation, timestamps", ""], ["Import & segments", "freeze text, variables", "Import"], ["Coding & categories", "deductive / inductive", "Code tree, coding guideline"], ["Interpreting", "memos, summaries", "Memos, Mayring, summary grid"],
      ["Cross-case analysis", "comparisons, patterns, types", "Matrix, case comparison, KWIC"], ["Report & methods section", "evidence, documentation", "Report, audit trail, codebook"]],
    loop: "↻ In grounded theory, data collection and analysis alternate (theoretical sampling)." },
  baum: { T: [["#E69F00", "Career path", 12, [["SME", 7], ["Corporation", 4]]], ["#009E73", "Team climate", 18, [["Support", 11], ["Conflicts", 5]]], ["#CC79A7", "Motivation", 9, [["intrinsic", 6], ["extrinsic", 3]]]],
    cap: "This is how the code tree looks in jellyqda: main code fully coloured, subcodes framed on the coloured thread. Σ counts codings including subcodes." },
  mayring: { D: [["“Well, I spent five years in this small firm, you just had to do everything, from bookkeeping to talking to clients.”", "Five years in a small firm, had to take on every task", "Broad range of tasks in an SME", 0],
      ["“What I really missed was someone you could just ask, like a mentor or something.”", "Missed a contact person/mentor", "Lack of support through mentoring", 1],
      ["“In our team everyone helps everyone, that’s really what keeps me here.”", "Mutual help in the team keeps her in the job", "Team as a reason to stay", 2],
      ["“Honestly, without my colleagues I’d have left long ago.”", "Would quit without her colleagues", "Team as a reason to stay", 2]],
    K: [["Variety of tasks in SMEs", "#E69F00"], ["Need for support", "#56B4E9"], ["Team as a reason to stay", "#009E73"]],
    L: ["Original", "Paraphrase", "Generalisation", "Reduction"], th: ["Passage", "Paraphrase", "Generalisation", "Category"],
    cap: ["Four passages from a (fictitious) interview.", "Z1 paraphrase: content briefly in your own words, without embellishment.", "Z2 generalisation: lift to a consistent level of abstraction. The last two passages become identical!", "Z3/Z4 reduction: delete what means the same, bundle what is similar – four passages become three categories. In jellyqda: these are your codes."] },
  kreis: { P: [["Initial work with the text", "Read, highlight important passages, write memos and first case summaries.", "Memos, document memos"], ["Develop main categories", "Usually from research question, theory and guide.", "+ Code, coding guideline"], ["First coding cycle", "Code all material with the main categories.", "Coding bar, Ctrl+1…9"],
      ["Build subcategories inductively", "Compile all passages of a main category and build subcategories from the material.", "Codings of a code, + Subcode, in vivo"], ["Second coding cycle", "Code the material again with the refined system.", "Recode in the coding bar"],
      ["Simple & complex analyses", "Category-based, case-based, relations, case comparisons.", "Matrix, case comparison, summary grid"], ["Write up & document", "Present results, make the procedure transparent.", "Report, codebook, audit trail"]],
    center: ["Research", "question(s)"], phase: "Phase ", aria: "Seven phases after Kuckartz" },
  transkript: '<div class="transcript">' +
    '<div><span class="ts">[00:01:12]</span> <span class="sp">I:</span> Could you tell me how you came to <span class="ps">[Company A]</span>?</div>' +
    '<div><span class="ts">[00:01:20]</span> <span class="sp">R3:</span> Yes, well (.) it was pure chance really. <span class="pa">(laughs)</span> I studied in <span class="ps">[City B]</span> and …</div>' +
    '<div><span class="ts">[00:02:47]</span> <span class="sp">I:</span> And how was it in the team at the beginning?</div></div>' +
    '<div class="cap"><span style="color:var(--accent2)">■</span> timestamp &nbsp; <span style="color:var(--accent)">■</span> speaker label – from these jellyqda builds one segment per turn with <code>segments = "speaker"</code>. &nbsp; <span style="color:var(--warn)">■</span> pseudonym in square brackets.</div>'
};

function PRWHY(sel, p) {
  const out = [];
  if (sel.lg) {
    const v = PR[p].lg[sel.lg], n = LG[sel.lg].name.toLowerCase();
    out.push(v === 2 ? "Fits your " + n + " logic." : v === 1 ? "Can be applied in a " + n + " way, but that isn’t the core of the method." : "Works differently from your chosen logic (" + LG[sel.lg].name + ").");
  }
  if (sel.iv) {
    const iv = IV[sel.iv];
    out.push(iv.good.includes(p) ? "Often used with the " + iv.name.toLowerCase() + "." : iv.ok.includes(p) ? "Possible with the " + iv.name.toLowerCase() + " – justify the choice in your methods section." : "Rather unusual for the " + iv.name.toLowerCase() + ".");
  }
  return out.join(" ");
}

function PLAN(sel) {
  const st = ST[sel.st], L = [];
  L.push({ t: "Create the project & record prior knowledge", d: "Before you code: a project memo “My prior knowledge & assumptions”. It is the basis for reflected subjectivity.", r: 'library(jellyqda)\nqda_open("my-thesis.jellyqda")\nqda_memo_add("Prior knowledge: …", title = "My prior knowledge")' });
  L.push({ t: "Import transcripts", d: "Segments by " + (st.segmode === "speaker" ? "speaker turn" : "paragraph") + ". Set variables (e.g. role) right away; postscripts as document memos.", r: 'qda_import(c("interview_01.docx", "interview_02.docx"), segments = "' + st.segmode + '")\nqda_source_set_var(1, "Role", "…")' });
  if (sel.lg === "de") {
    L.push({ t: "Set up the category system from theory", d: "Main categories and, if needed, values as subcodes. A residual category “Other” for the unexpected.", r: 'qda_code_add("Category A")\nqda_code_add("Value 1", parent = "Category A")\nqda_code_add("Other")' });
    L.push({ t: "Write the coding guideline", d: "Definition, anchor example and coding rule for each category (book icon).", r: 'qda_code_guide("Category A", definition = "…", rule = "…")' });
    L.push({ t: "Trial run & revision", d: "Code 10–50 % of the material, sharpen categories and rules. Justify changes in a code memo." });
    L.push({ t: "Main run", d: "Code everything. Use search-hit coding only with a review afterwards." });
  } else if (sel.lg === "in") {
    L.push({ t: "Initial work with the text", d: "Read the first interview slowly, note anything striking as a passage memo (Ctrl+M)." });
    L.push({ t: "Code openly", d: "Name things close to the text, in vivo is welcome. Don’t organise too early." });
    if (["mayring_z", "meuser", "glaeser"].includes(sel.pr)) L.push({ t: "Paraphrase & generalise", d: "Analysis → Summary (Mayring): paraphrase and generalisation per coding.", r: 'qda_coding_set_summary(1, paraphrase = "…", generalization = "…")' });
    L.push({ t: "Condense", d: "After every second or third interview: rename, move as a subcode, merge. Code memos with definitions.", r: 'qda_code_move("Code", parent = "Parent category")\nqda_code_merge("Old code", into = "New code")' });
    L.push({ t: "Cross-check with word lists", d: "Word frequencies and keyword in context reveal field terms and connections.", r: 'qda_words(n = 30)\nqda_kwic("term")' });
  } else if (sel.lg === "mix") {
    L.push({ t: "Create main categories", d: "From research question and guide – deductive. Note in the code memo: “defined in advance”.", r: 'qda_code_add("Topic from guide block 1")\nqda_code_add("Topic from guide block 2")' });
    L.push({ t: "First coding cycle", d: "Code all material roughly with the main categories (Ctrl+1…9)." });
    L.push({ t: "Build subcategories from the material", d: "Review the codings of a main category, build subcodes (in vivo, + Subcode). In the code memo: “built inductively”." });
    L.push({ t: "Coding guideline & second cycle", d: "Guideline for the final system, then recode in the coding bar.", r: 'qda_code_guide("Subcategory", definition = "…", rule = "…")\nqda_coding_recode(12, "Subcategory")' });
  } else {
    L.push({ t: "Mark sequences", d: "Use codes as bookmarks (e.g. “Narration”, “Argumentation”, “Opening passage”) – not as results." });
    L.push({ t: "Interpret in memos", d: "Each interpretation as a passage memo right at the sequence." });
    L.push({ t: "Prepare the interpretation group", d: "Print the report with margin column (A4) – numbers in the text, memos in the margin." });
  }
  if (["kuckartz_s", "flick", "kuckartz_t"].includes(sel.pr)) L.push({ t: "Case summaries", d: "Summary grid: one thematic summary per category and case.", r: 'qda_summary_set("Main category", 1, "…")' });
  L.push({ t: "Cross-case analysis", d: "Code matrix, case comparison by variables, collect quotes.", r: 'qda_matrix()\nqda_case_matrix("Role")\nqda_segments("Category A")' });
  L.push({ t: "Document", d: "Report, codebook and audit trail for appendix and methods section; backup in a second place.", r: 'qda_export("all")\nqda_export("audit")\nqda_backup()' });
  return L;
}

function METHOD(sel) {
  const iv = IV[sel.iv], st = ST[sel.st], pr = PR[sel.pr];
  const lgTxt = { de: "deductively; categories were derived in advance from [theory/literature] and recorded in a coding guideline with definitions, anchor examples and coding rules", in: "inductively; categories were developed step by step from the material and condensed regularly", mix: "deductively-inductively; main categories were derived from [the interview guide/theory], subcategories were built inductively from the material", ab: "reconstructively; the interviews were interpreted sequentially, codes served to structure the material" }[sel.lg];
  return "Data were collected in [N] interviews, conducted in the format “" + iv.name + "” (after " + iv.by + "). " +
    "The interviews were " + st.name.toLowerCase().replace(" (", ", ").replace(")", "") + " and lasted between [x] and [y] minutes. " +
    "They were recorded, transcribed following [transcription rules] and pseudonymised. " +
    "The analysis was carried out " + lgTxt + ", following " + pr.name + " (" + pr.by + "). " +
    "Coding was computer-assisted with the R package jellyqda (version 0.7.0). Coding guideline, memos and a complete audit trail of the analysis are documented in the appendix.";
}
