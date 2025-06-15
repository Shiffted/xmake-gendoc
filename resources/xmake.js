function locationHashChanged(e) {
    var tocbody = document.getElementById("toc-body")
    if (tocbody) {
        var tocLinks = tocbody.getElementsByTagName("a")
        for (let i = 0; i < tocLinks.length; i++) {
            if (tocLinks[i].href == window.location.href) {
                tocLinks[i].style = "font-weight:bold"
                tocLinks[i].parentElement.style = "background-color:#d6ffed"
            } else {
                tocLinks[i].style = ""
                tocLinks[i].parentElement.style = ""
            }
        }
    }
    var navLinks = document.getElementById("sidebar-nav").getElementsByTagName("a")
    for (let i = 0; i < navLinks.length; i++) {
        const urlbase = window.location.href.split('#')
        if (navLinks[i].href == urlbase[0] || navLinks[i].href == window.location.href) {
            navLinks[i].style = "font-weight:bold"
            navLinks[i].parentElement.style = "background-color:#d6ffed"
        } else {
            navLinks[i].style = ""
            navLinks[i].parentElement.style = ""
        }
    }
}
window.onhashchange = locationHashChanged;
locationHashChanged({})
