namespace ZZSoft.SDIBase;

using Microsoft.Bank.BankAccount;
using Microsoft.EServices.EDocument;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Finance.VAT.TransactionNature;
using Microsoft.Foundation.Company;
using Microsoft.Foundation.PaymentTerms;
using Microsoft.Sales.History;

page 73020 "FE SDI Role Center"
{
    // One place for the whole electronic invoicing cycle: the files, the documents inside
    // them, the posted sales documents they come from, and the setup they depend on.
    //
    // The setup section deliberately includes STANDARD pages - Company Information, Fattura
    // Setup, VAT Transaction Natures, Payment Methods. FatturaPA is built almost entirely out
    // of data that lives there, and a role centre that only listed this extension's own pages
    // would send people hunting through Search for the fields that actually decide whether a
    // file is accepted.

    Caption = 'FatturaPA / SdI';
    PageType = RoleCenter;
    ApplicationArea = All;

    layout
    {
        area(RoleCenter)
        {
            group(Cues)
            {
                part(Activities; "FE SDI Activities")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        // The navigation bar across the top: the two lists people live in.
        area(Embedding)
        {
            action(XmlFiles)
            {
                ApplicationArea = All;
                Caption = 'FatturaPA Files';
                ToolTip = 'Every XML file: invoices sent, invoices received, and the SdI receipts.';
                RunObject = Page "FE Xml Files";
            }
            action(Documents)
            {
                ApplicationArea = All;
                Caption = 'FatturaPA Documents';
                ToolTip = 'One row per FatturaElettronicaBody, across every file.';
                RunObject = Page "FE Xml File Documents";
            }
            action(PostedSalesInvoicesEmbed)
            {
                ApplicationArea = All;
                Caption = 'Posted Sales Invoices';
                ToolTip = 'Where an outgoing FatturaPA file starts.';
                RunObject = Page "Posted Sales Invoices";
            }
        }

        // The left-hand menu.
        area(Sections)
        {
            group(FatturaPA)
            {
                Caption = 'FatturaPA';
                Image = ElectronicDoc;

                action(XmlFilesSection)
                {
                    ApplicationArea = All;
                    Caption = 'XML Files';
                    Image = XMLFile;
                    RunObject = Page "FE Xml Files";
                }
                action(DocumentsSection)
                {
                    ApplicationArea = All;
                    Caption = 'Documents';
                    Image = Documents;
                    RunObject = Page "FE Xml File Documents";
                }
                action(ReceiptErrors)
                {
                    ApplicationArea = All;
                    Caption = 'Receipt Errors';
                    Image = ErrorLog;
                    ToolTip = 'The error lines SdI returned on rejection receipts.';
                    RunObject = Page "FE Receipt Errors";
                }
            }

            group(SalesDocuments)
            {
                Caption = 'Sales';
                Image = Sales;

                action(PostedSalesInvoices)
                {
                    ApplicationArea = All;
                    Caption = 'Posted Sales Invoices';
                    Image = Invoice;
                    RunObject = Page "Posted Sales Invoices";
                }
                action(PostedSalesCrMemos)
                {
                    ApplicationArea = All;
                    Caption = 'Posted Sales Credit Memos';
                    Image = CreditMemo;
                    RunObject = Page "Posted Sales Credit Memos";
                }
            }

            group(ExtensionSetup)
            {
                Caption = 'FatturaPA Setup';
                Image = Setup;

                action(SalesExportSetup)
                {
                    ApplicationArea = All;
                    Caption = 'Sales Export Setup';
                    Image = SetupList;
                    ToolTip = 'How outgoing files are named and numbered.';
                    RunObject = Page "FE Sales Export Setup";
                }
                action(XsdSchemas)
                {
                    ApplicationArea = All;
                    Caption = 'XSD Schemas';
                    Image = XMLFile;
                    ToolTip = 'The official schemas the validation runs against. Load both, in the right order.';
                    RunObject = Page "FE Xsd Schemas";
                }
            }

            group(CompanySetup)
            {
                Caption = 'Company Data';
                Image = Company;

                action(CompanyInformation)
                {
                    ApplicationArea = All;
                    Caption = 'Company Information';
                    Image = CompanyInformation;
                    ToolTip = 'Where CedentePrestatore comes from: VAT number, fiscal code, address, REA registration, and the Company Type that becomes RegimeFiscale.';
                    RunObject = Page "Company Information";
                }
                action(FatturaSetup)
                {
                    ApplicationArea = All;
                    Caption = 'Fattura Setup';
                    Image = ElectronicDoc;
                    ToolTip = 'The Italian localization setup, including the company PA code.';
                    RunObject = Page "Fattura Setup";
                }
            }

            group(CodeSetup)
            {
                Caption = 'FatturaPA Codes';
                Image = CodesList;

                action(FatturaCodes)
                {
                    ApplicationArea = All;
                    Caption = 'Fattura Codes';
                    Image = CodesList;
                    ToolTip = 'The MP payment methods and TP payment terms SdI accepts.';
                    RunObject = Page "Fattura Codes";
                }
                action(FatturaDocumentTypes)
                {
                    ApplicationArea = All;
                    Caption = 'Fattura Document Types';
                    Image = Document;
                    ToolTip = 'The TD codes - TD01 invoice, TD04 credit memo, and the rest.';
                    RunObject = Page "Fattura Document Type List";
                }
                action(VatTransactionNatures)
                {
                    ApplicationArea = All;
                    Caption = 'VAT Transaction Natures';
                    Image = VATStatement;
                    ToolTip = 'The N codes that say why no VAT is charged. A zero rate without one is rejected.';
                    RunObject = Page "VAT Transaction Nature";
                }
                action(VatIdentifiers)
                {
                    ApplicationArea = All;
                    Caption = 'VAT Identifiers';
                    Image = VATPostingSetup;
                    ToolTip = 'Their description becomes RiferimentoNormativo on exempt lines.';
                    RunObject = Page "VAT Identifier";
                }
                action(VatPostingSetup)
                {
                    ApplicationArea = All;
                    Caption = 'VAT Posting Setup';
                    Image = VATPostingSetup;
                    ToolTip = 'Carries the VAT Transaction Nature and decides EsigibilitaIVA.';
                    RunObject = Page "VAT Posting Setup";
                }
                action(PaymentMethods)
                {
                    ApplicationArea = All;
                    Caption = 'Payment Methods';
                    Image = PaymentJournal;
                    ToolTip = 'Each one needs its Fattura PA Payment Method, or DatiPagamento cannot be written.';
                    RunObject = Page "Payment Methods";
                }
                action(PaymentTerms)
                {
                    ApplicationArea = All;
                    Caption = 'Payment Terms';
                    Image = Payment;
                    ToolTip = 'Each one needs its Fattura Payment Terms Code - TP01, TP02, TP03.';
                    RunObject = Page "Payment Terms";
                }
            }
        }
    }
}
