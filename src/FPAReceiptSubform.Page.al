namespace ZZSoft.SDIBase;

page 73007 "FE Receipt Subform"
{
    // The SdI receipts of one invoice. Same table as the parent card - a receipt is just
    // another file - filtered through SubPageLink on "SdI Base Name" + File Type = Receipt.

    Caption = 'SdI Receipts';
    PageType = ListPart;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "FE Xml File";
    Editable = false;
    LinksAllowed = false;
    SourceTableView = sorting("SdI Base Name", "File Type", "Receipt Type");

    layout
    {
        area(Content)
        {
            repeater(Receipts)
            {
                field("Receipt Type"; Rec."Receipt Type")
                {
                    ApplicationArea = All;
                    StyleExpr = ReceiptStyle;
                }
                field("Receipt Type Code"; Rec."Receipt Type Code")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'The raw two-letter code from the file name. Shown when the type is one this extension does not name.';
                }
                field("Receipt Progressive"; Rec."Receipt Progressive") { ApplicationArea = All; }
                field("Receipt Date/Time"; Rec."Receipt Date/Time") { ApplicationArea = All; }
                field("Identificativo SdI"; Rec."Identificativo SdI") { ApplicationArea = All; }
                field("Message Id"; Rec."Message Id") { ApplicationArea = All; Visible = false; }
                field(Esito; Rec.Esito) { ApplicationArea = All; }
                field("Riferimento Fattura"; Rec."Riferimento Fattura") { ApplicationArea = All; Visible = false; }
                field("Error Count"; Rec."Error Count")
                {
                    ApplicationArea = All;
                    StyleExpr = ReceiptStyle;
                }
                field("Receipt Note"; Rec."Receipt Note")
                {
                    ApplicationArea = All;
                    StyleExpr = ReceiptStyle;
                }
                field("Referenced File Name"; Rec."Referenced File Name") { ApplicationArea = All; }
                field("Original File Name"; Rec."Original File Name") { ApplicationArea = All; Caption = 'File Name'; }
                field("Imported At"; Rec."Imported At") { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewReceipt)
            {
                ApplicationArea = All;
                Caption = 'View';
                Image = View;
                ToolTip = 'Shows the receipt XML. The AssoSoftware stylesheet only renders invoices, so a receipt is displayed as indented source.';

                trigger OnAction()
                begin
                    Page.Run(Page::"FE Xml File Viewer", Rec);
                end;
            }
            action(DownloadReceipt)
            {
                ApplicationArea = All;
                Caption = 'Download XML';
                Image = XMLFile;
                ToolTip = 'Downloads the receipt file.';

                trigger OnAction()
                var
                    InStr: InStream;
                    FileName: Text;
                begin
                    if not Rec.GetXmlInStream(InStr) then
                        exit;
                    FileName := Rec."Original File Name";
                    DownloadFromStream(InStr, '', '', '', FileName);
                end;
            }
        }
    }

    var
        ReceiptStyle: Text;

    trigger OnAfterGetRecord()
    begin
        case Rec."Receipt Type" of
            Rec."Receipt Type"::RC:
                ReceiptStyle := 'Favorable';
            Rec."Receipt Type"::NS:
                ReceiptStyle := 'Unfavorable';
            Rec."Receipt Type"::MC,
            Rec."Receipt Type"::AT:
                ReceiptStyle := 'Ambiguous';
            Rec."Receipt Type"::EC,
            Rec."Receipt Type"::NE:
                if Rec.Esito = 'EC02' then
                    ReceiptStyle := 'Unfavorable'
                else
                    ReceiptStyle := 'Favorable';
            Rec."Receipt Type"::DT:
                ReceiptStyle := 'Favorable';
            else
                ReceiptStyle := 'Standard';
        end;
    end;
}
