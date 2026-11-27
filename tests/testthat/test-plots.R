# SVG graphics (R/plot_svg.R, R/plot_cooccurrence.R, R/plot_network.R,
# R/plot_portrait.R)

svg_of <- function(x) as.character(x)

test_that("heatmap: cells, numbers, tooltips, click attributes", {
  viz_setup(); on.exit(qda_close(), add = TRUE)
  viz_code("A1", 2); viz_code("B", 2); viz_code("A1", 3); viz_code("B", 3); viz_code("C", 4)
  h <- svg_of(qda_plot_cooccurrence())
  expect_true(grepl("^<svg class=\"jqv\"", h))
  expect_true(grepl('data-a="B" data-b="A / A1"', h, fixed = TRUE))
  expect_true(grepl(">2</text>", h, fixed = TRUE))
  expect_true(grepl("<title>", h, fixed = TRUE))
  expect_true(grepl("class=\"q7\"", h, fixed = TRUE))       # the maximum is the darkest step
  hj <- svg_of(qda_plot_cooccurrence(measure = "jaccard"))
  expect_true(grepl(">1.00<|>.67<|>1<", hj))
  f <- tempfile(fileext = ".svg")
  expect_equal(qda_plot_cooccurrence(file = f), f)
  expect_true(grepl("<svg", paste(readLines(f), collapse = "")))
  expect_true(inherits(qda_plot_cooccurrence(), "html"))
})

test_that("network: one circle per code, one line per pair, layouts", {
  viz_setup(); on.exit(qda_close(), add = TRUE)
  viz_code("A1", 2); viz_code("B", 2); viz_code("B", 3); viz_code("C", 3); viz_code("C", 4); viz_code("A1", 4)
  n <- svg_of(qda_plot_network())
  expect_equal(lengths(regmatches(n, gregexpr("<circle", n))), 3L)
  expect_equal(lengths(regmatches(n, gregexpr("<line", n))), 3L)
  nf <- svg_of(qda_plot_network(layout = "force"))
  expect_equal(lengths(regmatches(nf, gregexpr("<circle", nf))), 3L)
  n2 <- svg_of(qda_plot_network(min_n = 2))
  expect_equal(lengths(regmatches(n2, gregexpr("<line", n2))), 0L)
  pos <- jellyqda:::.net_layout(5, data.frame(a = 1:4, b = 2:5, w = 1:4), "force")
  expect_true(all(pos >= 0 & pos <= 1))
})

test_that("portrait strips: one row per document, blocks jump to the passage", {
  viz_setup(); on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  viz_code("A1", 2); viz_code("B", 2)
  p <- svg_of(qda_plot_portrait())
  expect_true(grepl("interview_01.txt", p, fixed = TRUE))
  expect_true(grepl('data-jump="1" data-src="1"', p, fixed = TRUE))
  expect_true(grepl('class="none"', p, fixed = TRUE))       # uncoded segments
  expect_true(grepl("#0072B2", p, fixed = TRUE))
})

test_that("too few codes / no data give a short note, not an error", {
  new_project(); on.exit(qda_close(), add = TRUE)
  expect_true(grepl("Zu wenige Codes", svg_of(qda_plot_cooccurrence())))
  expect_true(grepl("Zu wenige Codes", svg_of(qda_plot_network())))
  expect_true(grepl("Keine Dokumente", svg_of(qda_plot_portrait())))
})

test_that("labels are escaped", {
  viz_setup(); on.exit(qda_close(), add = TRUE)
  qda_code_add("<b>&\"x\"")
  viz_code("<b>&\"x\"", 2); viz_code("B", 2)
  h <- svg_of(qda_plot_cooccurrence())
  expect_false(grepl("<b>&", h, fixed = TRUE))
  expect_true(grepl("&lt;b&gt;&amp;", h, fixed = TRUE))
})
