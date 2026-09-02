namespace ZZSoft.FPA;

page 73003 "FPA Xml File Documents"
{
    // Flat list of every document across every imported file: one row per
    // FatturaElettronicaBody. Supplier, customer and validation status come from the parent
    // file record through FlowFields, so nothing from the header is duplicated in storage.

    Caption = 'FatturaPA Documents';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "FPA Xml File Document";
    CardPageId = "FPA Xml File Doc Viewer";
    Editable = false;
    SourceTableView = sorting(Data) order(descending);
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Documents)
            {
                field(Numero; Rec.Numero) { ApplicationArea = All; }
                field(Data; Rec.Data) { ApplicationArea = All; }
                field("Tipo Documento"; Rec."Tipo Documento") { ApplicationArea = All; }
                field("Cedente Denominazione"; Rec."Cedente Denominazione") { ApplicationArea = All; }
                field("Cedente P.IVA"; Rec."Cedente P.IVA") { ApplicationArea = All; }
                field("Cessionario Denominazione"; Rec."Cessionario Denominazione") { ApplicationArea = All; Visible = false; }
                field("Imponibile Importo"; Rec."Imponibile Importo") { ApplicationArea = All; }
                field(Imposta; Rec.Imposta) { ApplicationArea = All; }
                field("Importo Totale Documento"; Rec."Importo Totale Documento") { ApplicationArea = All; Style = Strong; }
                field(Divisa; Rec.Divisa) { ApplicationArea = All; Visible = false; }
                field("Data Scadenza Pagamento"; Rec."Data Scadenza Pagamento") { ApplicationArea = All; }
                field("No. of Lines"; Rec."No. of Lines") { ApplicationArea = All; Visible = false; }
                field("Validation Status"; Rec."Validation Status")
                {
                    ApplicationArea = All;
                    StyleExpr = ValidationStyle;
                }
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
                    ToolTip = 'Position of this document inside its file. 1 for a single-document file.';
                }
                field(Causale; Rec.Causale) { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewDocument)
            {
                ApplicationArea = All;
                Caption = 'View';
                Image = View;
                ToolTip = 'Renders this document alone with the AssoSoftware stylesheet.';

                trigger OnAction()
                begin
                    Page.Run(Page::"FPA Xml File Doc Viewer", Rec);
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
            fileuploadaction(ImportXml)
            {
                ApplicationArea = All;
                Caption = 'Import XML';
                Image = Import;
                AllowMultipleFiles = true;
                AllowedFileExtensions = '.xml';
                ToolTip = 'Uploads one or more FatturaPA XML files - select several, or drag them onto the dialog - and creates one document per FatturaElettronicaBody. Files already imported are skipped unless you confirm the replacement.';

                trigger OnAction(Files: List of [FileUpload])
                var
                    XmlFile: Record "FPA Xml File";
                    XmlReader: Codeunit "FPA Xml Reader";
                    Summary: Text;
                begin
                    Summary := XmlReader.ImportFiles(Files, XmlFile);
                    CurrPage.Update(false);
                    Message(Summary);

                    // Open the card only for a single-file import: after a batch the list
                    // itself is the useful view.
                    if (Files.Count() = 1) and (XmlFile."File Name" <> '') then
                        Page.Run(Page::"FPA Xml File Card", XmlFile);
                end;
            }
            action(Files)
            {
                ApplicationArea = All;
                Caption = 'XML Files';
                Image = Navigate;
                RunObject = page "FPA Xml Files";
                ToolTip = 'Shows the imported XML files.';
            }
        }

        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(ViewDocument_Promoted; ViewDocument) { }
                actionref(ImportXml_Promoted; ImportXml) { }
                actionref(ShowFile_Promoted; ShowFile) { }
                actionref(Files_Promoted; Files) { }
            }
        }
    }

    var
        ValidationStyle: Text;

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Cedente Denominazione", "Cedente P.IVA", "Cessionario Denominazione", "Validation Status");
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
}
