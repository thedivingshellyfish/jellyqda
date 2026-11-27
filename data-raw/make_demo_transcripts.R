# Generates the demo transcripts in demo/ --------------------------------------
#
# DEMO FILES: the four transcripts are FICTIONAL. They belong to an invented
# study ("Working in small software companies") and were assembled by this
# script from hand-written sentences. All persons, companies, places and
# events are invented; any resemblance to real persons is coincidental.
#
# Output (English, about 10 / 30 / 60 / 120 minutes of talk):
#   demo/demo_interview_10min.txt   P01 "Alex",  junior developer
#   demo/demo_interview_30min.txt   P02 "Bea",   UX designer, part-time
#   demo/demo_interview_60min.txt   P03 "Chris", co-founder and CTO
#   demo/demo_interview_120min.txt  P04 "Dana",  support lead, career changer
#
# Format as in many real transcripts: a header, then one line per speaker
# turn "[hh:mm:ss] I: ..." / "[hh:mm:ss] P: ...", fillers ("um", "you
# know"), the odd "(inaudible)" line. Good for trying import, segments by
# speaker turns, coding, word frequencies and keyword in context.
#
# Deterministic (set.seed). Run once from the package root:
#   Rscript data-raw/make_demo_transcripts.R

source(file.path("data-raw", "transcript_generator.R"))   # make_transcript()

specs <- list(
  list(10,  "DEMO_INT_010", "P01 \"Alex\"",  "junior developer",              101),
  list(30,  "DEMO_INT_030", "P02 \"Bea\"",   "UX designer, part-time",        102),
  list(60,  "DEMO_INT_060", "P03 \"Chris\"", "co-founder and CTO",            103),
  list(120, "DEMO_INT_120", "P04 \"Dana\"",  "support lead, career changer",  104))
for (s in specs) {
  out <- file.path("demo", sprintf("demo_interview_%dmin.txt", s[[1]]))
  writeLines(make_transcript(s[[1]], s[[2]], s[[3]], s[[4]], s[[5]]), out, useBytes = TRUE)
  cat(out, file.info(out)$size, "bytes\n")
}
