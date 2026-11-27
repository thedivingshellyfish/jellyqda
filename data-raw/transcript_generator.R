# Generator for fictional English interview transcripts (DEMO DATA).
#
# Defines make_transcript(minutes, id, pseudonym, role, seed): returns the
# lines of a FICTIONAL transcript of an invented study ("Working in small
# software companies"), assembled from hand-written sentences. All persons,
# companies and events are invented.
# Used by data-raw/make_demo_transcripts.R (the files in demo/) and by the
# stress test dev/stress_test.R (many transcripts of different lengths).

topics <- list(
  career = list(
    q = c("How did you end up in your current job?",
          "What did you do before you joined the company?",
          "Looking back, what was the turning point in your career?",
          "Why did you choose a small company?"),
    a = c("After my studies I worked for a large corporation for two years, and it felt anonymous.",
          "I applied to the company because a former colleague recommended it.",
          "My first job was in a call centre, which taught me a lot about patience.",
          "In a small company I could take on responsibility much earlier than my friends in big firms.",
          "The switch was risky, the salary was lower at first.",
          "I never planned a career in software, it just happened.",
          "My parents expected me to become a teacher, so the decision took some courage.",
          "I learned most things on the job, not at university.",
          "After two years I was offered the role of team lead.",
          "I still remember the job interview, it was in the kitchen because there was no meeting room.",
          "In the corporation every decision went through three levels of management.",
          "Here I can see what difference my work makes.")),
  motivation = list(
    q = c("What motivates you at work?",
          "What do you enjoy most about your work?",
          "Can you remember a moment when you were proud of your work?",
          "What keeps you going on difficult days?"),
    a = c("I like solving tricky problems, it feels good when something finally works.",
          "What matters most to me is that people actually use what we build.",
          "When a customer writes that our tool saved them an hour a day, that makes my week.",
          "I enjoy learning something new almost every week.",
          "The freedom to decide how I work is important to me.",
          "Honestly, the money is not the main reason, otherwise I would have stayed in the corporation.",
          "I am proud of the release last spring, we finished it as a team.",
          "On difficult days I think about the users we are working for.",
          "I like that my ideas are taken seriously, even as a junior.",
          "Mentoring new colleagues gives me a lot of energy.")),
  team = list(
    q = c("How would you describe the climate in your team?",
          "How do you work together in the team?",
          "Was there ever a conflict in the team?",
          "How are new colleagues welcomed?"),
    a = c("We are a close team, people help each other without being asked.",
          "In our retrospectives we speak openly about mistakes.",
          "There was a conflict about responsibilities last year, it took weeks to settle.",
          "New colleagues get a buddy for the first month.",
          "Trust is the most important thing in our team.",
          "We have lunch together on Fridays, that helps a lot.",
          "Sometimes the discussions are loud, but nobody holds a grudge.",
          "When two people left at the same time the mood was tense for a while.",
          "I can ask anyone for help, including the founders.",
          "Remote work made it harder to notice when someone was struggling.",
          "We celebrate small successes, for example with cake.")),
  workload = list(
    q = c("How do you experience the workload?",
          "How do you deal with pressure?",
          "Do you manage to switch off after work?",
          "What happens before a release?"),
    a = c("Before a release I often work late into the evening.",
          "I switch off my work phone at six, I had to learn that.",
          "Sometimes I still think about tickets at the weekend.",
          "When several projects start at once I sleep badly.",
          "Our manager tries to protect us from too many meetings.",
          "The workload comes in waves, quiet weeks and very busy weeks.",
          "Working part-time helps me, but the meetings do not get fewer.",
          "I once got close to burning out, after that I changed a lot.",
          "Clear priorities help me more than overtime.",
          "In a small company there is no one else who can take over.")),
  customers = list(
    q = c("How much contact do you have with customers?",
          "How do you get feedback from users?",
          "Can you tell me about a difficult customer situation?"),
    a = c("I talk to customers every week, the direct feedback is valuable even when it is uncomfortable.",
          "We run user tests with nurses and care staff, that grounds me.",
          "Customer contact mostly goes through the project lead, so I rarely see the users.",
          "Once a customer called on a Sunday because the system was down.",
          "Some customers expect us to answer within minutes.",
          "When users struggle with our software, it hurts a bit, but it helps us improve.",
          "Most feature ideas come directly from support tickets.",
          "I like visiting customers on site, you see things you never see in the office.")),
  future = list(
    q = c("Where do you see yourself in five years?",
          "What would you change in the company if you could?",
          "Is there anything you would like to add?"),
    a = c("I would like to stay, as long as the company stays this small.",
          "Maybe I will start my own business one day.",
          "I would introduce fixed focus times without meetings.",
          "I hope we can grow without losing our culture.",
          "I would like to do more mentoring in the future.",
          "Better pay for support staff would be my first change.",
          "Nothing to add, thank you, it was good to talk about it."))
)
fillers <- c("um,", "you know,", "honestly,", "well,", "I mean,", "to be fair,", "hm,", "so,")
tails <- c("", "", "", " (laughs)", " Yeah.", " That was quite something.", " I think.")
probes <- c("Can you give me an example?", "How did that feel?", "Mhm.", "What happened then?",
            "Could you say a bit more about that?", "I see.", "And how did your colleagues react?")

