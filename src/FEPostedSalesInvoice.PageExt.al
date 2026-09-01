namespace ZZSoft.SDIBase;

using Microsoft.Sales.History;

pageextension 73010 "FE Posted Sales Invoice" extends "Posted Sales Invoice"
{
    actions
    {
        addlast(Processing)
        {
            group(FatturaPA)
            {
                Caption = 'FatturaPA';
                Image = ElectronicDoc;

                action(FEExportInvoice)
                {
                    ApplicationArea = All;
                    Caption = 'Generate and File XML';
                    Image = ExportElectronicDocument;
                    ToolTip = 'Builds the electronic invoice with the standard Italian export and files it under FatturaPA XML Files, named to the SdI rule.';

                    trigger OnAction()
                    var
                        FESalesExport: Codeunit "FE Sales Export";
                    begin
                        FESalesExport.ExportAndShow(Rec, Enum::"FE Source Doc. Type"::"Sales Invoice", Rec."No.");
                    end;
                }
                action(FEShowXmlFile)
                {
                    ApplicationArea = All;
                    Caption = 'FatturaPA File';
                    Image = XMLFile;
                    ToolTip = 'Opens the FatturaPA file already generated for this invoice.';

                    trigger OnAction()
                    var
                        XmlFile: Record "FE Xml File";
                    begin
                        XmlFile.SetRange(Origin, XmlFile.Origin::"Sales Export");
                        XmlFile.SetRange("Source Doc. Type", XmlFile."Source Doc. Type"::"Sales Invoice");
                        XmlFile.SetRange("Source Document No.", Rec."No.");
                        Page.Run(Page::"FE Xml Files", XmlFile);
                    end;
                }
            }
            group(FatturaPATest)
            {
                Caption = 'FatturaPA Test';
                Image = TestFile;

                action(FETestXmlInv)
                {
                    ApplicationArea = All;
                    Caption = 'Generate XML (Test)';
                    Image = ViewDetails;
                    ToolTip = 'Builds the FatturaPA XML for this document and downloads it, without filing it and without using up a progressive. A dry run: nothing is written and the document can still be corrected.';

                    trigger OnAction()
                    var
                        XmlTest: Codeunit "FE Xml Test";
                    begin
                        XmlTest.PreviewSalesInvoice(Rec."No.");
                    end;
                }
                action(FETestValidateInv)
                {
                    ApplicationArea = All;
                    Caption = 'Generate and Validate XML (Test)';
                    Image = CheckList;
                    ToolTip = 'Builds the XML and checks it against the loaded XSD schemas, so a document that would be rejected shows up now rather than after it has been sent. Nothing is written.';

                    trigger OnAction()
                    var
                        XmlTest: Codeunit "FE Xml Test";
                    begin
                        XmlTest.ValidateSalesInvoice(Rec."No.");
                    end;
                }
            }
        }

        addlast(Category_Category6)
        {
            actionref(FEExportInvoice_Promoted; FEExportInvoice) { }
            actionref(FETestXmlInv_Promoted; FETestXmlInv) { }
        }
    }
}
