(() => {
    const DOM = {
        sidebarNav: document.querySelector('#sidebar .sidebar-nav'),
        tocNav: document.querySelector('#toc .toc-nav')
    };

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

    function init() {
        if (!document.body) {
            console.error('Initialization failed: <body> element not found.');
            return;
        }

        updateActiveSidebarLink();
        updateActiveTocLink();

        window.addEventListener('hashchange', updateActiveTocLink);
    }

    init();
})();
