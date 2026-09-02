namespace ZZSoft.FPA;

using Microsoft.Foundation.Reporting;

table 73004 "FPA Sales Export Setup"
{
    // Singleton setup for turning a posted sales document into a file in "FPA Xml File".

    Caption = 'FatturaPA Sales Export Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "Electronic Format"; Code[20])
        {
            Caption = 'Electronic Format';
            TableRelation = "Electronic Document Format".Code;
            ValidateTableRelation = false;
            ToolTip = 'The Electronic Document Format used to produce the XML - the FatturaPA entry the Italian localization registers. Leave the standard export to build the document; this extension only files the result.';
        }
        field(20; "Progressivo Source"; Enum "FPA Progressivo Source")
        {
            Caption = 'Progressive Source';
            ToolTip = 'Sequential is a counter in base 36, unique by construction. Random draws 5 characters and retries on collision. From Document reuses the ProgressivoInvio the standard export wrote into the XML, so the file name and the document agree.';
        }
        field(21; "Progressivo Start No."; BigInteger)
        {
            Caption = 'Sequential Start No.';
            MinValue = 0;
            ToolTip = 'Where the sequential counter begins. Set it once, before the first export, if you want to continue a numbering already used with another system.';
        }
        field(30; "Open Card After Export"; Boolean)
        {
            Caption = 'Open Card After Export';
            InitValue = true;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    var
        FormatMissingErr: Label 'Set the Electronic Format on the FatturaPA Sales Export Setup page first. It has to be the format the Italian localization registers for FatturaPA.';

    procedure GetSetup()
    begin
        if not Rec.Get('') then begin
            Rec.Init();
            Rec."Primary Key" := '';
            Rec."Progressivo Source" := Rec."Progressivo Source"::Sequential;
            Rec."Progressivo Start No." := 1;
            Rec."Open Card After Export" := true;
            Rec.Insert(true);
        end;
    end;

    procedure GetElectronicFormat(): Code[20]
    begin
        GetSetup();
        if Rec."Electronic Format" = '' then
            Error(FormatMissingErr);
        exit(Rec."Electronic Format");
    end;
}
