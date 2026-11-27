#!/usr/bin/env bash
# Build the web wiki: docs/wiki/*.md -> HTML pages in the style of the website.
#   bash dev/wiki/build_wiki.sh <wiki source dir> <output dir>
#   e.g. bash dev/wiki/build_wiki.sh docs/wiki site/wiki
# English pages: Home + every page linked in _Sidebar.md; German pages: de/*.md.
# Needs pandoc (>= 2.11). Used by .github/workflows/website.yml; the site has
# the website at /, the wiki at /wiki/ (German at /wiki/de/), the screenshots
# at /img/ and the pkgdown reference at /dev/.
set -euo pipefail
SRC=${1:-docs/wiki}
OUT=${2:-site/wiki}
HERE=$(cd "$(dirname "$0")" && pwd)

build_lang () {   # $1 source dir, $2 output dir, $3 lang, $4 path to site root
  local src=$1 out=$2 lang=$3 root=$4
  mkdir -p "$out"
  local wikilabel reflabel themelabel langdir pages
  if [ "$lang" = de ]; then
    wikilabel="Wiki"; reflabel="R-Funktionen"; themelabel="Hell oder dunkel"; langdir="de/"
    pages=$(cd "$src" && ls *.md | grep -v '^_')
  else
    wikilabel="Wiki"; reflabel="R functions"; themelabel="Light or dark"; langdir=""
    pages=$( (echo Home.md; grep -o '([A-Za-z0-9-]*\.md)' "$src/_Sidebar.md" | tr -d '()') | sort -u)
  fi
  # sidebar and footer are inserted from files after pandoc (not passed as
  # command-line variables: their umlauts would depend on the system locale)
  local tmp; tmp=$(mktemp -d)
  pandoc -f gfm -t html5 --lua-filter "$HERE/links.lua" -o "$tmp/sidebar.html" "$src/_Sidebar.md"
  pandoc -f gfm -t html5 --lua-filter "$HERE/links.lua" -o "$tmp/footer.html" "$src/_Footer.md"
  for p in $pages; do
    [ -f "$src/$p" ] || continue
    pandoc -f gfm -t html5 --template "$HERE/template.html" --lua-filter "$HERE/links.lua" \
      -V lang="$lang" -V assets="$root" -V langdir="$langdir" -V wikihome="Home.html" \
      -V wikilabel="$wikilabel" -V reflabel="$reflabel" -V themelabel="$themelabel" \
      -o "$tmp/page.html" "$src/$p"
    awk -v sb="$tmp/sidebar.html" -v ft="$tmp/footer.html" '
      $0 == "@@SIDEBAR@@" { while ((getline l < sb) > 0) print l; close(sb); next }
      $0 == "@@FOOTER@@"  { while ((getline l < ft) > 0) print l; close(ft); next }
      { print }' "$tmp/page.html" > "$out/${p%.md}.html"
  done
  rm -rf "$tmp"
  cp "$out/Home.html" "$out/index.html"
  echo "wiki ($lang): $(ls "$out"/*.html | wc -l) pages -> $out"
}

build_lang "$SRC" "$OUT" en "../"
build_lang "$SRC/de" "$OUT/de" de "../../"
