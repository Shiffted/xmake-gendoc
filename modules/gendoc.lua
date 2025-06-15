--!A cross-platform document build utility based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Copyright (C) 2015-present, TBOOX Open Source Group.
--
-- @author      charlesseizilles
-- @file        gendoc.lua
--

-- imports
import("core.base.option")
import("shared.md4c")

function _load_apimetadata(filecontent, opt)
    opt = opt or {}
    local content = {}
    local apimetadata = {}
    local ismeta = false
    for idx, line in ipairs(filecontent:split("\n", {strict = true})) do
        if idx == 1 then
            local _, _, includepath = line:find("${include (.+)}")
            if includepath then
                local apientrydata = io.readfile(path.join(os.projectdir(), "doc", opt.locale, includepath))
                local apimetadata, content = _load_apimetadata(apientrydata, opt)
                return apimetadata, content, includepath
            elseif idx == 1 and line == "---" then
                ismeta = true
            end
        elseif ismeta then
            if line == "---" then
                ismeta = false
            else
                local key, value = line:match("(.+): (.+)")
                apimetadata[key] = value
            end
        else
            table.insert(content, line)
        end
    end
    if apimetadata.api then
        local api = apimetadata.api
        if api ~= "true" and api ~= "false" then
            for idx, line in ipairs(content) do
                if line:startswith("### ") then
                    table.insert(content, idx + 1, "`" .. api .. "`")
                    break
                end
            end
        end
    end
    if apimetadata.version then
        local names = {
            ["en-us"] = "Introduced in version",
            ["zh-cn"] = "被引入的版本"
        }
        local name = names[opt.locale]
        if name then
            table.insert(content, "#### " .. name .. " " .. apimetadata.version)
        end
    end
    if apimetadata.refer then
        local names = {
            ["en-us"] = "See also",
            ["zh-cn"] = "参考"
        }
        local name = names[opt.locale]
        if name then
            table.insert(content, "#### " .. name)
            local refers = {}
            for _, line in ipairs(apimetadata.refer:split(",%s+")) do
                table.insert(refers, "${link " .. line .. "}")
            end
            table.insert(content, table.concat(refers, ", "))
        end
    end
    return apimetadata, table.concat(content, "\n")
end

function _make_db()
    local db = {}
    local docroot = path.join(os.projectdir(), "doc")
    for _, pagefilepath in ipairs(os.files(path.join(os.projectdir(), "doc", "*", "pages.lua"))) do
        local locale = path.basename(path.directory(pagefilepath))
        local localizeddocroot = path.join(docroot, locale)
        db[locale] = io.load(path.join(localizeddocroot, "pages.lua"))
        db[locale].apis = {}
        db[locale].pages = {}
        for _, pagegroup in ipairs(db[locale].categories) do
            for _, page in ipairs(pagegroup.pages) do
                table.insert(db[locale].pages, page)
                for _, apientryfile in ipairs(os.files(path.join(localizeddocroot, page.docdir, "*.md"))) do
                    local apientrydata = io.readfile(apientryfile)
                    local apimetadata, _, includepath = _load_apimetadata(apientrydata, {locale = locale})
                    if apimetadata.key and not includepath then
                        assert(db[locale].apis[apimetadata.key] == nil, "keys must be unique (\"" .. apimetadata.key .. "\" was already inserted) (" .. apientryfile .. ")")
                        db[locale].apis[apimetadata.key] = apimetadata
                        db[locale].apis[apimetadata.key].page = page
                    end
                end
            end
        end
    end
    return db
end

function _join_link(...)
    return table.concat(table.pack(...), "/")
end

function _make_anchor(db, key, locale, siteroot, page, text)
    assert(db and key and locale and siteroot and db[locale])
    if db[locale].apis[key] then
        text = text or db[locale].apis[key].name
        return '<a href="' .. _join_link(siteroot, locale, page) .. '#' .. db[locale].apis[key].key .. '" id="' .. db[locale].apis[key].key .. '">' .. text .. '</a>'
    else
        text = text or key
        return '<s>' .. text .. '</s>'
    end
end

function _make_link(db, key, locale, siteroot, text)
    assert(db and key and locale and siteroot and db[locale])
    if db[locale].apis[key] then
        text = text or db[locale].apis[key].name
        return '<a href="' .. _join_link(siteroot, locale, db[locale].apis[key].page.docdir .. ".html") .. '#' .. db[locale].apis[key].key .. '">' .. text .. '</a>'
    else
        text = text or key
        return '<s>' .. text .. '</s>'
    end
end

