namespace ZZSoft.FPA;

page 73000 "FPA Xml Files"
{
    Caption = 'FatturaPA XML Files';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "FPA Xml File";
    CardPageId = "FPA Xml File Card";
    Editable = false;
    SourceTableView = sorting("Imported At") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Files)
            {
                field("Original File Name"; Rec."Original File Name")
                {
                    ApplicationArea = All;
                    Caption = 'File Name';
                }
                field("File Type"; Rec."File Type")
                {
                    ApplicationArea = All;
                    StyleExpr = FileTypeStyle;
                }
                field("Receipt Type"; Rec."Receipt Type")
                {
                    ApplicationArea = All;
                    StyleExpr = ReceiptStyle;
                }
                field("SdI Status"; Rec."SdI Status")
                {
                    ApplicationArea = All;
                    StyleExpr = SdiStatusStyle;
                    ToolTip = 'On an invoice: the outcome derived from its receipts.';
                }
                field("SdI Base Name"; Rec."SdI Base Name")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Groups an invoice with its receipts. Filter on it to see one transmission end to end.';
                }
                field("Receipt Note"; Rec."Receipt Note") { ApplicationArea = All; }
                field("Cedente Denominazione"; Rec."Cedente Denominazione") { ApplicationArea = All; }
                field("Cedente P.IVA"; Rec."Cedente P.IVA") { ApplicationArea = All; }
                field("Cessionario Denominazione"; Rec."Cessionario Denominazione") { ApplicationArea = All; }
                field("No. of Receipts"; Rec."No. of Receipts")
                {
                    ApplicationArea = All;
                    DrillDown = true;

                    trigger OnDrillDown()
                    begin
                        Rec.ShowReceipts();
                    end;
                }
                field("No. of Documents"; Rec."No. of Documents")
                {
                    ApplicationArea = All;
                    DrillDown = true;

                    trigger OnDrillDown()
                    begin
                        Rec.ShowDocuments();
                    end;
                }
                field("Total Amount"; Rec."Total Amount") { ApplicationArea = All; }
                field(Versione; Rec.Versione) { ApplicationArea = All; Visible = false; }
                field("Formato Trasmissione"; Rec."Formato Trasmissione") { ApplicationArea = All; }
                field("Has Signature"; Rec."Has Signature") { ApplicationArea = All; }
                field("Validation Status"; Rec."Validation Status")
                {
                    ApplicationArea = All;
                    StyleExpr = ValidationStyle;
                }
                field("File Size (Bytes)"; Rec."File Size (Bytes)") { ApplicationArea = All; Visible = false; }
                field(Origin; Rec.Origin) { ApplicationArea = All; }
                field("Source Document No."; Rec."Source Document No.")
                {
                    ApplicationArea = All;
                    DrillDown = true;

                    trigger OnDrillDown()
                    begin
                        Rec.ShowSourceDocument();
                    end;
                }
                field("Imported At"; Rec."Imported At") { ApplicationArea = All; }
                field("Imported By"; Rec."Imported By") { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
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
            action(ShowReceipts)
            {
                ApplicationArea = All;
                Caption = 'Receipts';
                Image = ReceiveLoaner;
                ToolTip = 'Shows the SdI receipts that share the base name of the selected file.';

                trigger OnAction()
                begin
                    Rec.ShowReceipts();
                end;
            }
            action(OpenInvoice)
            {
                ApplicationArea = All;
                Caption = 'Open Invoice';
                Image = Documents;
                ToolTip = 'From a receipt, opens the invoice it refers to.';

                trigger OnAction()
                begin
                    Rec.ShowRelatedInvoice();
                end;
            }
            action(ShowDocuments)
            {
                ApplicationArea = All;
                Caption = 'Documents';
                Image = Documents;
                ToolTip = 'Shows the documents extracted from this file.';

                trigger OnAction()
                begin
                    Rec.ShowDocuments();
                end;
            }
            action(Reexplode)
            {
                ApplicationArea = All;
                Caption = 'Re-read XML';
                Image = Recalculate;
                ToolTip = 'Parses the stored XML again and rebuilds the header fields and the document rows. Use after upgrading the extension.';

                trigger OnAction()
                var
                    XmlFile: Record "FPA Xml File";
                    XmlReader: Codeunit "FPA Xml Reader";
                    DoneTxt: Label '%1 file(s) re-read.', Comment = '%1 = number of files';
                    Counter: Integer;
                begin
                    CurrPage.SetSelectionFilter(XmlFile);
                    if XmlFile.FindSet() then
                        repeat
                            XmlReader.Explode(XmlFile);
                            Counter += 1;
                        until XmlFile.Next() = 0;
                    CurrPage.Update(false);
                    Message(DoneTxt, Counter);
                end;
            }
            action(ValidateSelected)
            {
                ApplicationArea = All;
                Caption = 'Validate Against XSD';
                Image = CheckList;
                ToolTip = 'Validates the selected files against the loaded FatturaPA XSD schemas.';

                trigger OnAction()
                var
                    XmlFile: Record "FPA Xml File";
                    XsdValidator: Codeunit "FPA Xsd Validator";
                    DoneTxt: Label '%1 of %2 selected files are valid.', Comment = '%1 = valid count, %2 = total count';
                    ValidCount: Integer;
                    TotalCount: Integer;
                begin
                    CurrPage.SetSelectionFilter(XmlFile);
                    if XmlFile.FindSet() then
                        repeat
                            TotalCount += 1;
                            if XsdValidator.Validate(XmlFile) then
                                ValidCount += 1;
                        until XmlFile.Next() = 0;
                    CurrPage.Update(false);
                    Message(DoneTxt, ValidCount, TotalCount);
                end;
            }
            action(DownloadXml)
            {
                ApplicationArea = All;
                Caption = 'Download XML';
                Image = XMLFile;
                ToolTip = 'Downloads the original XML file, signature included.';

                trigger OnAction()
                var
                    InStr: InStream;
                    FileName: Text;
                begin
                    if not Rec.GetXmlInStream(InStr) then
                        exit;
                    FileName := Rec."Original File Name";
                    DownloadFromStream(InStr, '', '', '', FileName);
                end;
            }
            action(SourceDocument)
            {
                ApplicationArea = All;
                Caption = 'Source Document';
                Image = Document;
                ToolTip = 'Opens the posted sales document this file was generated from.';

                trigger OnAction()
                begin
                    Rec.ShowSourceDocument();
                end;
            }
            action(SalesExportSetup)
            {
                ApplicationArea = All;
                Caption = 'Sales Export Setup';
                Image = Setup;
                RunObject = page "FPA Sales Export Setup";
                ToolTip = 'Chooses the Electronic Document Format used for outgoing invoices and how the file name progressive is built.';
            }
            action(Schemas)
            {
                ApplicationArea = All;
                Caption = 'XSD Schemas';
                Image = XMLSetup;
                RunObject = page "FPA Xsd Schemas";
                ToolTip = 'Loads the official FatturaPA XSD schemas used for validation.';
            }
        }

        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(ImportXml_Promoted; ImportXml) { }
                actionref(ShowDocuments_Promoted; ShowDocuments) { }
                actionref(ShowReceipts_Promoted; ShowReceipts) { }
                actionref(OpenInvoice_Promoted; OpenInvoice) { }
                actionref(ValidateSelected_Promoted; ValidateSelected) { }
                actionref(DownloadXml_Promoted; DownloadXml) { }
                actionref(SourceDocument_Promoted; SourceDocument) { }
                actionref(Schemas_Promoted; Schemas) { }
                actionref(SalesExportSetup_Promoted; SalesExportSetup) { }
            }
        }
    }

    var
        ValidationStyle: Text;
        FileTypeStyle: Text;
        ReceiptStyle: Text;
        SdiStatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("No. of Documents", "Total Amount", "No. of Receipts");
        SetTypeStyles();
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

    local procedure SetTypeStyles()
    begin
        if Rec."File Type" = Rec."File Type"::Unknown then
            FileTypeStyle := 'Unfavorable'
        else
            FileTypeStyle := 'Standard';

        case Rec."Receipt Type" of
            Rec."Receipt Type"::RC:
                ReceiptStyle := 'Favorable';
            Rec."Receipt Type"::NS:
                ReceiptStyle := 'Unfavorable';
            Rec."Receipt Type"::MC:
                ReceiptStyle := 'Ambiguous';
            else
                ReceiptStyle := 'Standard';
        end;

        case Rec."SdI Status" of
            Rec."SdI Status"::Delivered,
            Rec."SdI Status"::"Accepted by Customer",
            Rec."SdI Status"::"Terms Expired":
                SdiStatusStyle := 'Favorable';
            Rec."SdI Status"::Rejected,
            Rec."SdI Status"::"Refused by Customer":
                SdiStatusStyle := 'Unfavorable';
            Rec."SdI Status"::"Not Delivered",
            Rec."SdI Status"::"Transmission Attested":
                SdiStatusStyle := 'Ambiguous';
            else
                SdiStatusStyle := 'Standard';
        end;
    end;
}
