namespace ZZSoft.FPA;

using Microsoft.Sales.History;

pageextension 73010 "FPA Posted Sales Invoice" extends "Posted Sales Invoice"
{
    actions
    {
        addlast(Processing)
        {
            group(FPAFatturaPA)
            {
                Caption = 'FatturaPA';
                Image = ElectronicDoc;

                action(FPAExportInvoice)
                {
                    ApplicationArea = All;
                    Caption = 'Generate and File XML';
                    Image = ExportElectronicDocument;
                    ToolTip = 'Builds the electronic invoice with the standard Italian export and files it under FatturaPA XML Files, named to the SdI rule.';

                    trigger OnAction()
                    var
                        FPASalesExport: Codeunit "FPA Sales Export";
                    begin
                        FPASalesExport.ExportAndShow(Rec, Enum::"FPA Source Doc. Type"::"Sales Invoice", Rec."No.");
                    end;
                }
                action(FPAShowXmlFile)
                {
                    ApplicationArea = All;
                    Caption = 'FatturaPA File';
                    Image = XMLFile;
                    ToolTip = 'Opens the FatturaPA file already generated for this invoice.';

                    trigger OnAction()
                    var
                        XmlFile: Record "FPA Xml File";
                    begin
                        XmlFile.SetRange(Origin, XmlFile.Origin::"Sales Export");
                        XmlFile.SetRange("Source Doc. Type", XmlFile."Source Doc. Type"::"Sales Invoice");
                        XmlFile.SetRange("Source Document No.", Rec."No.");
                        Page.Run(Page::"FPA Xml Files", XmlFile);
                    end;
                }
            }
            group(FPAFatturaPATest)
            {
                Caption = 'FatturaPA Test';
                Image = TestFile;

                action(FPATestXmlInv)
                {
                    ApplicationArea = All;
                    Caption = 'Generate XML (Test)';
                    Image = ViewDetails;
                    ToolTip = 'Builds the FatturaPA XML for this document and downloads it, without filing it and without using up a progressive. A dry run: nothing is written and the document can still be corrected.';

                    trigger OnAction()
                    var
                        XmlTest: Codeunit "FPA Xml Test";
                    begin
                        XmlTest.PreviewSalesInvoice(Rec."No.");
                    end;
                }
                action(FPATestValidateInv)
                {
                    ApplicationArea = All;
                    Caption = 'Generate and Validate XML (Test)';
                    Image = CheckList;
                    ToolTip = 'Builds the XML and checks it against the loaded XSD schemas, so a document that would be rejected shows up now rather than after it has been sent. Nothing is written.';

                    trigger OnAction()
                    var
                        XmlTest: Codeunit "FPA Xml Test";
                    begin
                        XmlTest.ValidateSalesInvoice(Rec."No.");
                    end;
                }
            }
        }

        addlast(Category_Category6)
        {
            actionref(FPAExportInvoice_Promoted; FPAExportInvoice) { }
            actionref(FPATestXmlInv_Promoted; FPATestXmlInv) { }
        }
    }
}