function _make_editlink(markdownpath, includepath, locale)
    local siteroot = "https://github.com/xmake-io/xmake-gendoc/edit/main/doc"
    if includepath then
        local pos = markdownpath:find(locale, 1, true)
        if pos then
            markdownpath = _join_link(markdownpath:sub(1, pos - 1), locale, includepath)
        end
    end
    return '<a href="' .. _join_link(siteroot, markdownpath) .. '" target="_blank">edit</a>'
end

function _build_language_selector(db, locale, siteroot, page)
    local languageSelect = [[
<select name="language" onchange='changeLanguage(this, "]] .. locale .. [[");'>
]]
    local odrereddbkeys = table.orderkeys(db)
    for _, localename in ipairs(odrereddbkeys) do
        local dblocaleentry = db[localename]
        local selected = localename == locale and "selected" or ""
        languageSelect = languageSelect .. string.format([[    <option %s value="%s">%s %s</option>
]], selected, localename, dblocaleentry.flag, dblocaleentry.name)
    end
    languageSelect = languageSelect .. [[
</select>
<script>
function changeLanguage(select, currentLang) {
    if(select.value != currentLang) {
        var newUrl = "%s/" + select.value + "/%s";
        var splitUrl = window.location.href.split('#');
        if (splitUrl.length > 1)
            newUrl = newUrl + '#' + splitUrl[splitUrl.length - 1];
        window.location.href = newUrl;
    }
}
</script>
]]
    return string.format(languageSelect, siteroot, page)
end

function _write_head(sitemap, siteroot, title, locale, has_toc)
    local lang_tags = {
        ["en-us"] = "en-US",
        ["zh-cn"] = "zn-CN"
    }

    -- TODO proper page description for each category.
    sitemap:write([[
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html lang="]], lang_tags[locale], [[">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta name="resource-type" content="document">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="A cross-platform build utility based on Lua.">
<link rel="stylesheet" href="]], siteroot, [[/prism.css" type="text/css" media="all">
<link rel="stylesheet" href="]], siteroot, [[/xmake.css" type="text/css" media="all">
<title>]], title, [[</title>
</head>
<body]], has_toc and "" or " class=\"no-toc\"", [[>
]])
end

