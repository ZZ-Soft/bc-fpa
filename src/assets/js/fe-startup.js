// Startup script for the "FE Stylesheet Viewer" control add-in.
// Builds the host DOM, then tells AL we are ready.

(function () {
    'use strict';

    var controlId = document.getElementById('controlAddIn') ? 'controlAddIn' : null;
    var root = controlId ? document.getElementById(controlId) : document.body;

    var wrapper = document.createElement('div');
    wrapper.className = 'fe-wrapper';
    wrapper.innerHTML =
        '<div class="fe-status" id="fe-status">Nessun documento caricato.</div>' +
        '<iframe id="fe-frame" class="fe-frame" title="FatturaPA" sandbox="allow-same-origin allow-modals allow-popups"></iframe>';
    root.appendChild(wrapper);

    // The iframe only becomes visible once something has been rendered into it.
    document.getElementById('fe-frame').style.display = 'none';

    function ready() {
        if (typeof SaxonJS === 'undefined' || typeof window.FE_SEF === 'undefined') {
            document.getElementById('fe-status').textContent =
                'Errore: runtime SaxonJS o foglio di stile compilato non caricati.';
            return;
        }
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlAddInReady', []);
    }

    if (document.readyState === 'complete') {
        ready();
    } else {
        window.addEventListener('load', ready);
    }
})();
