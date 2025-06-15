(() => {
    const DOM = {
        sidebar: document.querySelector('#sidebar'),
        sidebarNav: document.querySelector('#sidebar .sidebar-nav'),
        toc: document.querySelector('#toc'),
        tocNav: document.querySelector('#toc .toc-nav')
    };

    const mqXl = window.matchMedia('(min-width: 1200px)');

    function updateActiveSidebarLink() {
        if (!DOM.sidebarNav) return;

        const newActive = DOM.sidebarNav.querySelector(`a[href="${window.location.href.split('#')[0]}"]`);
        if (newActive) {
            newActive.classList.add('target');
        }
    }

    function updateActiveTocLink() {
        if (!DOM.tocNav) return;

        const currentActive = DOM.tocNav.querySelector('.target');
        currentActive?.classList.remove('target');

        const newActive = DOM.tocNav.querySelector(`a[href="${window.location.hash}"]`);
        newActive?.classList.add('target');
    }

    function updateTocPosition() {
        if (!DOM.sidebar || !DOM.toc || !DOM.sidebarNav || !DOM.tocNav) return;

        if (mqXl.matches) {
            if (DOM.tocNav.parentElement !== DOM.toc) {
                DOM.toc.appendChild(DOM.tocNav);
            }
        } else {
            if (DOM.tocNav.parentElement !== DOM.sidebar) {
                DOM.sidebar.insertBefore(DOM.tocNav, DOM.sidebarNav);
            }
        }
    }

    function init() {
        if (!document.body) {
            console.error('Initialization failed: <body> element not found.');
            return;
        }

        updateActiveSidebarLink();
        updateActiveTocLink();
        updateTocPosition();

        window.addEventListener('hashchange', updateActiveTocLink);
        mqXl.addEventListener('change', updateTocPosition);
    }

    init();
})();
