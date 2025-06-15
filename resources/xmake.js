(() => {
    const DOM = {
        sidebarToggle: document.querySelector('#sidebar-toggle'),
        sidebar: document.querySelector('#sidebar'),
        sidebarNav: document.querySelector('#sidebar .sidebar-nav'),
        toc: document.querySelector('#toc'),
        tocNav: document.querySelector('#toc .toc-nav')
    };

    const mqMedium = window.matchMedia('(min-width: 769px)');
    const mqXl = window.matchMedia('(min-width: 1200px)');

    function toggleSidebar() {
        document.body.classList.toggle('toggled');
        const isExpanded = DOM.sidebarToggle.getAttribute('aria-expanded') === 'true';
        DOM.sidebarToggle.setAttribute('aria-expanded', !isExpanded);
    }

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

    function updateAriaToggleState() {
        if (!DOM.sidebarToggle) return;

        document.body.classList.remove('toggled');
        if (mqMedium.matches) {
            DOM.sidebarToggle.setAttribute('aria-expanded', 'true');
        } else {
            DOM.sidebarToggle.setAttribute('aria-expanded', 'false');
        }
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
        updateAriaToggleState();
        updateTocPosition();

        DOM.sidebarToggle?.addEventListener('click', toggleSidebar);
        window.addEventListener('hashchange', updateActiveTocLink);
        mqMedium.addEventListener('change', updateAriaToggleState);
        mqXl.addEventListener('change', updateTocPosition);
    }

    init();
})();
