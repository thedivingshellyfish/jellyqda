-- jellyqda web wiki: pandoc filter (dev/wiki/build_wiki.sh)
-- * links to wiki pages:  Page.md(#anchor)      -> Page.html(#anchor)
-- * links to repository files above the wiki (../../demo/x.R, ../../../demo/x.R)
--   -> the file on GitHub
-- * screenshots: .../screenshots/...          -> .../img/... (where the site keeps them)
-- Applies to markdown links/images and to raw HTML (<img src>, <a href>).
local REPO = "https://github.com/thedivingshellyfish/jellyqda/blob/main/"

local function fix_url(u)
  if u:match("^%a[%w+.-]*:") or u:match("^#") then return u end   -- http:, mailto:, #anchor
  local page, anchor = u:match("^([^#]*)%.md(#?.*)$")
  if page then return page .. ".html" .. anchor end
  if u:match("screenshots/") then return (u:gsub("screenshots/", "img/")) end
  if u:match("^%.%./") then return REPO .. (u:gsub("^[%./]+", "")) end
  return u
end

local function fix_html(s)
  s = s:gsub('(src=")([^"]*)(")', function(a, u, b) return a .. fix_url(u) .. b end)
  s = s:gsub('(href=")([^"]*)(")', function(a, u, b) return a .. fix_url(u) .. b end)
  return s
end

function Link(el) el.target = fix_url(el.target); return el end
function Image(el) el.src = fix_url(el.src); return el end
function RawInline(el) if el.format == "html" then el.text = fix_html(el.text) end; return el end
function RawBlock(el) if el.format == "html" then el.text = fix_html(el.text) end; return el end

-- page title (for <title>) from the first level-1 heading
function Pandoc(doc)
  if not doc.meta.pagetitle then
    for _, b in ipairs(doc.blocks) do
      if b.t == "Header" and b.level == 1 then doc.meta.pagetitle = pandoc.utils.stringify(b.content); break end
    end
  end
  return doc
end
