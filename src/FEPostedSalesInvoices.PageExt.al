namespace ZZSoft.SDIBase;

using Microsoft.Sales.History;

pageextension 73011 "FE Posted Sales Invoices" extends "Posted Sales Invoices"
{
    actions
    {
        addlast(Processing)
        {
            group(FEFatturaPA)
            {
                Caption = 'FatturaPA';
                Image = ElectronicDoc;

                action(FEExportSelected)
                {
                    ApplicationArea = All;
                    Caption = 'SDI XML file';
                    Image = ExportElectronicDocument;
                    Scope = Repeater;
                    ToolTip = 'Builds the electronic invoice for each selected document with the standard Italian export and files it under FatturaPA XML Files, exploded into FatturaPA Documents. One failure does not stop the others.';

                    trigger OnAction()
                    begin
                        ExportSelection();
                    end;
                }
                action(FEShowXmlFiles)
                {
                    ApplicationArea = All;
                    Caption = 'FatturaPA Files';
                    Image = XMLFile;
                    Scope = Repeater;
                    ToolTip = 'Opens the FatturaPA files generated from the selected invoices.';

                    trigger OnAction()
                    begin
                        ShowXmlFilesForSelection();
                    end;
                }
                action(FEShowDocuments)
                {
                    ApplicationArea = All;
                    Caption = 'FatturaPA Documents';
                    Image = Documents;
                    Scope = Repeater;
                    ToolTip = 'Opens the exploded documents - one per FatturaElettronicaBody - of the files generated from the selected invoices.';

                    trigger OnAction()
                    begin
                        ShowDocumentsForSelection();
                    end;
                }
            }
        }

        addlast(Category_Process)
        {
            actionref(FEExportSelected_Promoted; FEExportSelected) { }
            actionref(FEShowDocuments_Promoted; FEShowDocuments) { }
        }
    }

    var
        NoFileMsg: Label 'None of the selected invoices has been filed as FatturaPA yet.';
        DoneMsg: Label '%1 of %2 selected invoices were filed, producing %3 document(s).', Comment = '%1 = exported, %2 = total, %3 = documents';
        DoneWithErrorsMsg: Label '%1 of %2 selected invoices were filed, producing %3 document(s).\\%4 failed. First error:\\%5', Comment = '%1 = exported, %2 = total, %3 = documents, %4 = failed, %5 = error text';
        ReExportQst: Label 'Some of the selected invoices have already been filed. Generate a new file for those as well?';
        BatchQst: Label 'Generate a FatturaPA file for %1 invoices?', Comment = '%1 = number of selected invoices';

    local procedure ExportSelection()
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        XmlFile: Record "FE Xml File";
        FESalesExport: Codeunit "FE Sales Export";
        Exported: Integer;
        Failed: Integer;
        Total: Integer;
        Documents: Integer;
        FirstError: Text;
    begin
        CurrPage.SetSelectionFilter(SalesInvoiceHeader);
        if not SalesInvoiceHeader.FindSet() then
            exit;

        // Say out loud how many documents are about to be generated, and stop unless the
        // answer is yes. Generating an SdI file is not reversible in a useful sense - each one
        // burns a progressive - so a batch must never start by accident.
        if SalesInvoiceHeader.Count() > 1 then
            if not Confirm(BatchQst, false, SalesInvoiceHeader.Count()) then
                exit;

        // Decide about re-exports BEFORE the first write. Confirm is a dialog, and Business
        // Central refuses to open one once the transaction has written to the database, so
        // asking lazily inside the loop would fail on every batch where the already-filed
        // invoice is not the first one.
        if (SalesInvoiceHeader.count() = 1) then
            Message('Fattura: %1 %2', SalesInvoiceHeader."No.", SalesInvoiceHeader."Sell-to Customer Name");
        FESalesExport.SetBatchReExport(AskAboutReExport(SalesInvoiceHeader));

        repeat
            Total += 1;
            if TryExportOne(FESalesExport, SalesInvoiceHeader, XmlFile) then begin
                Exported += 1;
                XmlFile.CalcFields("No. of Documents");
                Documents += XmlFile."No. of Documents";
            end else begin
                Failed += 1;
                // A TryFunction that is only tested and never read is a black hole: keep the
                // first reason so the summary can say WHY, not just how many.
                if FirstError = '' then
                    FirstError := GetLastErrorText();
            end;
        until SalesInvoiceHeader.Next() = 0;

        CurrPage.Update(false);
        if Failed > 0 then
            Message(DoneWithErrorsMsg, Exported, Total, Documents, Failed, FirstError)
        else
            Message(DoneMsg, Exported, Total, Documents);
    end;

    /// <summary>
    /// Asks once, up front, and only if at least one of the selected invoices really has a
    /// file already. Returns false when nothing needs asking, which also means "do not redo".
    /// </summary>
    local procedure AskAboutReExport(var SalesInvoiceHeader: Record "Sales Invoice Header"): Boolean
    var
        Selected: Record "Sales Invoice Header";
        XmlFile: Record "FE Xml File";
    begin
        // Copy, not CopyFilters: a multi-row selection is expressed with MARKS, and
        // CopyFilters carries only the filters - it would silently widen the scan to every
        // invoice in the current view. Copy also gives an independent cursor, so the export
        // loop still finds the caller's record where it left it.
        Selected.Copy(SalesInvoiceHeader);
        if not Selected.FindSet() then
            exit(false);

        XmlFile.SetRange(Origin, XmlFile.Origin::"Sales Export");
        XmlFile.SetRange("Source Doc. Type", XmlFile."Source Doc. Type"::"Sales Invoice");
        repeat
            XmlFile.SetRange("Source Document No.", Selected."No.");
            if not XmlFile.IsEmpty() then
                exit(Confirm(ReExportQst, false));
        until Selected.Next() = 0;

        exit(false);
    end;

    /// <summary>
    /// One badly set up document must not abort a batch of fifty, so each export runs inside
    /// a TryFunction and the loop carries on.
    /// </summary>
    [TryFunction]
    local procedure TryExportOne(var FESalesExport: Codeunit "FE Sales Export"; var SalesInvoiceHeader: Record "Sales Invoice Header"; var XmlFile: Record "FE Xml File")
    begin
        FESalesExport.ExportPostedSalesInvoice(SalesInvoiceHeader, XmlFile);
    end;

    local procedure ShowXmlFilesForSelection()
    var
        XmlFile: Record "FE Xml File";
    begin
        if not MarkFilesForSelection(XmlFile) then begin
            Message(NoFileMsg);
            exit;
        end;
        XmlFile.Reset();
        XmlFile.MarkedOnly(true);
        Page.Run(Page::"FE Xml Files", XmlFile);
    end;

    local procedure ShowDocumentsForSelection()
    var
        XmlFile: Record "FE Xml File";
        XmlFileDocument: Record "FE Xml File Document";
        Found: Boolean;
    begin
        if not MarkFilesForSelection(XmlFile) then begin
            Message(NoFileMsg);
            exit;
        end;

        XmlFile.Reset();
        XmlFile.MarkedOnly(true);
        if XmlFile.FindSet() then
            repeat
                XmlFileDocument.SetRange("File Name", XmlFile."File Name");
                if XmlFileDocument.FindSet() then
                    repeat
                        XmlFileDocument.Mark(true);
                        Found := true;
                    until XmlFileDocument.Next() = 0;
            until XmlFile.Next() = 0;

        if not Found then begin
            Message(NoFileMsg);
            exit;
        end;

        XmlFileDocument.Reset();
        XmlFileDocument.MarkedOnly(true);
        Page.Run(Page::"FE Xml File Documents", XmlFileDocument);
    end;

    /// <summary>
    /// Marks every FatturaPA file produced by the selected invoices.
    ///
    /// Marks rather than a built filter string: a file name is user data, and pasting several
    /// of them into a SetFilter would break the moment one contained a character the filter
    /// syntax treats as an operator.
    /// </summary>
    local procedure MarkFilesForSelection(var XmlFile: Record "FE Xml File"): Boolean
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        Found: Boolean;
    begin
        CurrPage.SetSelectionFilter(SalesInvoiceHeader);
        if not SalesInvoiceHeader.FindSet() then
            exit(false);

        XmlFile.SetRange(Origin, XmlFile.Origin::"Sales Export");
        XmlFile.SetRange("Source Doc. Type", XmlFile."Source Doc. Type"::"Sales Invoice");
        repeat
            XmlFile.SetRange("Source Document No.", SalesInvoiceHeader."No.");
            if XmlFile.FindSet() then
                repeat
                    XmlFile.Mark(true);
                    Found := true;
                until XmlFile.Next() = 0;
        until SalesInvoiceHeader.Next() = 0;

        exit(Found);
    end;
}
