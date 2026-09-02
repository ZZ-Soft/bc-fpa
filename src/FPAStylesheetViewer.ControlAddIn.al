namespace ZZSoft.SDIBase;

controladdin "FE Stylesheet Viewer"
{
    // Renders a FatturaPA XML through the AssoSoftware XSLT stylesheet, entirely client side.
    //
    // Why client side: AL has no XSLT engine (XmlDocument is System.Xml.Linq only, and
    // System.Xml.Xsl.XslCompiledTransform is not reachable from a Cloud target), so the
    // transformation has to happen in the browser. We bundle SaxonJS rather than relying on
    // the browser's native XSLTProcessor, which Chromium is removing (target: late 2026).
    //
    // Resource files, all shipped inside the extension - no CDN, so no CSP problems:
    //   assets/js/SaxonJS2.rt.js  SaxonJS 2 browser runtime, downloaded from saxonica.com
    //   assets/js/fe-sef.js       all stylesheets pre-compiled to SEF (window.FE_SEF, keyed)
    //   assets/js/fe-viewer.js    the glue code exposing the procedures below
    //
    // Paths are resolved from the folder holding THIS .al file, so the assets live in
    // src/assets/ next to it.

    Scripts =
        'assets/js/saxon-js2/SaxonJS2.rt.js',
        'assets/js/fe-sef.js',
        'assets/js/fe-viewer.js';
    StartupScript = 'assets/js/fe-startup.js';
    StyleSheets = 'assets/css/fe-viewer.css';

    RequestedHeight = 900;
    MinimumHeight = 300;
    RequestedWidth = 1200;
    MinimumWidth = 400;
    VerticalStretch = true;
    HorizontalStretch = true;
    VerticalShrink = true;
    HorizontalShrink = true;

    /// <summary>Raised once the add-in DOM and the SaxonJS runtime are ready.</summary>
    event ControlAddInReady();

    /// <summary>Raised after a successful transformation. HtmlLength is the size of the produced HTML.</summary>
    event RenderCompleted(HtmlLength: Integer);

    /// <summary>Raised when the XML is malformed or the transformation fails.</summary>
    event RenderFailed(ErrorMessage: Text);

    /// <summary>Clears the XML buffer and the rendered output.</summary>
    procedure ResetBuffer();

    /// <summary>Appends one chunk of the XML document to the client-side buffer.</summary>
    procedure AppendXmlChunk(Chunk: Text);

    /// <summary>
    /// Transforms the buffered XML with the stylesheet registered under StylesheetKey and
    /// displays the result. Keys: FATTURA for an invoice, the two-letter receipt code for an
    /// SdI message. An unknown key falls back to indented source rather than a blank page.
    /// </summary>
    procedure RenderDocument(StylesheetKey: Text);

    /// <summary>
    /// Displays the buffered XML as indented source instead of transforming it.
    /// Used for SdI receipts: the AssoSoftware stylesheet only matches FatturaElettronica,
    /// so running it over a RicevutaConsegna would produce a blank page.
    /// </summary>
    procedure RenderRawXml();

    /// <summary>Shows a placeholder message instead of a document.</summary>
    procedure ShowMessage(MessageText: Text);

    /// <summary>Triggers a browser download of the rendered HTML.</summary>
    procedure DownloadHtml(FileName: Text);

    /// <summary>Opens the browser print dialog on the rendered document.</summary>
    procedure PrintDocument();
}
