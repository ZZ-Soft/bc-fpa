// Glue code for the "FE Stylesheet Viewer" control add-in.
// Every function named here matches a `procedure` declared in the controladdin object,
// so it must be a global function (Business Central calls them by name on window).

'use strict';

var FEState = {
    chunks: [],
    lastHtml: ''
};

function feStatusEl() {
    return document.getElementById('fe-status');
}

function feFrameEl() {
    return document.getElementById('fe-frame');
}

function feSetStatus(text, isError) {
    var el = feStatusEl();
    if (!el) { return; }
    el.textContent = text || '';
    el.className = isError ? 'fe-status fe-status-error' : 'fe-status';
    el.style.display = text ? 'block' : 'none';
}

// ---------------------------------------------------------------- add-in API

function ResetBuffer() {
    FEState.chunks = [];
    FEState.lastHtml = '';
    var frame = feFrameEl();
    if (frame) {
        frame.srcdoc = '';
        frame.style.display = 'none';
    }
    feSetStatus('Caricamento del documento in corso…', false);
}

function AppendXmlChunk(chunk) {
    FEState.chunks.push(chunk);
}

function ShowMessage(messageText) {
    var frame = feFrameEl();
    if (frame) { frame.style.display = 'none'; }
    feSetStatus(messageText, false);
}

function RenderDocument(stylesheetKey) {
    var xmlText = FEState.chunks.join('');
    FEState.chunks = [];

    if (!xmlText) {
        feSetStatus('Nessun XML da visualizzare.', true);
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('RenderFailed', ['Buffer XML vuoto.']);
        return;
    }

    var sef = (window.FE_SEF && stylesheetKey) ? window.FE_SEF[stylesheetKey] : null;
    if (!sef) {
        // No stylesheet for this kind of document: show the source rather than a blank page.
        FEState.chunks = [xmlText];
        RenderRawXml();
        return;
    }

    try {
        // Parse first so that a malformed file produces a readable message
        // instead of an opaque SaxonJS failure.
        var parsed = new DOMParser().parseFromString(xmlText, 'application/xml');
        var parseErrors = parsed.getElementsByTagName('parsererror');
        if (parseErrors && parseErrors.length > 0) {
            throw new Error('XML non ben formato: ' + parseErrors[0].textContent.substring(0, 300));
        }

        // sourceText (not sourceNode): SaxonJS parses the string with its own document
        // builder, which avoids any mismatch between the host DOM implementation and the
        // runtime. The DOMParser pass above is only there to produce a readable error.
        var result = SaxonJS.transform({
            stylesheetInternal: sef,
            sourceType: 'xml',
            sourceText: xmlText,
            destination: 'serialized'
        }, 'sync');

        var html = result.principalResult;
        if (!html) {
            throw new Error('La trasformazione non ha prodotto alcun output.');
        }

        FEState.lastHtml = html;

        var frame = feFrameEl();
        // srcdoc keeps the stylesheet's own <style> block isolated from the
        // Business Central client CSS, which innerHTML would strip.
        frame.srcdoc = html;
        frame.style.display = 'block';
        feSetStatus('', false);

        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('RenderCompleted', [html.length]);
    } catch (e) {
        var msg = (e && e.message) ? e.message : String(e);
        feSetStatus('Impossibile visualizzare il documento: ' + msg, true);
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('RenderFailed', [msg]);
    }
}

function RenderRawXml() {
    var xmlText = FEState.chunks.join('');
    FEState.chunks = [];

    if (!xmlText) {
        feSetStatus('Nessun XML da visualizzare.', true);
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('RenderFailed', ['Buffer XML vuoto.']);
        return;
    }

    try {
        var parsed = new DOMParser().parseFromString(xmlText, 'application/xml');
        var parseErrors = parsed.getElementsByTagName('parsererror');
        if (parseErrors && parseErrors.length > 0) {
            throw new Error('XML non ben formato: ' + parseErrors[0].textContent.substring(0, 300));
        }

        var pretty = feIndentXml(xmlText);
        var html =
            '<!doctype html><html><head><meta charset="utf-8"><style>' +
            'body{margin:0;padding:12px;background:#fff;font-family:Consolas,"Courier New",monospace;font-size:12px;color:#323130}' +
            'pre{margin:0;white-space:pre-wrap;word-break:break-word}' +
            '</style></head><body><pre>' + feEscapeHtml(pretty) + '</pre></body></html>';

        FEState.lastHtml = html;
        var frame = feFrameEl();
        frame.srcdoc = html;
        frame.style.display = 'block';
        feSetStatus('', false);

        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('RenderCompleted', [html.length]);
    } catch (e) {
        var msg = (e && e.message) ? e.message : String(e);
        feSetStatus('Impossibile visualizzare il file: ' + msg, true);
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('RenderFailed', [msg]);
    }
}

function feEscapeHtml(text) {
    return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Minimal re-indent: SdI receipts arrive on very few lines, which is unreadable in a <pre>.
function feIndentXml(xml) {
    var normalised = xml.replace(/>\s*</g, '><').replace(/></g, '>\n<');
    var lines = normalised.split('\n');
    var depth = 0;
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line) { continue; }
        if (line.indexOf('</') === 0) { depth = Math.max(0, depth - 1); }
        out.push(new Array(depth + 1).join('  ') + line);
        var opens = line.indexOf('<') === 0 &&
                    line.indexOf('</') !== 0 &&
                    line.indexOf('<?') !== 0 &&
                    line.indexOf('<!') !== 0 &&
                    line.lastIndexOf('/>') !== line.length - 2 &&
                    line.indexOf('</') === -1;
        if (opens) { depth++; }
    }
    return out.join('\n');
}

function DownloadHtml(fileName) {
    if (!FEState.lastHtml) { return; }
    var blob = new Blob([FEState.lastHtml], { type: 'text/html;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = fileName || 'fattura.html';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 2000);
}

function PrintDocument() {
    var frame = feFrameEl();
    if (!frame || !FEState.lastHtml) { return; }
    try {
        frame.contentWindow.focus();
        frame.contentWindow.print();
    } catch (e) {
        feSetStatus('Stampa non disponibile in questo contesto: ' + e.message, true);
    }
}
