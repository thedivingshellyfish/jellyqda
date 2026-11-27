# Look and browser logic of the app (`qda_app()`)

This folder holds everything the browser gets from the app besides the
HTML: the stylesheet (`css/`) and the browser logic (`js/`). Both used to be
one big file each (`jellyqda.css`, `jellyqda.js`); they are now split by
topic into numbered files.

**How the files are loaded:** `.jellyqda_assets()` in `R/app.R` reads all
files of a folder **in name order** and writes them into **one** `<style>`
and **one** `<script>` tag in the `<head>` of the page -- exactly as if it
were one big file. So

- the order of the CSS rules (cascade) is the order of the file numbers,
- a JS function defined in one file can be used in every other file,
- a new file only needs a name with the right number in front
  (e.g. `18-something.js`); nothing has to be registered.

After installation this folder is `app/www/` in the package folder. After
changing CSS or JS: reinstall the package (`devtools::install()`) or run
`devtools::load_all()` and restart R.

## Stylesheet: `css/`

| File | Content |
|------|---------|
| `css/01-layout.css` | Basic layout |
| `css/02-document.css` | Document browser |
| `css/03-action-bar.css` | Action bar and coding bar |
| `css/04-lists.css` | Lists: codes, documents, segments, memos |
| `css/05-toolbar.css` | Toolbar (show/hide panels, dark mode, help, language, quit) |
| `css/06-tables.css` | Tables: code matrix (.mxcell) and summary grid (.sumcell) |
| `css/07-dark-mode.css` | Dark mode |
| `css/08-code-tree.css` | Code tree with subcodes, coding bar, save / report / export |
| `css/09-analysis-tools.css` | Analysis tools (since 0.6.0): coding fields, auto-coding, case comparison |

Notes:

- The order of the rules matters (cascade); please do not reorder rules
  wildly when changing them. `07-dark-mode.css` overrides the colours of
  files 01-06; `08-code-tree.css` has its own dark mode rules at its end.
- Colours: main colour `#2c6fbb` (blue), memo colour `#b58900` (yellow),
  double coding `#d81b60` (pink).

## Browser logic: `js/`

| File | Content |
|------|---------|
| `js/01-helpers.js` | Helper functions |
| `js/02-text-selection.js` | Text selection in the document -> character offsets |
| `js/03-document-clicks.js` | Clicks in the document |
| `js/04-list-clicks.js` | Clicks in lists (documents, codes, codings, variables, search) |
| `js/05-memos.js` | Memos (basic functions; the memo panel itself: section 13) |
| `js/06-shortcuts.js` | Keyboard shortcuts |
| `js/07-drag-drop-codes.js` | Drag & drop: move codes in the code tree (new parent) |
| `js/08-display.js` | Display: show/hide panels, dark mode, zoom, help, quit |
| `js/09-tables.js` | Tables: click a cell -> show segments for (code x document) |
| `js/10-server-messages.js` | Messages from the server (session$sendCustomMessage in R) |
| `js/11-page-load.js` | On page load (as soon as the HTML is complete) |
| `js/12-overlap-popover.js` | Overlapping codings: popover |
| `js/13-memo-panel.js` | Memo panel |
| `js/14-icons.js` | Icons |
| `js/15-code-tree.js` | Code tree (codes + subcodes) and coding bar |
| `js/16-analysis-tools.js` | Analysis tools (since 0.6.0) |
| `js/17-language.js` | Language (EN/DE) |

Principle: the browser does almost nothing by itself. Every action is sent
to the server with

```js
Shiny.setInputValue('<name>', value, {priority: 'event'})
```

and handled there in one of the `R/app_server_*.R` files with

```r
shiny::observeEvent(input$<name>, { ... })
```

`priority: 'event'` makes the same value twice (e.g. the same code button
twice) count as a new event.

All clicks are "delegated" (`$(document).on('click', selector, ...)`), so
that they also work for HTML that Shiny re-renders later via `renderUI`.
jQuery and Shiny are already loaded when the script runs.

Texts shown to the user are written in German as `jqT('...')` /
`jqF('...', args)` and translated via `R/i18n_catalog.R`; a test
(`tests/testthat/test-i18n.R`) checks that every such text in `js/` has an
English translation.
