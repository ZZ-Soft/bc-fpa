namespace ZZSoft.SDIBase;

page 73008 "FE Receipt Errors"
{
    Caption = 'Errors';
    PageType = ListPart;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "FE Receipt Error";
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
