# Generates inst/extdata/survey_demo.csv ---------------------------------------
#
# DEMO FILE: a FICTIONAL online survey ("Studying and stress", invented for
# jellyqda's survey import). All respondents and answers are invented. The
# layout is that of a typical export (SoSci Survey, LimeSurvey, Qualtrics):
# one row per respondent, an id, a time stamp, closed questions and open
# questions with the question text as column name.
#   Rscript data-raw/make_survey_demo.R

set.seed(42)
n <- 12
motivation <- c("I always liked solving puzzles, and computer science felt like that.",
                "My parents are nurses; I wanted to do something with people as well.",
                "Honestly, I did not know what else to study. It turned out well.",
                "I want to work on climate questions, and this field gives me the tools.",
                "A teacher at school encouraged me. Without her I would not be here.",
                "The job prospects are good, and I need a secure income.",
                "I volunteered in a hospital and knew this was my place.",
                "I like being outdoors; field work was the deciding point.")
stress <- c("Exams all in the same two weeks, and no time to recover in between.",
            "Working 15 hours a week next to my studies. Some weeks it is too much.",
            "Group work where not everyone does their part.",
            "Feeling that everyone else understands the material faster than me.",
            "Deadlines for three projects at once at the end of the semester.",
            "Finding an affordable room; I commute two hours a day.",
            "Presentations in front of the whole year group.",
            "Not knowing whether I will find a job afterwards.",
            "Night shifts during the practical phase, then lectures in the morning.")
help <- c("More time between exams.", "Recorded lectures, so I can catch up after work.",
          "A contact person who actually answers emails.", "Quiet places to study on campus.",
          "Clear criteria for group work grades.", "Financial support that does not depend on my parents' income.",
          "Mentoring by students from higher semesters.", "Fewer but more meaningful assignments.")
pick <- function(v) sample(v, 1)
rows <- lapply(seq_len(n), function(i) {
  data.frame(
    respondent = sprintf("DEMO_%02d", i),
    submitted = format(as.POSIXct("2027-01-10 09:00", tz = "UTC") + i * 3517, "%Y-%m-%d %H:%M"),
    age_group = sample(c("18-21", "22-25", "26+"), 1),
    field_of_study = sample(c("Computer science", "Nursing", "Environmental science"), 1),
    semester = as.character(sample(1:8, 1)),
    `Why did you choose your field of study?` = pick(motivation),
    `What causes you stress during your studies?` = if (i == 4) paste(pick(stress), "And:", pick(stress), sep = "\n") else pick(stress),
    `What would help you most?` = if (i %in% c(6, 9)) "" else pick(help),
    `Satisfaction with your studies (1-5)` = as.character(sample(1:5, 1)),
    check.names = FALSE, stringsAsFactors = FALSE)
})
df <- do.call(rbind, rows)
df[11, 6:8] <- ""                       # one respondent left all open questions empty
readr::write_csv(df, "inst/extdata/survey_demo.csv")
cat("inst/extdata/survey_demo.csv:", nrow(df), "rows\n")
