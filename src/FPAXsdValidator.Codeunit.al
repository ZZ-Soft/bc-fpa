namespace ZZSoft.SDIBase;

using System.Utilities;
using System.Xml;

codeunit 73001 "FE Xsd Validator"
{
    // Validates a FatturaPA XML against the official XSDs using codeunit "Xml Validation"
    // from the System Application (System.Xml). Supported on Business Central online - it is
    // the only sanctioned way to do XSD validation in AL, since System.Xml.Schema and
    // XmlReaderSettings are not reachable from a Cloud target.
    //
    // Validation is a FILE-level operation: the schema describes the whole document, header
    // plus all bodies, so it runs against "FE Xml File". The exploded "FE Xml File Document"
    // rows read the outcome back through a FlowField.
    //
    // FatturaPA needs TWO schemas loaded together, because the invoice schema imports the
    // XML-DSig schema for the <ds:Signature> element:
    //   1. xmldsig-core-schema.xsd   ns = http://www.w3.org/2000/09/xmldsig#
    //   2. Schema_del_file_xml_FatturaPA_v1.2.x.xsd
    //                                ns = http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2
    // Load them in that order via the "Load Order" field on table "FE Xsd Schema".

    var
        NoSchemasErr: Label 'No XSD schema has been loaded. Open the FatturaPA XSD Schemas page and load the official schemas first.';
        ValidTxt: Label 'The document is valid against the loaded XSD schemas.';
        SchemaLoadErr: Label 'Schema %1 could not be loaded: %2', Comment = '%1 = schema code, %2 = error text';

    /// <summary>
    /// Validates the whole file and writes the outcome back onto the file record.
    /// </summary>
    procedure Validate(var XmlFile: Record "FE Xml File"): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        Status: Enum "FE Validation Status";
        ResultMessage: Text;
    begin
        // Through a Temp Blob, not straight off the record: SetResult below modifies the
        // record, and a stream still bound to its BLOB field would be open when it does.
        if not XmlFile.GetXmlTempBlob(TempBlob) then
            exit(false);

        Status := ValidateTempBlob(TempBlob, ResultMessage);
        SetResult(XmlFile, Status, ResultMessage);
        exit(Status = Status::Valid);
    end;

    /// <summary>
    /// Validates XML that is not stored anywhere, and reports without writing anything.
    ///
    /// Split out of Validate so a document can be checked BEFORE it is filed - which is what a
    /// dry run needs: finding out that an invoice will be rejected is only useful while it can
    /// still be fixed rather than after it has taken a file name and a progressive.
    /// </summary>
    procedure ValidateTempBlob(var TempBlob: Codeunit "Temp Blob"; var ResultMessage: Text) Status: Enum "FE Validation Status"
    var
        XmlValidation: Codeunit "Xml Validation";
        XsdSchema: Record "FE Xsd Schema";
        XmlInStr: InStream;
        SchemaInStr: InStream;
    begin
        TempBlob.CreateInStream(XmlInStr, TextEncoding::UTF8);

        XsdSchema.SetCurrentKey("Load Order");
        XsdSchema.SetRange(Loaded, true);
        if XsdSchema.IsEmpty() then
            Error(NoSchemasErr);

        if not XmlValidation.TrySetValidatedDocument(XmlInStr) then begin
            ResultMessage := GetLastErrorText();
            exit(Status::"Not Well Formed");
        end;

        XsdSchema.FindSet();
        repeat
            XsdSchema.CalcFields("Schema Xml");
            if XsdSchema."Schema Xml".HasValue() then begin
                XsdSchema."Schema Xml".CreateInStream(SchemaInStr, TextEncoding::UTF8);
                if not XmlValidation.TryAddValidationSchema(SchemaInStr, XsdSchema."Target Namespace") then
                    Error(SchemaLoadErr, XsdSchema.Code, GetLastErrorText());
            end;
        until XsdSchema.Next() = 0;

        if XmlValidation.TryValidateAgainstSchema() then begin
            ResultMessage := ValidTxt;
            exit(Status::Valid);
        end;

        ResultMessage := GetLastErrorText();
        exit(Status::Invalid);
    end;

    /// <summary>
    /// Convenience overload: validates the file a document belongs to.
    /// </summary>
    procedure ValidateDocument(var XmlFileDocument: Record "FE Xml File Document"): Boolean
    var
        XmlFile: Record "FE Xml File";
    begin
        if not XmlFileDocument.GetXmlFile(XmlFile) then
            exit(false);
        exit(Validate(XmlFile));
    end;

    local procedure SetResult(var XmlFile: Record "FE Xml File"; Status: Enum "FE Validation Status"; ResultMessage: Text)
    begin
        XmlFile."Validation Status" := Status;
        XmlFile."Validation Message" := CopyStr(ResultMessage, 1, MaxStrLen(XmlFile."Validation Message"));
        XmlFile."Validated At" := CurrentDateTime();
        XmlFile.Modify(true);
    end;
}
