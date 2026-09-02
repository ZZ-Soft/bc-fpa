namespace ZZSoft.FPA;

page 73005 "FPA Xml File Doc Viewer"
{
    // Renders ONE FatturaElettronicaBody. The XML handed to the add-in is built on the fly
    // by "FPA Body Extractor": file header + this body only, so a multi-document lotto shows
    // one invoice at a time instead of all of them stacked in a single page.

    Caption = 'FatturaPA Document';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "FPA Xml File Document";
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            group(Documento)
            {
                Caption = 'Document';

                field("File Name"; Rec."File Name")
                {
                    ApplicationArea = All;
                    DrillDown = true;

                    trigger OnDrillDown()
                    var
                        XmlFile: Record "FPA Xml File";
                    begin
                        if Rec.GetXmlFile(XmlFile) then
                            Page.Run(Page::"FPA Xml File Card", XmlFile);
                    end;
                }
                field("Body No."; Rec."Body No.")
                {
                    ApplicationArea = All;
                    Visible = ShowBodyNo;
                }
                field(Numero; Rec.Numero) { ApplicationArea = All; }
                field(Data; Rec.Data) { ApplicationArea = All; }
                field("Tipo Documento"; Rec."Tipo Documento") { ApplicationArea = All; }
                field(Causale; Rec.Causale) { ApplicationArea = All; MultiLine = true; }
            }
            group(Importi)
            {
                Caption = 'Amounts';

                field("Imponibile Importo"; Rec."Imponibile Importo") { ApplicationArea = All; }
                field(Imposta; Rec.Imposta) { ApplicationArea = All; }
                field("Importo Totale Documento"; Rec."Importo Totale Documento") { ApplicationArea = All; Style = Strong; }
                field(Divisa; Rec.Divisa) { ApplicationArea = All; }
                field("No. of Lines"; Rec."No. of Lines") { ApplicationArea = All; }
                field("Data Scadenza Pagamento"; Rec."Data Scadenza Pagamento") { ApplicationArea = All; }
            }
            group(Parti)
            {
                Caption = 'Parties';

                field("Cedente Denominazione"; Rec."Cedente Denominazione") { ApplicationArea = All; }
                field("Cedente P.IVA"; Rec."Cedente P.IVA") { ApplicationArea = All; }
                field("Cessionario Denominazione"; Rec."Cessionario Denominazione") { ApplicationArea = All; }
                field("Cessionario P.IVA"; Rec."Cessionario P.IVA") { ApplicationArea = All; }
                field("Validation Status"; Rec."Validation Status")
                {
                    ApplicationArea = All;
                    StyleExpr = ValidationStyle;
                    ToolTip = 'XSD validation applies to the whole file. Open the file card to see the message.';
                }
            }

            usercontrol(ViewerControl; "FPA Stylesheet Viewer")
            {
                ApplicationArea = All;

                trigger ControlAddInReady()
                begin
                    AddInReady := true;
                    RenderCurrentDocument();
                end;

                trigger RenderCompleted(HtmlLength: Integer)
                begin
                    Rendered := true;
                end;

                trigger RenderFailed(ErrorMessage: Text)
                begin
                    Rendered := false;
                    Session.LogMessage('FPA0001', ErrorMessage, Verbosity::Warning,
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
                ToolTip = 'Runs the AssoSoftware stylesheet again over this document.';

                trigger OnAction()
                begin
                    RenderCurrentDocument();
                end;
            }
            action(ShowFile)
            {
                ApplicationArea = All;
                Caption = 'Open File';
                Image = XMLFile;
                ToolTip = 'Opens the XML file this document was extracted from.';

                trigger OnAction()
                var
                    XmlFile: Record "FPA Xml File";
                begin
                    if Rec.GetXmlFile(XmlFile) then
                        Page.Run(Page::"FPA Xml File Card", XmlFile);
                end;
            }
            action(ValidateXsd)
            {
                ApplicationArea = All;
                Caption = 'Validate File Against XSD';
                Image = CheckList;
                ToolTip = 'Validates the whole XML file against the official FatturaPA XSD schemas.';

                trigger OnAction()
                var
                    XmlFile: Record "FPA Xml File";
                    XsdValidator: Codeunit "FPA Xsd Validator";
                    ValidTxt: Label 'The file is valid.';
                begin
                    if not Rec.GetXmlFile(XmlFile) then
                        exit;
                    if XsdValidator.Validate(XmlFile) then
                        Message(ValidTxt)
                    else
                        Message(XmlFile."Validation Message");
                    CurrPage.Update(false);
                end;
            }
            action(DownloadHtml)
            {
                ApplicationArea = All;
                Caption = 'Download HTML';
                Image = Export;
                ToolTip = 'Downloads this document as a standalone HTML file.';

                trigger OnAction()
                begin
                    if not Rendered then
                        exit;
                    CurrPage.ViewerControl.DownloadHtml(BuildFileName());
                end;
            }
            action(PrintPreview)
            {
                ApplicationArea = All;
                Caption = 'Print';
                Image = Print;
                ToolTip = 'Opens the browser print dialog for this document.';

                trigger OnAction()
                begin
                    if not Rendered then
                        exit;
                    CurrPage.ViewerControl.PrintDocument();
                end;
            }
        }

        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(Refresh_Promoted; Refresh) { }
                actionref(ValidateXsd_Promoted; ValidateXsd) { }
                actionref(PrintPreview_Promoted; PrintPreview) { }
                actionref(DownloadHtml_Promoted; DownloadHtml) { }
                actionref(ShowFile_Promoted; ShowFile) { }
            }
        }
    }

    var
        AddInReady: Boolean;
        Rendered: Boolean;
        ShowBodyNo: Boolean;
        ValidationStyle: Text;

    trigger OnAfterGetCurrRecord()
    var
        XmlFile: Record "FPA Xml File";
    begin
        Rec.CalcFields("Cedente Denominazione", "Cedente P.IVA", "Cessionario Denominazione", "Cessionario P.IVA", "Validation Status");
        ShowBodyNo := Rec.GetXmlFile(XmlFile) and (XmlFile."No. of Bodies" > 1);
        SetValidationStyle();
        if AddInReady then
            RenderCurrentDocument();
    end;

    local procedure SetValidationStyle()
    begin
        case Rec."Validation Status" of
            Rec."Validation Status"::Valid:
                ValidationStyle := 'Favorable';
            Rec."Validation Status"::Invalid,
            Rec."Validation Status"::"Not Well Formed":
                ValidationStyle := 'Unfavorable';
            else
                ValidationStyle := 'Standard';
        end;
    end;

    /// <summary>
    /// Extracts this single body, then streams it to the client in chunks.
    /// </summary>
    local procedure RenderCurrentDocument()
    var
        ChunkHelper: Codeunit "FPA Chunk Helper";
        DocumentXml: BigText;
        Chunks: List of [Text];
        Chunk: Text;
        NoXmlTxt: Label 'This document has no XML attached.';
        InvoiceStylesheetKeyTok: Label 'FATTURA', Locked = true;
    begin
        Rendered := false;
        if not AddInReady then
            exit;

        Rec.GetSingleDocumentXml(DocumentXml);
        if DocumentXml.Length() = 0 then begin
            CurrPage.ViewerControl.ShowMessage(NoXmlTxt);
            exit;
        end;

        CurrPage.ViewerControl.ResetBuffer();
        ChunkHelper.SplitIntoChunks(DocumentXml, Chunks);
        foreach Chunk in Chunks do
            CurrPage.ViewerControl.AppendXmlChunk(Chunk);
        CurrPage.ViewerControl.RenderDocument(InvoiceStylesheetKeyTok);
    end;

    local procedure BuildFileName(): Text
    var
        FileNameTok: Label '%1_%2.html', Locked = true;
        XmlFile: Record "FPA Xml File";
    begin
        Rec.GetXmlFile(XmlFile);
        exit(StrSubstNo(FileNameTok,
            DelChr(XmlFile."Cedente P.IVA", '=', '/\:*?"<>| '),
            DelChr(Rec.Numero, '=', '/\:*?"<>| ')));
    end;
}
