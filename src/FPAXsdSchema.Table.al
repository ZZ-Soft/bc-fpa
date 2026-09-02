namespace ZZSoft.SDIBase;

using System.Utilities;

table 73002 "FE Xsd Schema"
{
    Caption = 'FatturaPA XSD Schema';
    DataClassification = CustomerContent;
    LookupPageId = "FE Xsd Schemas";
    DrillDownPageId = "FE Xsd Schemas";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(3; "Target Namespace"; Text[250])
        {
            Caption = 'Target Namespace';
        }
        field(4; "Schema Xml"; Blob)
        {
            Caption = 'Schema';
        }
        field(5; "Load Order"; Integer)
        {
            Caption = 'Load Order';
            MinValue = 0;
        }
        field(6; "File Name"; Text[250])
        {
            Caption = 'File Name';
            Editable = false;
        }
        field(7; Loaded; Boolean)
        {
            Caption = 'Loaded';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
        key(LoadOrder; "Load Order")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Code", Description, "Target Namespace")
        {
        }
    }

    var
        DsigNsTxt: Label 'http://www.w3.org/2000/09/xmldsig#', Locked = true;
        FatturaNsV12Txt: Label 'http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2', Locked = true;
        MessaggiNsTxt: Label 'http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fattura/messaggi/v1.0', Locked = true;
        MessaggiPaNsTxt: Label 'http://www.fatturapa.gov.it/sdi/messaggi/v1.0', Locked = true;
        DsigCodeTxt: Label 'XMLDSIG', Locked = true;
        FatturaCodeTxt: Label 'FATTURAPA', Locked = true;
        MessaggiCodeTxt: Label 'SDIRICEVUTE', Locked = true;
        MessaggiPaCodeTxt: Label 'SDIMESSAGGI', Locked = true;
        DsigDescTxt: Label 'XML Digital Signature core schema';
        FatturaDescTxt: Label 'FatturaPA schema v1.2.x';
        MessaggiDescTxt: Label 'SdI receipts schema (SDIRicevute.xsd)';
        MessaggiPaDescTxt: Label 'SdI messages schema (MessaggiTypes_v1.1.xsd)';
        NoFileSelectedErr: Label 'No file was selected.';

    /// <summary>
    /// Creates the two rows FatturaPA v1.2 needs, in the load order the validator requires.
    /// </summary>
    procedure EnsureDefaultRows()
    begin
        InsertDefault(DsigCodeTxt, CopyStr(DsigDescTxt, 1, 100), CopyStr(DsigNsTxt, 1, 250), 10);
        InsertDefault(FatturaCodeTxt, CopyStr(FatturaDescTxt, 1, 100), CopyStr(FatturaNsV12Txt, 1, 250), 20);
        InsertDefault(MessaggiCodeTxt, CopyStr(MessaggiDescTxt, 1, 100), CopyStr(MessaggiNsTxt, 1, 250), 30);
        InsertDefault(MessaggiPaCodeTxt, CopyStr(MessaggiPaDescTxt, 1, 100), CopyStr(MessaggiPaNsTxt, 1, 250), 40);
    end;

    /// <summary>
    /// Uploads an .xsd file into THIS record, keeping its code and load order.
    /// </summary>
    procedure UploadSchema(): Boolean
    var
        FileName: Text;
        InStr: InStream;
        DialogTitleTxt: Label 'Load XSD schema';
        FilterTxt: Label 'XSD Files (*.xsd)|*.xsd|All Files (*.*)|*.*';
    begin
        if not UploadIntoStream(DialogTitleTxt, '', FilterTxt, FileName, InStr) then
            Error(NoFileSelectedErr);
        exit(StoreSchema(InStr, FileName));
    end;

    /// <summary>
    /// Routes an uploaded .xsd to the right row by its targetNamespace, creating the row if
    /// it does not exist yet. This is what lets the multi-file upload accept both official
    /// schemas in one go without the user having to prepare the rows first.
    /// </summary>
    procedure LoadFromStream(var InStr: InStream; FileName: Text): Boolean
    var
        XsdSchema: Record "FE Xsd Schema";
        TempBlob: Codeunit "Temp Blob";
        BufferOutStr: OutStream;
        BufferInStr: InStream;
        TargetNamespace: Text;
    begin
        // Buffer it: the namespace has to be read before the destination row is known,
        // and an InStream can only be consumed once.
        TempBlob.CreateOutStream(BufferOutStr, TextEncoding::UTF8);
        CopyStream(BufferOutStr, InStr);

        TempBlob.CreateInStream(BufferInStr, TextEncoding::UTF8);
        TargetNamespace := ReadTargetNamespaceFromStream(BufferInStr);
        if TargetNamespace = '' then
            exit(false);

        XsdSchema.SetRange("Target Namespace", CopyStr(TargetNamespace, 1, MaxStrLen(XsdSchema."Target Namespace")));
        if not XsdSchema.FindFirst() then
            XsdSchema := CreateRowForNamespace(TargetNamespace);

        TempBlob.CreateInStream(BufferInStr, TextEncoding::UTF8);
        exit(XsdSchema.StoreSchema(BufferInStr, FileName));
    end;

    /// <summary>
    /// Writes the stream into the BLOB of this record and refreshes File Name / Target Namespace.
    /// </summary>
    procedure StoreSchema(var InStr: InStream; FileName: Text): Boolean
    var
        OutStr: OutStream;
    begin
        Rec."File Name" := CopyStr(FileName, 1, MaxStrLen(Rec."File Name"));
        Clear(Rec."Schema Xml");
        Rec."Schema Xml".CreateOutStream(OutStr, TextEncoding::UTF8);
        CopyStream(OutStr, InStr);
        Rec.Loaded := true;
        // Persist first: ReadTargetNamespace calls CalcFields, which would otherwise
        // discard the BLOB value still sitting in memory.
        Rec.Modify(true);

        Rec."Target Namespace" := CopyStr(ReadTargetNamespace(), 1, MaxStrLen(Rec."Target Namespace"));
        Rec.Modify(true);
        exit(true);
    end;

    local procedure CreateRowForNamespace(TargetNamespace: Text) NewSchema: Record "FE Xsd Schema"
    var
        NewCode: Code[20];
        NewDescription: Text[100];
        NewOrder: Integer;
    begin
        if TargetNamespace = DsigNsTxt then begin
            NewCode := DsigCodeTxt;
            NewDescription := CopyStr(DsigDescTxt, 1, MaxStrLen(NewDescription));
            NewOrder := 10;
        end else
            if TargetNamespace = FatturaNsV12Txt then begin
                NewCode := FatturaCodeTxt;
                NewDescription := CopyStr(FatturaDescTxt, 1, MaxStrLen(NewDescription));
                NewOrder := 20;
            end else
                if TargetNamespace = MessaggiNsTxt then begin
                    NewCode := MessaggiCodeTxt;
                    NewDescription := CopyStr(MessaggiDescTxt, 1, MaxStrLen(NewDescription));
                    NewOrder := 30;
                end else
                    if TargetNamespace = MessaggiPaNsTxt then begin
                        NewCode := MessaggiPaCodeTxt;
                        NewDescription := CopyStr(MessaggiPaDescTxt, 1, MaxStrLen(NewDescription));
                        NewOrder := 40;
                    end else begin
                        // Any other schema (an older FatturaPA revision, a local variant): derive a
                        // code from the namespace and append it at the end of the load order.
                        NewCode := CopyStr(UpperCase(DelChr(TargetNamespace, '=', ':/#.- ')), 1, MaxStrLen(NewCode));
                        NewDescription := CopyStr(TargetNamespace, 1, MaxStrLen(NewDescription));
                        NewOrder := NextLoadOrder();
                    end;

        if NewSchema.Get(NewCode) then
            exit;

        NewSchema.Init();
        NewSchema.Code := NewCode;
        NewSchema.Description := NewDescription;
        NewSchema."Target Namespace" := CopyStr(TargetNamespace, 1, MaxStrLen(NewSchema."Target Namespace"));
        NewSchema."Load Order" := NewOrder;
        NewSchema.Insert(true);
    end;

    local procedure NextLoadOrder(): Integer
    var
        XsdSchema: Record "FE Xsd Schema";
    begin
        XsdSchema.SetCurrentKey("Load Order");
        if XsdSchema.FindLast() then
            exit(XsdSchema."Load Order" + 10);
        exit(10);
    end;

    local procedure InsertDefault(SchemaCode: Code[20]; SchemaDescription: Text[100]; TargetNamespace: Text[250]; LoadOrder: Integer)
    var
        XsdSchema: Record "FE Xsd Schema";
    begin
        if XsdSchema.Get(SchemaCode) then
            exit;
        XsdSchema.Init();
        XsdSchema.Code := SchemaCode;
        XsdSchema.Description := SchemaDescription;
        XsdSchema."Target Namespace" := TargetNamespace;
        XsdSchema."Load Order" := LoadOrder;
        XsdSchema.Insert(true);
    end;

    local procedure ReadTargetNamespace(): Text
    var
        InStr: InStream;
    begin
        Rec.CalcFields(Rec."Schema Xml");
        if not Rec."Schema Xml".HasValue() then
            exit('');
        Rec."Schema Xml".CreateInStream(InStr, TextEncoding::UTF8);
        exit(ReadTargetNamespaceFromStream(InStr));
    end;

    local procedure ReadTargetNamespaceFromStream(var InStr: InStream): Text
    var
        XmlDoc: XmlDocument;
        Root: XmlElement;
        NsAttribute: XmlAttribute;
    begin
        if not XmlDocument.ReadFrom(InStr, XmlDoc) then
            exit('');
        if not XmlDoc.GetRoot(Root) then
            exit('');
        if not Root.Attributes().Get('targetNamespace', NsAttribute) then
            exit('');
        exit(NsAttribute.Value());
    end;
}
