namespace ZZSoft.FPA;

using Microsoft.Sales.History;
using System.Security.AccessControl;
using System.Utilities;

table 73000 "FPA Xml File"
{
    // "Cartella intermedia": one record per physical XML file.
    //
    // A FatturaPA file contains exactly ONE <FatturaElettronicaHeader> and one or more
    // <FatturaElettronicaBody> (fattura ordinaria: max 1 per lotto unless LOTTO, but the
    // schema allows N). Everything that lives in the header - trasmissione, cedente,
    // cessionario - therefore belongs here, once. Each body becomes a row in
    // "FPA Xml File Document", linked back through "File Name".
    //
    // The SdI file name is unique by construction (IdPaese + IdCodice + '_' + ProgressivoInvio),
    // so it is used directly as the primary key.

    Caption = 'FatturaPA XML File';
    DataClassification = CustomerContent;
    LookupPageId = "FPA Xml Files";
    DrillDownPageId = "FPA Xml Files";

    fields
    {
        field(1; "File Name"; Code[250])
        {
            Caption = 'File Name';
            NotBlank = true;
            ToolTip = 'Name of the imported XML file. Used as the link to the individual documents.';
        }
        field(2; "Original File Name"; Text[250])
        {
            Caption = 'Original File Name';
            Editable = false;
            ToolTip = 'File name exactly as uploaded. The primary key is a Code field, so it is upper-cased; this field preserves the original casing.';
        }
        field(3; "Xml"; Blob)
        {
            Caption = 'XML';
        }
        field(4; "File Size (Bytes)"; Integer)
        {
            Caption = 'File Size (Bytes)';
            Editable = false;
            BlankZero = true;
        }
        field(5; Versione; Code[10])
        {
            Caption = 'Version';
            Editable = false;
            ToolTip = 'Value of the versione attribute on the root element, for example FPR12 or FPA12.';
        }
        field(6; "Has Signature"; Boolean)
        {
            Caption = 'Signed';
            Editable = false;
            ToolTip = 'The file carries an enveloped ds:Signature element.';
        }
        field(7; "No. of Bodies"; Integer)
        {
            Caption = 'No. of Bodies';
            Editable = false;
            BlankZero = true;
            ToolTip = 'FatturaElettronicaBody elements physically present in the file, counted at import time. Normally identical to No. of Documents; a difference means the explosion did not complete.';
        }

        field(10; "Id Trasmittente"; Code[35])
        {
            Caption = 'Transmitter ID';
            Editable = false;
        }
        field(11; "Formato Trasmissione"; Code[10])
        {
            Caption = 'Transmission Format';
            Editable = false;
        }
        field(12; "Progressivo Invio"; Code[20])
        {
            Caption = 'Transmission Progressive No.';
            Editable = false;
        }
        field(13; "Codice Destinatario"; Code[10])
        {
            Caption = 'Recipient Code';
            Editable = false;
        }
        field(14; "PEC Destinatario"; Text[100])
        {
            Caption = 'Recipient PEC';
            Editable = false;
            ExtendedDatatype = EMail;
        }

        field(20; "Cedente Denominazione"; Text[100])
        {
            Caption = 'Supplier Name';
            Editable = false;
        }
        field(21; "Cedente P.IVA"; Code[30])
        {
            Caption = 'Supplier VAT No.';
            Editable = false;
        }
        field(22; "Cedente Codice Fiscale"; Code[30])
        {
            Caption = 'Supplier Fiscal Code';
            Editable = false;
        }
        field(23; "Cedente Comune"; Text[60])
        {
            Caption = 'Supplier City';
            Editable = false;
        }
        field(24; "Cedente Provincia"; Code[4])
        {
            Caption = 'Supplier County';
            Editable = false;
        }

        field(30; "Cessionario Denominazione"; Text[100])
        {
            Caption = 'Customer Name';
            Editable = false;
        }
        field(31; "Cessionario P.IVA"; Code[30])
        {
            Caption = 'Customer VAT No.';
            Editable = false;
        }
        field(32; "Cessionario Codice Fiscale"; Code[30])
        {
            Caption = 'Customer Fiscal Code';
            Editable = false;
        }

        field(40; "No. of Documents"; Integer)
        {
            Caption = 'No. of Documents';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("FPA Xml File Document" where("File Name" = field("File Name")));
            ToolTip = 'Number of FatturaElettronicaBody elements found in this file.';
        }
        field(41; "Total Amount"; Decimal)
        {
            Caption = 'Total Amount';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = sum("FPA Xml File Document"."Importo Totale Documento" where("File Name" = field("File Name")));
            AutoFormatType = 1;
        }

        field(50; "Validation Status"; Enum "FPA Validation Status")
        {
            Caption = 'Validation Status';
            Editable = false;
        }
        field(51; "Validation Message"; Text[1024])
        {
            Caption = 'Validation Message';
            Editable = false;
            ToolTip = 'First 1024 characters of the validator output. A schema error listing every offending node can be longer; the beginning is the part that identifies the problem.';
        }
        field(52; "Validated At"; DateTime)
        {
            Caption = 'Validated At';
            Editable = false;
        }

        field(60; "Imported At"; DateTime)
        {
            Caption = 'Imported At';
            Editable = false;
        }
        field(61; "Imported By"; Code[50])
        {
            Caption = 'Imported By';
            Editable = false;
            TableRelation = User."User Name";
            ValidateTableRelation = false;
        }

        // ---- SdI file classification, derived from the file name ----
        field(80; "File Type"; Enum "FPA File Type")
        {
            Caption = 'File Type';
            Editable = false;
            ToolTip = 'Invoice or SdI receipt. Recognised from the file name: one underscore means an invoice, more than one means a receipt.';
        }
        field(81; "SdI Base Name"; Code[250])
        {
            Caption = 'SdI Base Name';
            Editable = false;
            ToolTip = 'The IdPaese+IdCodice_ProgressivoInvio prefix, without extension. Shared by an invoice and all of its receipts - this is what links them.';
        }
        field(82; "Receipt Type"; Enum "FPA Receipt Type")
        {
            Caption = 'Receipt Type';
            Editable = false;
        }
        field(83; "Receipt Type Code"; Code[10])
        {
            Caption = 'Receipt Type Code';
            Editable = false;
            ToolTip = 'The two-letter code exactly as it appears in the file name, kept even when it is one SdI defines but this extension does not name.';
        }
        field(84; "Receipt Progressive"; Code[10])
        {
            Caption = 'Receipt Progressive';
            Editable = false;
        }
        field(85; "Identificativo SdI"; Code[36])
        {
            Caption = 'SdI Identifier';
            Editable = false;
            ToolTip = 'IdentificativoSdI_Type in SDIRicevute.xsd allows up to 36 characters, even though the values seen in practice are 11-digit numbers.';
        }
        field(86; "Receipt Date/Time"; DateTime)
        {
            Caption = 'Receipt Date/Time';
            Editable = false;
            ToolTip = 'DataOraConsegna when present, otherwise DataOraRicezione.';
        }
        field(87; "Message Id"; Code[36])
        {
            Caption = 'Message Id';
            Editable = false;
        }
        field(88; "Receipt Note"; Text[250])
        {
            Caption = 'Receipt Note';
            Editable = false;
            ToolTip = 'For a rejection: the first error, code and description. For a failed delivery: the reason. Otherwise the Note element.';
        }
        field(89; "Error Count"; Integer)
        {
            Caption = 'No. of Errors';
            Editable = false;
            BlankZero = true;
        }
        field(93; "File Hash"; Text[100])
        {
            Caption = 'File Hash';
            Editable = false;
            ToolTip = 'SHA-256 of the file the receipt refers to, as SdI received it. Identifies the exact .p7m, which the file name alone cannot.';
        }
        field(94; "Pec Message Id"; Text[100])
        {
            Caption = 'PEC Message Id';
            Editable = false;
        }
        field(95; "Data Messa A Disposizione"; Date)
        {
            Caption = 'Made Available On';
            Editable = false;
            ToolTip = 'Only on a failed-delivery receipt: the date the invoice was put in the recipient reserved area. This is the date the customer is deemed to have received it.';
        }
        field(96; "Tentativi Invio"; Integer)
        {
            Caption = 'Delivery Attempts';
            Editable = false;
            BlankZero = true;
            ToolTip = 'Only on a metadata notification.';
        }
        field(97; Esito; Code[10])
        {
            Caption = 'Esito';
            Editable = false;
            ToolTip = 'Outcome declared by the customer: EC01 accepted, EC02 refused. Present on EC and, nested, on NE.';
        }
        field(98; "Scarto Esito"; Code[10])
        {
            Caption = 'Rejected Outcome Code';
            Editable = false;
            ToolTip = 'Only on SE: why SdI rejected the outcome the customer sent.';
        }
        field(99; "Message Id Committente"; Code[36])
        {
            Caption = 'Customer Message Id';
            Editable = false;
        }
        field(103; "Riferimento Fattura"; Text[100])
        {
            Caption = 'Invoice Reference';
            Editable = false;
            ToolTip = 'Number, year and position of the invoice the outcome refers to. EC and SE carry no NomeFile, so this is the only reference they give.';
        }
        field(92; "Referenced File Name"; Text[50])
        {
            Caption = 'Referenced File Name';
            Editable = false;
            ToolTip = 'The NomeFile the receipt refers to. Often ends in .p7m even when the copy you hold is a plain .xml - which is exactly why the link runs on SdI Base Name and not on this.';
        }
        field(90; "SdI Status"; Enum "FPA SDI Status")
        {
            Caption = 'SdI Status';
            Editable = false;
            ToolTip = 'Outcome of this invoice at SdI, derived from its receipts. Precedence: rejection, then failed delivery, then delivery, then metadata.';
        }
        // ---- provenance: uploaded, or produced by the standard sales export ----
        field(100; Origin; Enum "FPA File Origin")
        {
            Caption = 'Origin';
            Editable = false;
        }
        field(101; "Source Doc. Type"; Enum "FPA Source Doc. Type")
        {
            Caption = 'Source Document Type';
            Editable = false;
        }
        field(102; "Source Document No."; Code[20])
        {
            Caption = 'Source Document No.';
            Editable = false;
            ToolTip = 'The posted sales document this file was generated from.';
        }
        field(91; "No. of Receipts"; Integer)
        {
            Caption = 'No. of Receipts';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("FPA Xml File" where("SdI Base Name" = field("SdI Base Name"), "File Type" = const(Receipt)));
        }
    }

    keys
    {
        key(PK; "File Name")
        {
            Clustered = true;
        }
        key(Supplier; "Cedente P.IVA", "Imported At")
        {
        }
        key(Imported; "Imported At")
        {
        }
        key(SdiBase; "SdI Base Name", "File Type", "Receipt Type")
        {
        }
        key(SourceDocument; Origin, "Source Doc. Type", "Source Document No.")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "File Name", "Cedente Denominazione", "Imported At")
        {
        }
        fieldgroup(Brick; "File Name", "File Type", "Cedente Denominazione", "Total Amount", "SdI Status")
        {
        }
    }

    trigger OnInsert()
    begin
        Rec."Imported At" := CurrentDateTime();
        Rec."Imported By" := CopyStr(UserId(), 1, MaxStrLen(Rec."Imported By"));
    end;

    trigger OnDelete()
    var
        XmlFileDocument: Record "FPA Xml File Document";
        ReceiptError: Record "FPA Receipt Error";
    begin
        TestCanBeChanged();

        XmlFileDocument.SetRange("File Name", Rec."File Name");
        if (XmlFileDocument.FindSet()) then
            XmlFileDocument.DeleteAll(true);

        ReceiptError.SetRange("File Name", Rec."File Name");
        if (ReceiptError.FindSet()) then
            ReceiptError.DeleteAll(true);

        // Deleting a receipt changes the outcome of its invoice, so recompute it.
        if Rec."File Type" = Rec."File Type"::Receipt then
            RefreshSdiStatusAfterDelete();
    end;

    trigger OnRename()
    begin
        Error(CannotRenameErr);
    end;

    var
        CannotRenameErr: Label 'The file name is the key of the imported document and cannot be changed. Delete the file and import it again.';
        LockedErr: Label 'File %1 has already gone to SdI - its status is %2 - so it can no longer be replaced or deleted. Only a file still in Draft can.', Comment = '%1 = file name, %2 = SdI status';
        AlreadySentErr: Label 'File %1 is no longer a draft: its status is %2.', Comment = '%1 = file name, %2 = SdI status';

    /// <summary>
    /// Returns the whole stored XML as a BigText, ready to be streamed to the control add-in.
    /// </summary>
    procedure GetXmlAsBigText(var Result: BigText)
    var
        InStr: InStream;
    begin
        Clear(Result);
        if not GetXmlInStream(InStr) then
            exit;
        Result.Read(InStr);
    end;

    procedure GetXmlInStream(var InStr: InStream): Boolean
    begin
        Rec.CalcFields(Rec.Xml);
        if not Rec.Xml.HasValue() then
            exit(false);
        Rec.Xml.CreateInStream(InStr, TextEncoding::UTF8);
        exit(true);
    end;

    /// <summary>
    /// Copies the stored XML into a Temp Blob and returns it.
    ///
    /// Use this - not GetXmlInStream - whenever the caller is going to MODIFY the record
    /// afterwards. GetXmlInStream hands back a stream that is still bound to the BLOB field
    /// of this record variable, and that stream stays alive for as long as the caller's
    /// variable is in scope: modifying the record while it is open makes the platform write
    /// the BLOB back underneath a reader. Copying to a Temp Blob cuts that link - the only
    /// stream left alive belongs to an object the record knows nothing about.
    ///
    /// It also gives an exact byte count through Temp Blob.Length(), with no second read.
    /// </summary>
    procedure GetXmlTempBlob(var TempBlob: Codeunit "Temp Blob"): Boolean
    var
        RecordInStr: InStream;
        TempOutStr: OutStream;
    begin
        Clear(TempBlob);
        Rec.CalcFields(Rec.Xml);
        if not Rec.Xml.HasValue() then
            exit(false);

        Rec.Xml.CreateInStream(RecordInStr, TextEncoding::UTF8);
        TempBlob.CreateOutStream(TempOutStr, TextEncoding::UTF8);
        CopyStream(TempOutStr, RecordInStr);
        exit(TempBlob.HasValue());
    end;


    /// <summary>
    /// Recomputes the invoice status once this receipt is gone. Called from OnDelete, where
    /// the record still holds the base name but must no longer be counted.
    /// </summary>
    local procedure RefreshSdiStatusAfterDelete()
    var
        XmlFile: Record "FPA Xml File";
        SdiStatusMgt: Codeunit "FPA SdI Status Mgt.";
        BaseName: Code[250];
    begin
        BaseName := Rec."SdI Base Name";
        if BaseName = '' then
            exit;
        XmlFile.SetRange("SdI Base Name", BaseName);
        XmlFile.SetRange("File Type", XmlFile."File Type"::Receipt);
        XmlFile.SetFilter("File Name", '<>%1', Rec."File Name");
        SdiStatusMgt.UpdateInvoiceStatusFrom(BaseName, XmlFile);
    end;

    /// <summary>
    /// Opens the receipts that belong to this invoice.
    /// </summary>
    procedure ShowReceipts()
    var
        XmlFile: Record "FPA Xml File";
    begin
        XmlFile.SetRange("SdI Base Name", Rec."SdI Base Name");
        XmlFile.SetRange("File Type", XmlFile."File Type"::Receipt);
        Page.Run(Page::"FPA Xml Files", XmlFile);
    end;

    /// <summary>
    /// From a receipt, opens the invoice it refers to.
    /// </summary>
    procedure ShowRelatedInvoice()
    var
        XmlFile: Record "FPA Xml File";
        NoInvoiceMsg: Label 'The invoice %1 has not been imported yet.', Comment = '%1 = SdI base name';
    begin
        XmlFile.SetRange("SdI Base Name", Rec."SdI Base Name");
        XmlFile.SetRange("File Type", XmlFile."File Type"::Invoice);
        if not XmlFile.FindFirst() then begin
            Message(NoInvoiceMsg, Rec."SdI Base Name");
            exit;
        end;
        Page.Run(Page::"FPA Xml File Card", XmlFile);
    end;

    procedure ShowSourceDocument()
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        case Rec."Source Doc. Type" of
            Rec."Source Doc. Type"::"Sales Invoice":
                if SalesInvoiceHeader.Get(Rec."Source Document No.") then
                    Page.Run(Page::"Posted Sales Invoice", SalesInvoiceHeader);
            Rec."Source Doc. Type"::"Sales Credit Memo":
                if SalesCrMemoHeader.Get(Rec."Source Document No.") then
                    Page.Run(Page::"Posted Sales Credit Memo", SalesCrMemoHeader);
        end;
    end;

    /// <summary>
    /// Key of the compiled stylesheet that renders this file: FATTURA for an invoice, the
    /// receipt code for an SdI message, blank when there is none (the viewer then shows source).
    /// </summary>
    procedure StylesheetKey(): Text
    var
        FileNameParser: Codeunit "FPA File Name Parser";
        InvoiceKeyTok: Label 'FATTURA', Locked = true;
    begin
        case Rec."File Type" of
            Rec."File Type"::Invoice:
                exit(InvoiceKeyTok);
            Rec."File Type"::Receipt:
                exit(FileNameParser.StylesheetKeyForReceipt(Rec."Receipt Type Code"));
        end;
        exit('');
    end;

    procedure IsInvoice(): Boolean
    begin
        exit(Rec."File Type" = Rec."File Type"::Invoice);
    end;

    procedure IsReceipt(): Boolean
    begin
        exit(Rec."File Type" = Rec."File Type"::Receipt);
    end;

    procedure ShowDocuments()
    var
        XmlFileDocument: Record "FPA Xml File Document";
    begin
        XmlFileDocument.SetRange("File Name", Rec."File Name");
        Page.Run(Page::"FPA Xml File Documents", XmlFileDocument);
    end;

    // ------------------------------------------------------------------ draft / sent

    /// <summary>
    /// True while the file has never left the building. Draft is the zero value of the status,
    /// so it is also what every newly created record starts as.
    /// </summary>
    procedure IsDraft(): Boolean
    begin
        exit(Rec."SdI Status" = Rec."SdI Status"::" ");
    end;

    /// <summary>
    /// True when the file must not be replaced or deleted any more.
    ///
    /// Only files THIS company produced are ever locked. An uploaded file - a purchase invoice,
    /// a receipt - is a local copy of something that lives at SdI, so deleting it costs nothing
    /// but the copy; receipts in particular HAVE to stay deletable, because removing one is how
    /// a wrongly matched status gets corrected.
    ///
    /// A file we sent is the opposite. SdI has it, the customer received it, and our receipts
    /// point back at it. Past Draft it is a record of what happened, not data.
    /// </summary>
    procedure IsLocked(): Boolean
    begin
        if Rec.Origin <> Rec.Origin::"Sales Export" then
            exit(false);
        exit(not IsDraft());
    end;

    /// <summary>
    /// Stops the caller when the file is past Draft.
    ///
    /// Called from OnDelete, which covers re-importing over an existing file as well: that path
    /// deletes the old record before writing the new one, so one check guards both.
    /// </summary>
    procedure TestCanBeChanged()
    begin
        if IsLocked() then
            Error(LockedErr, Rec."File Name", Rec."SdI Status");
    end;

    /// <summary>
    /// Moves the file out of Draft. This is the point of no return: from here it can no longer
    /// be deleted or overwritten, because SdI has a copy that we cannot take back.
    /// </summary>
    procedure MarkAsSent()
    begin
        if not IsDraft() then
            Error(AlreadySentErr, Rec."File Name", Rec."SdI Status");
        Rec."SdI Status" := Rec."SdI Status"::Sent;
        Rec.Modify(true);
    end;
}
