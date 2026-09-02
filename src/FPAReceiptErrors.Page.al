namespace ZZSoft.FPA;

page 73008 "FPA Receipt Errors"
{
    Caption = 'Errors';
    PageType = ListPart;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "FPA Receipt Error";
    Editable = false;
    LinksAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Errors)
            {
                field("Line No."; Rec."Line No.") { ApplicationArea = All; Visible = false; }
                field(Codice; Rec.Codice)
                {
                    ApplicationArea = All;
                    Style = Unfavorable;
                }
                field(Descrizione; Rec.Descrizione)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                }
                field(Suggerimento; Rec.Suggerimento)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                }
            }
        }
    }
}
