namespace ZZSoft.FPA;

page 73004 "FPA Xml File Doc Subform"
{
    Caption = 'Documents';
    PageType = ListPart;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "FPA Xml File Document";
    Editable = false;
    AutoSplitKey = false;
    LinksAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Documents)
            {
                field("Body No."; Rec."Body No.") { ApplicationArea = All; }
                field("Tipo Documento"; Rec."Tipo Documento") { ApplicationArea = All; }
                field(Numero; Rec.Numero) { ApplicationArea = All; }
                field(Data; Rec.Data) { ApplicationArea = All; }
                field("Imponibile Importo"; Rec."Imponibile Importo") { ApplicationArea = All; }
                field(Imposta; Rec.Imposta) { ApplicationArea = All; }
                field("Importo Totale Documento"; Rec."Importo Totale Documento") { ApplicationArea = All; Style = Strong; }
                field(Divisa; Rec.Divisa) { ApplicationArea = All; }
                field("No. of Lines"; Rec."No. of Lines") { ApplicationArea = All; }
                field("Data Scadenza Pagamento"; Rec."Data Scadenza Pagamento") { ApplicationArea = All; }
                field(Causale; Rec.Causale) { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewDocument)
            {
                ApplicationArea = All;
                Caption = 'View';
                Image = View;
                ToolTip = 'Renders this document alone with the AssoSoftware stylesheet.';

                trigger OnAction()
                begin
                    Page.Run(Page::"FPA Xml File Doc Viewer", Rec);
                end;
            }
        }
    }
}
