namespace ZZSoft.SDIBase;

table 73003 "FE Receipt Error"
{
    // One row per <Errore> inside the <ListaErrori> of a RicevutaScarto.
    //
    // This is a child table rather than a field on the receipt because SDIRicevute.xsd allows
    // up to 200 errors per rejection, each with a mandatory Descrizione (up to 1000 chars) and
    // Suggerimento (up to 2000). Folding that into a single Text field would lose almost all
    // of it - and the Suggerimento is the part that tells you what to actually fix.

    Caption = 'SdI Receipt Error';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "File Name"; Code[250])
        {
            Caption = 'File Name';
            NotBlank = true;
            TableRelation = "FE Xml File"."File Name";
            ValidateTableRelation = false;
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            MinValue = 1;
        }
        field(10; Codice; Code[10])
        {
            Caption = 'Error Code';
            Editable = false;
            ToolTip = 'SdI error code, for example 00404. The schema allows up to 5 characters.';
        }
        field(11; Descrizione; Text[1000])
        {
            Caption = 'Description';
            Editable = false;
        }
        field(12; Suggerimento; Text[2000])
        {
            Caption = 'Suggestion';
            Editable = false;
            ToolTip = 'What SdI suggests doing about it. Mandatory in the schema, so it is always present.';
        }
    }

    keys
    {
        key(PK; "File Name", "Line No.")
        {
            Clustered = true;
        }
        key(Code; Codice)
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Codice, Descrizione)
        {
        }
    }
}
