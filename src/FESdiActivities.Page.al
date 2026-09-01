namespace ZZSoft.SDIBase;

page 73021 "FE SDI Activities"
{
    // The tile part of the FatturaPA / SdI role centre.
    //
    // Every tile drills into "FE Xml Files" with the SAME filters the tile counted with, set
    // in code rather than through DrillDownPageId - which would open the list unfiltered and
    // leave the user to work out which of 4,000 rows the number referred to.

    Caption = 'FatturaPA';
    PageType = CardPart;
    ApplicationArea = All;
    SourceTable = "FE SDI Cue";
    RefreshOnActivate = true;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            cuegroup(Outgoing)
            {
                Caption = 'Sent to SdI';

                field("Draft Outgoing"; Rec."Draft Outgoing")
                {
                    ApplicationArea = All;
                    Caption = 'Drafts';
                    ToolTip = 'Generated from a sales document and not yet sent. Still deletable and replaceable.';

                    trigger OnDrillDown()
                    var
                        XmlFile: Record "FE Xml File";
                    begin
                        XmlFile.SetRange(Origin, XmlFile.Origin::"Sales Export");
                        XmlFile.SetRange("SdI Status", XmlFile."SdI Status"::" ");
                        ShowFiles(XmlFile);
                    end;
                }
                field("Sent Waiting"; Rec."Sent Waiting")
                {
                    ApplicationArea = All;
                    Caption = 'Awaiting Receipt';
                    ToolTip = 'Sent to SdI, no receipt back yet.';
                    StyleExpr = 'Ambiguous';

                    trigger OnDrillDown()
                    var
                        XmlFile: Record "FE Xml File";
                    begin
                        XmlFile.SetRange(Origin, XmlFile.Origin::"Sales Export");
                        XmlFile.SetRange("SdI Status", XmlFile."SdI Status"::Sent);
                        ShowFiles(XmlFile);
                    end;
                }
                field(Delivered; Rec.Delivered)
                {
                    ApplicationArea = All;
                    Caption = 'Delivered';
                    StyleExpr = 'Favorable';

                    trigger OnDrillDown()
                    var
                        XmlFile: Record "FE Xml File";
                    begin
                        ShowInvoicesWithStatus(XmlFile."SdI Status"::Delivered);
                    end;
                }
            }

            cuegroup(NeedsAttention)
            {
                Caption = 'Needs Attention';

                field(Rejected; Rec.Rejected)
                {
                    ApplicationArea = All;
                    Caption = 'Rejected';
                    ToolTip = 'SdI threw the file out, so the invoice never legally existed. It has to be corrected and sent again.';
                    StyleExpr = 'Unfavorable';

                    trigger OnDrillDown()
                    var
                        XmlFile: Record "FE Xml File";
                    begin
                        ShowInvoicesWithStatus(XmlFile."SdI Status"::Rejected);
                    end;
                }
                field("Not Delivered"; Rec."Not Delivered")
                {
                    ApplicationArea = All;
                    Caption = 'Not Delivered';
                    ToolTip = 'Accepted by SdI but not delivered. The invoice is valid - the customer has to be told to collect it from their tax portal.';
                    StyleExpr = 'Ambiguous';

                    trigger OnDrillDown()
                    var
                        XmlFile: Record "FE Xml File";
                    begin
                        XmlFile.SetRange("File Type", XmlFile."File Type"::Invoice);
                        XmlFile.SetFilter(
                          "SdI Status", '%1|%2',
                          XmlFile."SdI Status"::"Not Delivered", XmlFile."SdI Status"::"Transmission Attested");
                        ShowFiles(XmlFile);
                    end;
                }
                field("Refused by Customer"; Rec."Refused by Customer")
                {
                    ApplicationArea = All;
                    Caption = 'Refused by Customer';
                    StyleExpr = 'Unfavorable';

                    trigger OnDrillDown()
                    var
                        XmlFile: Record "FE Xml File";
                    begin
                        ShowInvoicesWithStatus(XmlFile."SdI Status"::"Refused by Customer");
                    end;
                }
                field("Failed Validation"; Rec."Failed Validation")
                {
                    ApplicationArea = All;
                    Caption = 'Failed Validation';
                    ToolTip = 'Files that did not pass the XSD check, or that are not well-formed XML at all.';
                    StyleExpr = 'Unfavorable';

                    trigger OnDrillDown()
                    var
                        XmlFile: Record "FE Xml File";
                    begin
                        XmlFile.SetFilter(
                          "Validation Status", '%1|%2',
                          XmlFile."Validation Status"::Invalid, XmlFile."Validation Status"::"Not Well Formed");
                        ShowFiles(XmlFile);
                    end;
                }
                field("Unmatched Receipts"; Rec."Unmatched Receipts")
                {
                    ApplicationArea = All;
                    Caption = 'Unmatched Receipts';
                    ToolTip = 'Receipts whose invoice has never been imported, so there is nothing for them to update.';

                    trigger OnDrillDown()
                    var
                        XmlFile: Record "FE Xml File";
                    begin
                        XmlFile.SetRange("File Type", XmlFile."File Type"::Receipt);
                        XmlFile.SetRange("Referenced File Name", '');
                        ShowFiles(XmlFile);
                    end;
                }
            }

            cuegroup(Incoming)
            {
                Caption = 'Uploaded';

                field("Purchase Invoices"; Rec."Purchase Invoices")
                {
                    ApplicationArea = All;
                    Caption = 'Invoices';

                    trigger OnDrillDown()
                    var
                        XmlFile: Record "FE Xml File";
                    begin
                        XmlFile.SetRange(Origin, XmlFile.Origin::Upload);
                        XmlFile.SetRange("File Type", XmlFile."File Type"::Invoice);
                        ShowFiles(XmlFile);
                    end;
                }
                field(Receipts; Rec.Receipts)
                {
                    ApplicationArea = All;
                    Caption = 'Receipts';

                    trigger OnDrillDown()
                    var
                        XmlFile: Record "FE Xml File";
                    begin
                        XmlFile.SetRange("File Type", XmlFile."File Type"::Receipt);
                        ShowFiles(XmlFile);
                    end;
                }
                field("Not Validated"; Rec."Not Validated")
                {
                    ApplicationArea = All;
                    Caption = 'Not Validated';
                    ToolTip = 'Invoices that have never been checked against the XSD schemas.';

                    trigger OnDrillDown()
                    var
                        XmlFile: Record "FE Xml File";
                    begin
                        XmlFile.SetRange("File Type", XmlFile."File Type"::Invoice);
                        XmlFile.SetRange("Validation Status", XmlFile."Validation Status"::" ");
                        ShowFiles(XmlFile);
                    end;
                }

                actions
                {
                    action(ImportXml)
                    {
                        ApplicationArea = All;
                        Caption = 'Import XML Files';
                        Image = Import;
                        ToolTip = 'Opens the file list, where invoices and receipts can be uploaded.';
                        RunObject = Page "FE Xml Files";
                    }
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetCue();
    end;

    local procedure ShowFiles(var XmlFile: Record "FE Xml File")
    begin
        Page.Run(Page::"FE Xml Files", XmlFile);
    end;

    local procedure ShowInvoicesWithStatus(Status: Enum "FE SdI Status")
    var
        XmlFile: Record "FE Xml File";
    begin
        XmlFile.SetRange("File Type", XmlFile."File Type"::Invoice);
        XmlFile.SetRange("SdI Status", Status);
        ShowFiles(XmlFile);
    end;
}
