# jellyqda :: stopwords.R -- stop-word lists for qda_words() (R/analysis.R)
# German and English stop words plus typical transcript fillers ("aeh",
# "um", "you know"). Kept short and readable on purpose; users add their own
# words with qda_words(stopwords = c(...)). Words are compared in lower case.

# German stop words + transcript fillers (+ a few English ones). Kept short
# and readable on purpose; extend with qda_words(stopwords = c(...)).
.STOPWORDS_DE <- c(
  "aber", "alle", "allem", "allen", "aller", "alles", "als", "also", "am", "an", "ander", "andere",
  "anderen", "auch", "auf", "aus", "bei", "beim", "bin", "bis", "bist", "da", "dabei", "dadurch",
  "dafuer", "daher", "damit", "dann", "daran", "darauf", "darin", "darueber", "das", "dass",
  "dazu", "dein", "dem", "den", "denn", "der", "des", "deshalb", "dessen", "die", "dies", "diese",
  "diesem", "diesen", "dieser", "dieses", "doch", "dort", "du", "durch", "ein", "eine", "einem",
  "einen", "einer", "eines", "einfach", "einmal", "er", "es", "etwa", "etwas", "euch", "fuer",
  "ganz", "gar", "gibt", "gehabt", "gewesen", "habe", "haben", "hat", "hatte", "hatten", "hier",
  "hin", "hinter", "ich", "ihm", "ihn", "ihnen", "ihr", "ihre", "im", "immer", "in", "ins", "ist",
  "ja", "jede", "jedem", "jeden", "jeder", "jetzt", "kann", "kein", "keine", "koennen", "man",
  "mal", "mehr", "mein", "meine", "mich", "mir", "mit", "muss", "nach", "nein", "nicht", "nichts",
  "noch", "nun", "nur", "ob", "oder", "ohne", "schon", "sehr", "sein", "seine", "sich", "sie",
  "sind", "so", "solche", "sondern", "sonst", "ueber", "um", "und", "uns", "unser", "unter",
  "viel", "vom", "von", "vor", "war", "waren", "was", "weil", "weiter", "welche", "wenn", "wer",
  "werde", "werden", "wie", "wieder", "wir", "wird", "wo", "wohl", "wurde", "wurden", "zu", "zum",
  "zur", "zwar", "zwischen",
  # umlaut spellings of the words above
  "f\u00fcr", "dar\u00fcber", "daf\u00fcr", "\u00fcber", "k\u00f6nnen", "m\u00fcssen", "w\u00fcrde", "w\u00e4re",
  # filler words in transcripts
  "\u00e4h", "\u00e4hm", "aeh", "aehm", "hm", "hmm", "mhm", "mmh", "mmmh", "naja", "na", "okay", "ok",
  "genau", "quasi", "irgendwie", "tja", "eben", "halt",
  # a few English words (the full English list is .STOPWORDS_EN below)
  "the", "and", "that", "this", "with", "for", "you", "are", "was", "not", "but", "have")

# English stop words + transcript fillers. Short and readable on purpose.
.STOPWORDS_EN <- c(
  "a", "about", "above", "after", "again", "against", "all", "also", "am", "an", "and", "any",
  "are", "as", "at", "be", "because", "been", "before", "being", "below", "between", "both",
  "but", "by", "can", "could", "did", "do", "does", "doing", "done", "down", "during", "each",
  "even", "every", "few", "for", "from", "further", "get", "got", "had", "has", "have", "having",
  "he", "her", "here", "hers", "herself", "him", "himself", "his", "how", "i", "if", "in", "into",
  "is", "it", "its", "itself", "just", "let", "like", "me", "more", "most", "much", "my", "myself",
  "no", "nor", "not", "now", "of", "off", "on", "once", "one", "only", "or", "other", "our",
  "ours", "ourselves", "out", "over", "own", "quite", "really", "same", "she", "should", "so",
  "some", "still", "such", "than", "that", "the", "their", "theirs", "them", "themselves",
  "then", "there", "these", "they", "this", "those", "through", "to", "too", "under", "until",
  "up", "us", "very", "was", "we", "were", "what", "when", "where", "which", "while", "who",
  "whom", "why", "will", "with", "would", "you", "your", "yours", "yourself", "yourselves",
  # contractions
  "i'm", "it's", "don't", "didn't", "doesn't", "isn't", "wasn't", "can't", "won't", "that's",
  "there's", "i've", "i'd", "i'll", "we're", "they're", "you're",
  # filler words in transcripts
  "um", "uh", "erm", "hm", "hmm", "mhm", "yeah", "yes", "okay", "ok", "well", "sort", "kind",
  "mean", "know", "actually", "basically", "honestly", "right", "thing", "things")