function _build_api(db, locale, siteroot, page, apimetalist, apientrydata, markdownpath)
    local apimetadata, content, includepath = _load_apimetadata(apientrydata, {locale = locale})
    assert(apimetadata.api ~= nil, "entry api is nil value")
    assert(apimetadata.key ~= nil, "entry key is nil value")
    assert(apimetadata.name ~= nil, "entry name is nil value")
    table.insert(apimetalist, apimetadata)
    vprint("apimetadata", apimetadata)

    -- TODO auto generate links
    -- do not match is_arch before matching os.is_arch
    local orderedapikeys = table.orderkeys(db[locale].apis, function(lhs, rhs) return #lhs > #rhs end)
    local contentlines = content:split("\n", {strict = true})
    for idx, line in ipairs(contentlines) do
        if line:find("^### " .. apimetadata.name .. "$") then
            contentlines[idx] = "### " .. _make_anchor(db, apimetadata.key, locale, siteroot, page)
        else
            -- local lastfoundidx = 1
            -- for _, key in ipairs(orderedapikeys) do
            --     local api = db[locale].apis[key]
            --     local foundstart, foundend, match = line:find(api.name, lastfoundidx, true)
            --     if match then
            --         local linebegin
            --         line:gsub(match, _make_link(db, api.key, locale, siteroot), 1)
            --     end
            -- end
        end
    end
    content = table.concat(contentlines, '\n')

    local htmldata, errors = md4c.md2html(content)
    assert(htmldata, errors)

    -- add edit link
    local editlink = _make_editlink(markdownpath, includepath, locale)
    if editlink then
        htmldata = htmldata .. "\n" .. editlink
    end

    local findstart, findend
    repeat
        local anchor
        findstart, findend, anchor = htmldata:find("%${anchor ([^%s${%}]+)}")
        if findstart == nil then break end

        htmldata = htmldata:gsub("%${anchor [^%s${%}]+}", _make_anchor(db, anchor, locale, siteroot, page), 1)
    until not findstart
    repeat
        local anchor, text
        findstart, findend, anchor, text = htmldata:find("%${anchor ([^%s${%}]+) ([^${%}]+)}")
        if findstart == nil then break end

        htmldata = htmldata:gsub("%${anchor [^%s${%}]+ [^${%}]+}", _make_anchor(db, anchor, locale, siteroot, page, text), 1)
    until not findstart
    repeat
        local link
        findstart, findend, link = htmldata:find("%${link ([^%s${%}]+)}")
        if findstart == nil then break end

        htmldata = htmldata:gsub("%${link [^%s${%}]+}", _make_link(db, link, locale, siteroot), 1)
    until not findstart
    repeat
        local link, text
        findstart, findend, link, text = htmldata:find("%${link ([^%s${%}]+) ([^%{%}]+)}")
        if findstart == nil then break end

        htmldata = htmldata:gsub("%${link [^%s${%}]+ [^%{%}]+}", _make_link(db, link, locale, siteroot, text), 1)
    until not findstart

    return htmldata
end

function _write_header(sitemap, siteroot, db, locale, page)
        local search_placeholder_names = {
        ["en-us"] = "Type to search",
        ["zh-cn"] = "全文搜索在这里"
    }

    sitemap:write([[
<header id="header">
    <h1 class="app-name"><a href="]], siteroot, [[">xmake</a></h1>
    <nav>
        <ul>
            <li><a href="https://xrepo.xmake.io" target="_blank">Xrepo</a></li
            ><li><a href="https://github.com/xmake-io/xmake" target="_blank">Github</a></li>
        </ul>
    </nav>
    <div id="search-container">
        <form role="search" class="search">
            <label for="search-input" class="visually-hidden">Search</label>
            <input id="search-input" type="search" placeholder="]], search_placeholder_names[locale], [[" aria-controls="search-results" name="search" autocomplete="off">
            <div id="search-results"></div>
        </form>
    </div>
    ]], _build_language_selector(db, locale, siteroot, page), [[
</header>
]])
end

function _make_sidebar_nav(db, opt)
    local sidebar_nav = "<nav class=\"sidebar-nav\">"
    for _, category in ipairs(db[opt.locale].categories) do
        sidebar_nav = sidebar_nav .. "<section>\n<p>" .. category.title .. "</p>\n<ul>\n"
        for _, page in ipairs(category.pages) do
            local pagepath = page.docdir
            if pagepath == "." then
                pagepath = page.title
            end
            sidebar_nav = sidebar_nav .. "<li><a href=\"" .. _join_link(opt.siteroot, opt.locale, pagepath) .. ".html\">" .. page.title .. "</a></li>\n"
        end
        sidebar_nav = sidebar_nav .. "</ul>\n</section>\n"
    end
    return sidebar_nav .. "</nav>\n"
end

function _write_sidebar(sitemap, sidebar_nav)
    sitemap:write([[
<button id="sidebar-toggle" aria-controls="sidebar" aria-label="Menu">
    <div class="menu-bars">
        <div class="menu-bar"></div>
        <div class="menu-bar"></div>
        <div class="menu-bar"></div>
    </div>
    <div class="sidebar-toggle-bg"></div>
</button>
<aside id="sidebar">
    ]], sidebar_nav, [[
</aside>
]])
end

function _write_table_of_content(sitemap, db, locale, siteroot, page, apimetalist)
    local names = {
        ["en-us"] = "Interfaces",
        ["zh-cn"] = "接口"
    }
    local interfaces = names[locale]

    sitemap:write([[
<aside id="toc">
    <nav class="toc-nav">
        <p>]], interfaces, [[</p>
        <ul>
]])

    for _, apimetadata in ipairs(apimetalist) do
        if apimetadata.api ~= "false" then
            sitemap:write("            <li><a href=\"#", apimetadata.key, "\">", apimetadata.name, "</a></li>\n")
        end
    end

    sitemap:write([[
        </ul>
    </nav>
</aside>
]])
end

function _write_footer(sitemap, siteroot, locale)
    sitemap:write([[
<script src="]], siteroot, [[/xmake.js"></script>
<script defer src="]], siteroot, [[/prism.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/minisearch@6.3.0/dist/umd/index.min.js"></script>
<script defer src="]], siteroot, '/xmake-search-', locale , [[.js"></script>
</body>
</html>
]])
end

function _build_html_page(docdir, title, db, sidebar_nav, opt)
    opt = opt or {}
    local locale = opt.locale or "en-us"
    local page = docdir .. ".html"
    local isindex = false
    if title == "index" and docdir == "." then
        page = "index.html"
        isindex = true
    end
    local siteroot = opt.siteroot:gsub("\\", "/")
    local outputfiledir = path.join(opt.outputdir or "", locale)
    local outputfile = path.join(outputfiledir, page)
    local sitemap = io.open(outputfile, 'w')
    assert(sitemap, "cannot open file: " .. outputfile)

    _write_head(sitemap, siteroot, title, locale, not isindex)
    _write_header(sitemap, siteroot, db, locale, page)
    _write_sidebar(sitemap, sidebar_nav)

    local docroot = path.join(os.projectdir(), "doc")
    local localeroot = path.join(docroot, locale)
    local files = {}
    for _, file in ipairs(os.files(path.join(localeroot, docdir, "*.md"))) do
        local filename = path.filename(file)
        if not filename:startswith("_") then
            if filename == "0_intro.md" then
                table.insert(files, 1, file)
            else
                table.insert(files, file)
            end
        end
    end
    table.sort(files)

    local html_content = {}
    local apimetalist = {}
    for _, file in ipairs(files) do
        vprint("loading " .. file)
        local apientrydata = io.readfile(file)
        local markdownpath = path.relative(file, docroot)
        table.insert(html_content, "<article>\n")
        table.insert(html_content, _build_api(db, locale, siteroot, page, apimetalist, apientrydata, markdownpath))
        table.insert(html_content, "</article>\n")
    end

    if not isindex then
        _write_table_of_content(sitemap, db, locale, siteroot, page, apimetalist)
    end
    sitemap:write([[
<div class="content">
    <main id="md-content">
        ]], table.concat(html_content), [[
    </main>
</div>
]])

    _write_footer(sitemap, siteroot, locale)
    sitemap:close()
end

function _make_search_array(db, opt)
    local jssearcharray = ""
    local odreredapikeys = table.orderkeys(db[opt.locale].apis)
    local id = 1
    for _, apikey in ipairs(odreredapikeys) do
        local api = db[opt.locale].apis[apikey]
        if api.api ~= "false" then
            jssearcharray = jssearcharray .. "    {id: " .. tostring(id) .. ", key: \"" .. api.key .. "\", name: \"" .. api.name .. "\", url: \"" .. _join_link(opt.siteroot, opt.locale, api.page.docdir) .. ".html\" },\n"
            id = id + 1
        end
    end
    return jssearcharray:gsub("\\", "/")
end

function _write_search_file(db, opt)
    local search_file_path = path.join(opt.outputdir, "xmake-search-" .. opt.locale .. ".js")
    local search_file = io.open(search_file_path, "w")
    assert(search_file, "cannot open file: " .. search_file_path)

    search_file:write([[
const documents = [
]] .. _make_search_array(db, opt) .. [[
]

const miniSearch = new MiniSearch({
  fields: ['key', 'name'],
  storeFields: ['key', 'name', 'url'],
  searchOptions: {
    boost: { name: 2 },
    prefix: true,
    fuzzy: 0.4
  }
})
miniSearch.addAll(documents)

function changeSearch(input) {
  const results = miniSearch.search(input)
  document.querySelector('#search-results').innerHTML = results.map(result => {
    return `
      <li role="option">
        <a href="${result.url}#${result.key}">
          <h2>${result.name}</h2>
        </a>
      </li>
    `;
  }).join('');
}
document.querySelector('#search-input').addEventListener('input', (event) => {
    changeSearch(event.target.value.trim());
});
]])
end

function _build_html_pages(opt)
    opt = opt or {}
    os.tryrm(opt.outputdir)
    local db = _make_db()

    for _, pagefile in ipairs(os.files(path.join(os.projectdir(), "doc", "*", "pages.lua"))) do
        opt.locale = path.basename(path.directory(pagefile))

        _write_search_file(db, opt)

        local sidebar_nav = _make_sidebar_nav(db, opt)
        for _, page in ipairs(db[opt.locale].pages) do
            _build_html_page(page.docdir, page.title, db, sidebar_nav, opt)
        end
    end

    for _, htmlfile in ipairs(os.files(path.join(os.projectdir(), "doc", "*.html"))) do
        os.trycp(htmlfile, opt.outputdir)
        io.gsub(path.join(opt.outputdir, path.filename(htmlfile)), "%${siteroot}", opt.siteroot)
    end

    os.trycp(path.join(os.projectdir(), "resources", "*"), opt.outputdir)

    local sidebar_width = 300
    local toc_width = 210
    local max_content_width = 1000
    local css_vars = {
        ["sidebar-width"] = sidebar_width .. "px",
        ["toc-width"] = toc_width .. "px",
        ["max-content-width"] = max_content_width .. "px",
        ["full-width"] = (sidebar_width + toc_width + max_content_width) .. "px",
    }
    for _, css_file in ipairs(os.files(path.join(os.projectdir(), "resources", "**.css"))) do
        local outputfile = path.join(opt.outputdir, path.relative(css_file, "resources"))
        io.gsub(outputfile, "(var%((.-)%))", function(_, variable)
            return css_vars[variable:trim()]
        end)
    end
end

function main()
    local outputdir = path.absolute(option.get("outputdir"))
    local siteroot = option.get("siteroot")
    if not siteroot:startswith("http") then
        siteroot = "file://" .. path.absolute(siteroot)
    end
    if #siteroot > 1 and siteroot:endswith("/") then
        siteroot = siteroot:sub(1, -2)
    end

    _build_html_pages({outputdir = outputdir, siteroot = siteroot})

    cprint("Generated document: ${bright}%s${clear}", outputdir)
    cprint("Siteroot: ${bright}%s${clear}", siteroot)
end
