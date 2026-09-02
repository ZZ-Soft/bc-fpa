namespace ZZSoft.SDIBase;

table 73006 "FE SDI Cue"
{
    // Feeds the tiles on the FatturaPA / SdI role centre.
    //
    // One row, no data of its own: every field is a FlowField that counts rows in
    // "FE Xml File". Keeping the counting in the table rather than in the page means the tiles
    // and the lists they drill into can never disagree about what a number means.

    Caption = 'FatturaPA Activities';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }

        // ---- outgoing: what we produced ----
        field(10; "Draft Outgoing"; Integer)
        {
            Caption = 'Drafts';
            FieldClass = FlowField;
            CalcFormula = count("FE Xml File" where(Origin = const("Sales Export"), "SdI Status" = const(" ")));
            ToolTip = 'Files generated from a sales document and not yet sent to SdI. These are the only ones that can still be deleted or replaced.';
        }
        field(11; "Sent Waiting"; Integer)
        {
            Caption = 'Sent, Awaiting Receipt';
            FieldClass = FlowField;
            CalcFormula = count("FE Xml File" where(Origin = const("Sales Export"), "SdI Status" = const(Sent)));
            ToolTip = 'Sent to SdI, with no receipt back yet.';
        }
        field(12; Delivered; Integer)
        {
            Caption = 'Delivered';
            FieldClass = FlowField;
            CalcFormula = count("FE Xml File" where("File Type" = const(Invoice), "SdI Status" = const(Delivered)));
        }
        field(13; Rejected; Integer)
        {
            Caption = 'Rejected';
            FieldClass = FlowField;
            CalcFormula = count("FE Xml File" where("File Type" = const(Invoice), "SdI Status" = const(Rejected)));
            ToolTip = 'SdI threw the file out. As far as the tax authority is concerned the invoice never existed - it has to be corrected and sent again.';
        }
        field(14; "Not Delivered"; Integer)
        {
            Caption = 'Not Delivered';
            FieldClass = FlowField;
            CalcFormula = count("FE Xml File" where("File Type" = const(Invoice), "SdI Status" = filter("Not Delivered" | "Transmission Attested")));
            ToolTip = 'SdI accepted the file but could not deliver it. The invoice is valid; the customer has to be told to collect it.';
        }
        field(15; "Refused by Customer"; Integer)
        {
            Caption = 'Refused by Customer';
            FieldClass = FlowField;
            CalcFormula = count("FE Xml File" where("File Type" = const(Invoice), "SdI Status" = const("Refused by Customer")));
        }

        // ---- incoming: what was uploaded ----
        field(20; "Purchase Invoices"; Integer)
        {
            Caption = 'Uploaded Invoices';
            FieldClass = FlowField;
            CalcFormula = count("FE Xml File" where(Origin = const(Upload), "File Type" = const(Invoice)));
        }
        field(21; Receipts; Integer)
        {
            Caption = 'Receipts';
            FieldClass = FlowField;
            CalcFormula = count("FE Xml File" where("File Type" = const(Receipt)));
        }
        field(22; "Unmatched Receipts"; Integer)
        {
            Caption = 'Unmatched Receipts';
            FieldClass = FlowField;
            CalcFormula = count("FE Xml File" where("File Type" = const(Receipt), "Referenced File Name" = const('')));
            ToolTip = 'Receipts whose invoice has not been imported, so there is nothing for them to update.';
        }

        // ---- quality ----
        field(30; "Not Validated"; Integer)
        {
            Caption = 'Not Validated';
            FieldClass = FlowField;
            CalcFormula = count("FE Xml File" where("File Type" = const(Invoice), "Validation Status" = const(" ")));
        }
        field(31; "Failed Validation"; Integer)
        {
            Caption = 'Failed Validation';
            FieldClass = FlowField;
            CalcFormula = count("FE Xml File" where("Validation Status" = filter(Invalid | "Not Well Formed")));
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    /// <summary>
    /// Makes sure the single row the tiles hang off exists.
    ///
    /// A cue table holds no data, but it still needs a row: FlowFields are calculated ON a
    /// record, and without one every tile would read zero.
    /// </summary>
    procedure GetCue()
    begin
        Rec.Reset();
        if Rec.Get('') then
            exit;
        Rec.Init();
        Rec."Primary Key" := '';
        if Rec.Insert() then;
    end;
}
