namespace ZZSoft.FPA;

using System.Utilities;

codeunit 73009 "FPA Xml Test"
{
    // Dry runs of the FatturaPA writer, from a posted sales document.
    //
    // Nothing here writes to the database. No file is created in "FPA Xml File", no document
    // rows are exploded, and above all NO PROGRESSIVE IS DRAWN: NumberSequence hands values out
    // outside the transaction and never takes them back, so a hundred test runs would leave a
    // hundred holes in the numbering of the invoices actually sent. The dry run supplies its own
    // fixed progressive instead.
    //
    // What it is for: seeing the XML, and finding out which field is missing, while the invoice
    // can still be corrected - rather than after it has taken a name and a number.

    var
        TestProgressivoTok: Label 'TEST0', Locked = true;
        ValidTxt: Label 'The generated document is valid against the loaded XSD schemas.';
        InvalidMsg: Label 'The generated document did NOT pass validation.\\%1\\\Download it anyway to look at it?', Comment = '%1 = validation message';
        NotWellFormedMsg: Label 'The generated document is not well-formed XML.\\%1', Comment = '%1 = error text';
        DownloadQst: Label 'Download the generated file?';

    /// <summary>
    /// Builds the XML for a posted sales invoice and offers it as a download.
    /// </summary>
    procedure PreviewSalesInvoice(DocumentNo: Code[20])
    var
        TempBlob: Codeunit "Temp Blob";
    begin
        BuildInvoice(DocumentNo, TempBlob);
        Download(TempBlob);
    end;

    /// <summary>
    /// Same for a posted credit memo.
    /// </summary>
    procedure PreviewSalesCrMemo(DocumentNo: Code[20])
    var
        TempBlob: Codeunit "Temp Blob";
    begin
        BuildCrMemo(DocumentNo, TempBlob);
        Download(TempBlob);
    end;

    /// <summary>
    /// Builds it and runs it through the XSD schemas, reporting what SdI would object to.
    /// </summary>
    procedure ValidateSalesInvoice(DocumentNo: Code[20])
    var
        TempBlob: Codeunit "Temp Blob";
    begin
        BuildInvoice(DocumentNo, TempBlob);
        ValidateAndReport(TempBlob);
    end;

    procedure ValidateSalesCrMemo(DocumentNo: Code[20])
    var
        TempBlob: Codeunit "Temp Blob";
    begin
        BuildCrMemo(DocumentNo, TempBlob);
        ValidateAndReport(TempBlob);
    end;

    local procedure BuildInvoice(DocumentNo: Code[20]; var TempBlob: Codeunit "Temp Blob")
    var
        XmlFileManager: Codeunit "FPA Xml File Manager";
    begin
        XmlFileManager.SetProgressivo(CopyStr(TestProgressivoTok, 1, 10));
        XmlFileManager.BuildFromSalesInvoice(DocumentNo);
        XmlFileManager.ToTempBlob(TempBlob);
    end;

    local procedure BuildCrMemo(DocumentNo: Code[20]; var TempBlob: Codeunit "Temp Blob")
    var
        XmlFileManager: Codeunit "FPA Xml File Manager";
    begin
        XmlFileManager.SetProgressivo(CopyStr(TestProgressivoTok, 1, 10));
        XmlFileManager.BuildFromSalesCrMemo(DocumentNo);
        XmlFileManager.ToTempBlob(TempBlob);
    end;

    local procedure ValidateAndReport(var TempBlob: Codeunit "Temp Blob")
    var
        XsdValidator: Codeunit "FPA Xsd Validator";
        Status: Enum "FPA Validation Status";
        ResultMessage: Text;
    begin
        Status := XsdValidator.ValidateTempBlob(TempBlob, ResultMessage);

        case Status of
            Status::Valid:
                begin
                    // Valid is the boring answer, so it does not need a download prompt of its
                    // own - but the file is usually still wanted, to read it.
                    if Confirm(StrSubstNo('%1\\\%2', ValidTxt, DownloadQst), true) then
                        Download(TempBlob);
                end;
            Status::"Not Well Formed":
                Message(NotWellFormedMsg, ResultMessage);
            else
                if Confirm(InvalidMsg, false, ResultMessage) then
                    Download(TempBlob);
        end;
    end;

    /// <summary>
    /// Hands the generated XML to the browser under the name the real export would have used,
    /// with a progressive of TEST0 so it cannot be mistaken for a file that was actually sent.
    /// </summary>
    local procedure Download(var TempBlob: Codeunit "Temp Blob")
    var
        ProgressivoMgt: Codeunit "FPA Progressivo Mgt.";
        InStr: InStream;
        FileName: Text;
    begin
        FileName := ProgressivoMgt.FileNameFor(CopyStr(TestProgressivoTok, 1, 10));
        TempBlob.CreateInStream(InStr, TextEncoding::UTF8);
        DownloadFromStream(InStr, '', '', '', FileName);
    end;
}
