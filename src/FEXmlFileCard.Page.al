namespace ZZSoft.SDIBase;

page 73001 "FE Xml File Card"
{
    // The "cartella". What it shows depends on what the file is:
    //
    //   invoice  header data read once from the single FatturaElettronicaHeader, the
    //            documents exploded out of the FatturaElettronicaBody elements, and the
    //            SdI receipts that share its base name
    //   receipt  the SdI message fields, plus a way back to the invoice it refers to

    Caption = 'FatturaPA XML File';
    PageType = Document;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "FE Xml File";
    InsertAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            group(File)
            {
                Caption = 'File';

                field("Original File Name"; Rec."Original File Name") { ApplicationArea = All; Caption = 'File Name'; }
                field("File Type"; Rec."File Type")
                {
                    ApplicationArea = All;
                    StyleExpr = FileTypeStyle;
                }
                field("SdI Base Name"; Rec."SdI Base Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shared by this file and every receipt that belongs to it.';
                }
                field(Versione; Rec.Versione) { ApplicationArea = All; }
                field("Formato Trasmissione"; Rec."Formato Trasmissione") { ApplicationArea = All; Visible = IsInvoice; }
                field("Progressivo Invio"; Rec."Progressivo Invio") { ApplicationArea = All; Visible = IsInvoice; }
                field("Id Trasmittente"; Rec."Id Trasmittente") { ApplicationArea = All; Visible = IsInvoice; }
                field("Codice Destinatario"; Rec."Codice Destinatario") { ApplicationArea = All; Visible = IsInvoice; }
                field("PEC Destinatario"; Rec."PEC Destinatario") { ApplicationArea = All; Visible = IsInvoice; }
                field("Has Signature"; Rec."Has Signature") { ApplicationArea = All; Visible = IsInvoice; }
                field("File Size (Bytes)"; Rec."File Size (Bytes)") { ApplicationArea = All; }
                field("No. of Bodies"; Rec."No. of Bodies") { ApplicationArea = All; Visible = IsInvoice; }
                field(Origin; Rec.Origin) { ApplicationArea = All; }
                field("Source Doc. Type"; Rec."Source Doc. Type") { ApplicationArea = All; Visible = FromSalesExport; }
                field("Source Document No."; Rec."Source Document No.")
                {
                    ApplicationArea = All;
                    Visible = FromSalesExport;
                    DrillDown = true;

                    trigger OnDrillDown()
                    begin
                        Rec.ShowSourceDocument();
                    end;
                }
                field("Imported At"; Rec."Imported At") { ApplicationArea = All; }
                field("Imported By"; Rec."Imported By") { ApplicationArea = All; }
            }
            group(Ricevuta)
            {
                Caption = 'SdI Receipt';
                Visible = IsReceipt;

                field("Receipt Type"; Rec."Receipt Type")
                {
                    ApplicationArea = All;
                    StyleExpr = ReceiptStyle;
                }
                field("Receipt Type Code"; Rec."Receipt Type Code") { ApplicationArea = All; }
                field("Receipt Progressive"; Rec."Receipt Progressive") { ApplicationArea = All; }
                field("Identificativo SdI"; Rec."Identificativo SdI") { ApplicationArea = All; }
                field("Referenced File Name"; Rec."Referenced File Name") { ApplicationArea = All; }
                field("File Hash"; Rec."File Hash") { ApplicationArea = All; }
                field("Receipt Date/Time"; Rec."Receipt Date/Time") { ApplicationArea = All; }
                field("Data Messa A Disposizione"; Rec."Data Messa A Disposizione") { ApplicationArea = All; }
                field("Tentativi Invio"; Rec."Tentativi Invio") { ApplicationArea = All; }
                field("Message Id"; Rec."Message Id") { ApplicationArea = All; }
                field("Pec Message Id"; Rec."Pec Message Id") { ApplicationArea = All; }
                field("Message Id Committente"; Rec."Message Id Committente") { ApplicationArea = All; }
                field(Esito; Rec.Esito)
                {
                    ApplicationArea = All;
                    StyleExpr = EsitoStyle;
                }
                field("Scarto Esito"; Rec."Scarto Esito") { ApplicationArea = All; }
                field("Riferimento Fattura"; Rec."Riferimento Fattura") { ApplicationArea = All; }
                field("Error Count"; Rec."Error Count")
                {
                    ApplicationArea = All;
                    StyleExpr = ReceiptStyle;
                }
                field("Receipt Note"; Rec."Receipt Note")
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    StyleExpr = ReceiptStyle;
                }
            }
            group(EsitoSdI)
            {
                Caption = 'SdI Outcome';
                Visible = IsInvoice;

                field("SdI Status"; Rec."SdI Status")
                {
                    ApplicationArea = All;
                    StyleExpr = SdiStatusStyle;
                    ToolTip = 'Derived from the receipts below. A rejection takes precedence over a failed delivery, which takes precedence over a delivery.';
                }
                field("No. of Receipts"; Rec."No. of Receipts")
                {
                    ApplicationArea = All;
                    DrillDown = true;

                    trigger OnDrillDown()
                    begin
                        Rec.ShowReceipts();
                    end;
                }
            }
            group(Cedente)
            {
                Caption = 'Supplier (CedentePrestatore)';
                Visible = IsInvoice;

                field("Cedente Denominazione"; Rec."Cedente Denominazione") { ApplicationArea = All; }
                field("Cedente P.IVA"; Rec."Cedente P.IVA") { ApplicationArea = All; }
                field("Cedente Codice Fiscale"; Rec."Cedente Codice Fiscale") { ApplicationArea = All; }
                field("Cedente Comune"; Rec."Cedente Comune") { ApplicationArea = All; }
                field("Cedente Provincia"; Rec."Cedente Provincia") { ApplicationArea = All; }
            }
            group(Cessionario)
            {
                Caption = 'Customer (CessionarioCommittente)';
                Visible = IsInvoice;

                field("Cessionario Denominazione"; Rec."Cessionario Denominazione") { ApplicationArea = All; }
                field("Cessionario P.IVA"; Rec."Cessionario P.IVA") { ApplicationArea = All; }
                field("Cessionario Codice Fiscale"; Rec."Cessionario Codice Fiscale") { ApplicationArea = All; }
            }
            group(Validazione)
            {
                Caption = 'XSD Validation';

                field("Validation Status"; Rec."Validation Status")
                {
                    ApplicationArea = All;
                    StyleExpr = ValidationStyle;
                }
                field("Validated At"; Rec."Validated At") { ApplicationArea = All; }
                field("Validation Message"; Rec."Validation Message")
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    Visible = ShowValidationMessage;
                }
            }

            part(Documents; "FE Xml File Doc Subform")
            {
                ApplicationArea = All;
                Caption = 'Documents';
                SubPageLink = "File Name" = field("File Name");
                UpdatePropagation = Both;
                Visible = IsInvoice;
            }
            part(ReceiptErrors; "FE Receipt Errors")
            {
                ApplicationArea = All;
                Caption = 'Errors';
                SubPageLink = "File Name" = field("File Name");
                Visible = ShowErrors;
            }
            part(Receipts; "FE Receipt Subform")
            {
                ApplicationArea = All;
                Caption = 'SdI Receipts';
                SubPageLink = "SdI Base Name" = field("SdI Base Name"),
                              "File Type" = const(Receipt);
                UpdatePropagation = Both;
                Visible = IsInvoice;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewWholeFile)
            {
                ApplicationArea = All;
                Caption = 'View Whole File';
                Image = View;
                ToolTip = 'Renders every document in the file in a single page, as the stylesheet would show the original XML.';
                RunObject = page "FE Xml File Viewer";
                RunPageOnRec = true;
            }
            action(OpenInvoice)
            {
                ApplicationArea = All;
                Caption = 'Open Invoice';
                Image = Documents;
                Visible = IsReceipt;
                ToolTip = 'Opens the invoice this receipt refers to, matched on the SdI base name.';

                trigger OnAction()
                begin
                    Rec.ShowRelatedInvoice();
                end;
            }
            action(ShowReceipts)
            {
                ApplicationArea = All;
                Caption = 'Receipts';
                Image = ReceiveLoaner;
                Visible = IsInvoice;
                ToolTip = 'Opens the SdI receipts that belong to this invoice.';

                trigger OnAction()
                begin
                    Rec.ShowReceipts();
                end;
            }
            action(ValidateXsd)
            {
                ApplicationArea = All;
                Caption = 'Validate Against XSD';
                Image = CheckList;
                ToolTip = 'Validates the whole file against the official FatturaPA XSD schemas.';

                trigger OnAction()
                var
                    XsdValidator: Codeunit "FE Xsd Validator";
                    ValidTxt: Label 'The file is valid.';
                begin
                    if XsdValidator.Validate(Rec) then
                        Message(ValidTxt)
                    else
                        Message(Rec."Validation Message");
                    CurrPage.Update(false);
                end;
            }
            action(Reexplode)
            {
                ApplicationArea = All;
                Caption = 'Re-read XML';
                Image = Recalculate;
                ToolTip = 'Parses the stored XML again and rebuilds the header fields and the document rows.';

                trigger OnAction()
                var
                    XmlReader: Codeunit "FE Xml Reader";
                begin
                    XmlReader.Explode(Rec);
                    CurrPage.Update(false);
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
        }

        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(ViewWholeFile_Promoted; ViewWholeFile) { }
                actionref(OpenInvoice_Promoted; OpenInvoice) { }
                actionref(ShowReceipts_Promoted; ShowReceipts) { }
                actionref(ValidateXsd_Promoted; ValidateXsd) { }
                actionref(DownloadXml_Promoted; DownloadXml) { }
                actionref(Reexplode_Promoted; Reexplode) { }
            }
        }
    }

    var
        ShowValidationMessage: Boolean;
        ShowErrors: Boolean;
        FromSalesExport: Boolean;
        IsInvoice: Boolean;
        IsReceipt: Boolean;
        ValidationStyle: Text;
        FileTypeStyle: Text;
        ReceiptStyle: Text;
        SdiStatusStyle: Text;
        EsitoStyle: Text;

    trigger OnAfterGetCurrRecord()
    begin
        Rec.CalcFields("No. of Documents", "Total Amount", "No. of Receipts");
        IsInvoice := Rec.IsInvoice();
        IsReceipt := Rec.IsReceipt();
        ShowErrors := Rec."Error Count" > 0;
        FromSalesExport := Rec.Origin = Rec.Origin::"Sales Export";
        SetTypeStyles();
        ShowValidationMessage := Rec."Validation Status" <> Rec."Validation Status"::" ";
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

        if Rec.Esito = 'EC02' then
            EsitoStyle := 'Unfavorable'
        else
            if Rec.Esito <> '' then
                EsitoStyle := 'Favorable'
            else
                EsitoStyle := 'Standard';
    end;
}
