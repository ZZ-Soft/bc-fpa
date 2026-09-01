namespace ZZSoft.SDIBase;

using Microsoft.Sales.History;
using System.Utilities;

codeunit 73007 "FE Sales Export"
{
    // Files an outgoing invoice into "FE Xml File", so sales sits next to purchases and
    // receipts in one place.
    //
    // The XML is NOT built here either: codeunit "FE Xml File Manager" builds it from the
    // posted document, and this codeunit only decides what the file is called and where it is
    // filed.
    //
    // It used to go through "Electronic Document Format".SendElectronically - the standard
    // Italian export. That path is gone. It routes through a Record Export Buffer and an error
    // log, so a document that fails its checks comes back as an empty blob with no reason
    // attached, which is exactly what it did here. Its collector, "Fattura Doc. Helper", is
    // marked [Scope('OnPrem')] and cannot be called from a Cloud target either, so there was no
    // way to run the same checks up front and report them.
    //
    // Building the XML in this extension gives every rejection a message that names the field.

    var
        BatchAnswered: Boolean;
        BatchReExport: Boolean;
        NoContentErr: Label 'The electronic document for %1 came out empty.', Comment = '%1 = document no.';
        UnsupportedTypeErr: Label 'Document type %1 cannot be exported as FatturaPA.', Comment = '%1 = source document type';
        AlreadyExportedQst: Label 'Document %1 has already been exported as %2. Export it again with a new file name?', Comment = '%1 = document no., %2 = existing file name';
        ExportedMsg: Label 'Document %1 was filed as %2.', Comment = '%1 = document no., %2 = file name';

    /// <summary>
    /// Answers the "already exported, do it again?" question once for a whole batch.
    ///
    /// Needed because Confirm cannot open after the transaction has written, so a batch has
    /// to settle the question before the first export rather than at the first collision.
    /// Set on the codeunit instance the batch reuses for every document.
    /// </summary>
    procedure SetBatchReExport(Allowed: Boolean)
    begin
        BatchAnswered := true;
        BatchReExport := Allowed;
    end;

    /// <summary>
    /// Generates and files the electronic invoice for a posted sales invoice.
    /// </summary>
    procedure ExportPostedSalesInvoice(SalesInvoiceHeader: Record "Sales Invoice Header"; var XmlFile: Record "FE Xml File"): Boolean
    begin
        exit(ExportDocument(Enum::"FE Source Doc. Type"::"Sales Invoice", SalesInvoiceHeader."No.", XmlFile));
    end;

    /// <summary>
    /// Same for a posted sales credit memo.
    /// </summary>
    procedure ExportPostedSalesCrMemo(SalesCrMemoHeader: Record "Sales Cr.Memo Header"; var XmlFile: Record "FE Xml File"): Boolean
    begin
        exit(ExportDocument(Enum::"FE Source Doc. Type"::"Sales Credit Memo", SalesCrMemoHeader."No.", XmlFile));
    end;

    local procedure ExportDocument(SourceDocType: Enum "FE Source Doc. Type"; DocumentNo: Code[20]; var XmlFile: Record "FE Xml File"): Boolean
    var
        XmlFileManager: Codeunit "FE Xml File Manager";
        ProgressivoMgt: Codeunit "FE Progressivo Mgt.";
        XmlReader: Codeunit "FE Xml Reader";
        TempBlob: Codeunit "Temp Blob";
        InStr: InStream;
        FileName: Code[250];
        Progressivo: Code[10];
    begin
        if not ConfirmReExport(SourceDocType, DocumentNo) then
            exit(false);

        // Built here rather than handed over by the standard export. The builder draws the
        // ProgressivoInvio itself, writes it into DatiTrasmissione, and gives it back - so the
        // file name is derived from the same value the document carries instead of being
        // guessed from it afterwards.
        case SourceDocType of
            SourceDocType::"Sales Invoice":
                Progressivo := XmlFileManager.BuildFromSalesInvoice(DocumentNo);
            SourceDocType::"Sales Credit Memo":
                Progressivo := XmlFileManager.BuildFromSalesCrMemo(DocumentNo);
            else
                Error(UnsupportedTypeErr, SourceDocType);
        end;

        XmlFileManager.ToTempBlob(TempBlob);
        if not TempBlob.HasValue() then
            Error(NoContentErr, DocumentNo);

        FileName := ProgressivoMgt.FileNameFor(Progressivo);

        TempBlob.CreateInStream(InStr, TextEncoding::UTF8);
        if not XmlReader.ImportFromStream(InStr, FileName, true, XmlFile) then
            exit(false);

        // ImportFromStream already classified and exploded it; only the provenance is left.
        XmlFile.Origin := XmlFile.Origin::"Sales Export";
        XmlFile."Source Doc. Type" := SourceDocType;
        XmlFile."Source Document No." := DocumentNo;
        XmlFile.Modify(true);

        exit(true);
    end;

    /// <summary>
    /// Runs the export from a page and reports the outcome.
    /// </summary>
    procedure ExportAndShow(DocumentVariant: Variant; SourceDocType: Enum "FE Source Doc. Type"; DocumentNo: Code[20])
    var
        XmlFile: Record "FE Xml File";
        SalesExportSetup: Record "FE Sales Export Setup";
        Exported: Boolean;
    begin
        case SourceDocType of
            SourceDocType::"Sales Invoice":
                Exported := ExportPostedSalesInvoice(GetSalesInvoiceHeader(DocumentNo), XmlFile);
            SourceDocType::"Sales Credit Memo":
                Exported := ExportPostedSalesCrMemo(GetSalesCrMemoHeader(DocumentNo), XmlFile);
        end;

        if not Exported then
            exit;

        SalesExportSetup.GetSetup();
        if SalesExportSetup."Open Card After Export" then
            Page.Run(Page::"FE Xml File Card", XmlFile)
        else
            Message(ExportedMsg, DocumentNo, XmlFile."Original File Name");
    end;

    local procedure GetSalesInvoiceHeader(DocumentNo: Code[20]) SalesInvoiceHeader: Record "Sales Invoice Header"
    begin
        SalesInvoiceHeader.Get(DocumentNo);
    end;

    local procedure GetSalesCrMemoHeader(DocumentNo: Code[20]) SalesCrMemoHeader: Record "Sales Cr.Memo Header"
    begin
        SalesCrMemoHeader.Get(DocumentNo);
    end;

    /// <summary>
    /// A second export of the same document is legitimate - a resend needs a new file name -
    /// but it is worth confirming, because it is more often a double click.
    /// </summary>
    local procedure ConfirmReExport(SourceDocType: Enum "FE Source Doc. Type"; DocumentNo: Code[20]): Boolean
    var
        XmlFile: Record "FE Xml File";
    begin
        XmlFile.SetRange(Origin, XmlFile.Origin::"Sales Export");
        XmlFile.SetRange("Source Doc. Type", SourceDocType);
        XmlFile.SetRange("Source Document No.", DocumentNo);
        if not XmlFile.FindFirst() then
            exit(true);
        if BatchAnswered then
            exit(BatchReExport);
        exit(Confirm(AlreadyExportedQst, false, DocumentNo, XmlFile."Original File Name"));
    end;

}