make_transcript <- function(minutes, id, pseudonym, role, seed) {
  set.seed(seed)
  header <- c(
    "DEMO TRANSCRIPT - FICTIONAL. Written for jellyqda (tests and demos).",
    "All persons, companies, places and events are invented; any resemblance is coincidental.",
    "Study:        Working in small software companies (fictional demo study)",
    sprintf("Interview:    %s", id),
    sprintf("Pseudonym:    %s (fictional), %s", pseudonym, role),
    sprintf("Duration:     %02d:%02d h (approx.)", minutes %/% 60, minutes %% 60),
    "Format:       full transcript, time stamp at every speaker turn",
    "Speakers:     I = interviewer, P = participant",
    "------------------------------------------------------------",
    "")
  t <- 0; lines <- character(); order <- names(topics)
  limit <- minutes * 60
  say <- function(sentences) {
    s <- sentences
    for (k in seq_along(s)) if (runif(1) < 0.25) {
      first <- sub(" .*", "", s[k])           # keep "I", lower-case other first words
      body <- if (first %in% c("I", "I'm")) s[k] else paste0(tolower(substr(s[k], 1, 1)), substr(s[k], 2, nchar(s[k])))
      f <- sample(fillers, 1)
      s[k] <- paste0(toupper(substr(f, 1, 1)), substr(f, 2, nchar(f)), " ", body)
    }
    paste0(paste(s, collapse = " "), sample(tails, 1))
  }
  stamp <- function() sprintf("[%02d:%02d:%02d]", t %/% 3600, (t %/% 60) %% 60, t %% 60)
  add <- function(who, text) {
    lines <<- c(lines, sprintf("%s %s: %s", stamp(), who, text))
    words <- length(strsplit(text, " ")[[1]])
    t <<- t + max(3, round(words / 2.4)) + sample(1:4, 1)
  }
  add("I", "Thank you for taking part. As agreed, I will record the conversation. Shall we start?")
  add("P", "Yes, sure, go ahead.")
  i <- 0
  while (t < limit) {
    topic <- topics[[order[(i %% length(order)) + 1]]]; i <- i + 1
    add("I", sample(topic$q, 1))
    for (r in seq_len(sample(1:3, 1))) {
      if (t >= limit) break
      n <- sample(2:min(7, length(topic$a)), 1)
      add("P", say(sample(topic$a, n)))
      if (runif(1) < 0.08) lines <- c(lines, "(inaudible)")
      if (r < 3 && runif(1) < 0.5) add("I", sample(probes, 1))
    }
  }
  add("I", "Thank you very much, that was very helpful.")
  c(header, lines, "END OF DEMO TRANSCRIPT")
}

