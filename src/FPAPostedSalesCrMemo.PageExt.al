namespace ZZSoft.FPA;

using Microsoft.Sales.History;

pageextension 73012 "FPA Posted Sales Cr. Memo" extends "Posted Sales Credit Memo"
{
    actions
    {
        addlast(Processing)
        {
            group(FPAFatturaPA)
            {
                Caption = 'FatturaPA';
                Image = ElectronicDoc;

                action(FPAExportCrMemo)
                {
                    ApplicationArea = All;
                    Caption = 'Generate and File XML';
                    Image = ExportElectronicDocument;
                    ToolTip = 'Builds the electronic credit memo with the standard Italian export and files it under FatturaPA XML Files, named to the SdI rule.';

                    trigger OnAction()
                    var
                        FPASalesExport: Codeunit "FPA Sales Export";
                    begin
                        FPASalesExport.ExportAndShow(Rec, Enum::"FPA Source Doc. Type"::"Sales Credit Memo", Rec."No.");
                    end;
                }
                action(FPAShowXmlFile)
                {
                    ApplicationArea = All;
                    Caption = 'FatturaPA File';
                    Image = XMLFile;
                    ToolTip = 'Opens the FatturaPA file already generated for this credit memo.';

                    trigger OnAction()
                    var
                        XmlFile: Record "FPA Xml File";
                    begin
                        XmlFile.SetRange(Origin, XmlFile.Origin::"Sales Export");
                        XmlFile.SetRange("Source Doc. Type", XmlFile."Source Doc. Type"::"Sales Credit Memo");
                        XmlFile.SetRange("Source Document No.", Rec."No.");
                        Page.Run(Page::"FPA Xml Files", XmlFile);
                    end;
                }
            }
            group(FPAFatturaPATest)
            {
                Caption = 'FatturaPA Test';
                Image = TestFile;

                action(FPATestXmlCrM)
                {
                    ApplicationArea = All;
                    Caption = 'Generate XML (Test)';
                    Image = ViewDetails;
                    ToolTip = 'Builds the FatturaPA XML for this document and downloads it, without filing it and without using up a progressive. A dry run: nothing is written and the document can still be corrected.';

                    trigger OnAction()
                    var
                        XmlTest: Codeunit "FPA Xml Test";
                    begin
                        XmlTest.PreviewSalesCrMemo(Rec."No.");
                    end;
                }
                action(FPATestValidateCrM)
                {
                    ApplicationArea = All;
                    Caption = 'Generate and Validate XML (Test)';
                    Image = CheckList;
                    ToolTip = 'Builds the XML and checks it against the loaded XSD schemas, so a document that would be rejected shows up now rather than after it has been sent. Nothing is written.';

                    trigger OnAction()
                    var
                        XmlTest: Codeunit "FPA Xml Test";
                    begin
                        XmlTest.ValidateSalesCrMemo(Rec."No.");
                    end;
                }
            }
        }

        addlast(Category_Category6)
        {
            actionref(FPAExportCrMemo_Promoted; FPAExportCrMemo) { }
            actionref(FPATestXmlCrM_Promoted; FPATestXmlCrM) { }
        }
    }
}
