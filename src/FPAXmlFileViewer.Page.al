namespace ZZSoft.FPA;

page 73002 "FPA Xml File Viewer"
{
    // Renders the file as-is.
    //
    // An invoice goes through the AssoSoftware stylesheet: every FatturaElettronicaBody it
    // contains, stacked, exactly as the original XML would look. Use "FPA Xml File Doc Viewer" for
    // a single document.
    //
    // A receipt goes through its own official SdI stylesheet - one per message type, all
    // nine of them bundled - so a RicevutaConsegna renders as SdI itself renders it, not as
    // raw XML. Anything with no stylesheet still falls back to indented source.

    Caption = 'FatturaPA File Preview';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "FPA Xml File";
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            group(File)
            {
                Caption = 'File';
                ShowCaption = false;

                field("Original File Name"; Rec."Original File Name") { ApplicationArea = All; Caption = 'File Name'; }
                field("File Type"; Rec."File Type") { ApplicationArea = All; }
                field("Receipt Type"; Rec."Receipt Type") { ApplicationArea = All; Visible = IsReceipt; }
                field("No. of Documents"; Rec."No. of Documents") { ApplicationArea = All; Visible = IsInvoice; }
                field("Cedente Denominazione"; Rec."Cedente Denominazione") { ApplicationArea = All; Visible = IsInvoice; }
            }

            usercontrol(ViewerControl; "FPA Stylesheet Viewer")
            {
                ApplicationArea = All;

                trigger ControlAddInReady()
                begin
                    AddInReady := true;
                    RenderFile();
                end;

                trigger RenderCompleted(HtmlLength: Integer)
                begin
                    Rendered := true;
                end;

                trigger RenderFailed(ErrorMessage: Text)
                begin
                    Rendered := false;
                    Session.LogMessage('FPA0002', ErrorMessage, Verbosity::Warning,
                        DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'FatturaPAViewer');
                end;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Refresh)
            {
                ApplicationArea = All;
                Caption = 'Refresh Preview';
                Image = Refresh;
                ToolTip = 'Renders the file again: through the AssoSoftware stylesheet for an invoice, as indented XML source for a receipt.';

                trigger OnAction()
                begin
                    RenderFile();
                end;
            }
            action(PrintPreview)
            {
                ApplicationArea = All;
                Caption = 'Print';
                Image = Print;
                ToolTip = 'Opens the browser print dialog.';

                trigger OnAction()
                begin
                    if Rendered then
                        CurrPage.ViewerControl.PrintDocument();
                end;
            }
            action(DownloadHtml)
            {
                ApplicationArea = All;
                Caption = 'Download HTML';
                Image = Export;
                ToolTip = 'Downloads the whole file rendered as a standalone HTML document.';

                trigger OnAction()
                begin
                    if Rendered then
                        CurrPage.ViewerControl.DownloadHtml(Rec."Original File Name" + '.html');
                end;
            }
        }

        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(Refresh_Promoted; Refresh) { }
                actionref(PrintPreview_Promoted; PrintPreview) { }
                actionref(DownloadHtml_Promoted; DownloadHtml) { }
            }
        }
    }

    var
        AddInReady: Boolean;
        Rendered: Boolean;
        IsInvoice: Boolean;
        IsReceipt: Boolean;

    trigger OnAfterGetCurrRecord()
    begin
        Rec.CalcFields("No. of Documents");
        IsInvoice := Rec.IsInvoice();
        IsReceipt := Rec.IsReceipt();
        if AddInReady then
            RenderFile();
    end;

    local procedure RenderFile()
    var
        ChunkHelper: Codeunit "FPA Chunk Helper";
        FileXml: BigText;
        Chunks: List of [Text];
        Chunk: Text;
        NoXmlTxt: Label 'This file has no XML attached.';
    begin
        Rendered := false;
        if not AddInReady then
            exit;

        Rec.GetXmlAsBigText(FileXml);
        if FileXml.Length() = 0 then begin
            CurrPage.ViewerControl.ShowMessage(NoXmlTxt);
            exit;
        end;

        CurrPage.ViewerControl.ResetBuffer();
        ChunkHelper.SplitIntoChunks(FileXml, Chunks);
        foreach Chunk in Chunks do
            CurrPage.ViewerControl.AppendXmlChunk(Chunk);

        // The add-in picks the stylesheet by key and falls back to indented source when
        // there is none for this kind of file.
        CurrPage.ViewerControl.RenderDocument(Rec.StylesheetKey());
    end;
}
