namespace ZZSoft.FPA;

using Microsoft.Bank.BankAccount;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Foundation.Address;
using Microsoft.Foundation.Company;
using Microsoft.Foundation.PaymentTerms;
using Microsoft.Sales.Customer;
using Microsoft.Sales.History;
using Microsoft.Sales.Receivables;
using System.Utilities;

codeunit 73008 "FPA Xml File Manager"
{
    // Builds a FatturaPA XML from scratch with the AL XmlDocument API.
    //
    // Holds one document at a time: call NewDocument, fill it through the Add* helpers, then
    // take the result with ToTempBlob or ToText.
    //
    // ---------------------------------------------------------------------------------------
    // The one thing that decides whether SdI accepts the file
    // ---------------------------------------------------------------------------------------
    // In FatturaPA ONLY THE ROOT is namespace-qualified. Every descendant - FatturaElettronica
    // Header, DatiTrasmissione, all of them - is unqualified.
    //
    // So the root must declare the namespace under a PREFIX (p:), never as a default xmlns.
    // The difference is invisible in the root tag and fatal underneath it:
    //
    //   <p:FatturaElettronica xmlns:p="...">     child ends up in NO namespace   <- correct
    //     <FatturaElettronicaHeader>
    //
    //   <FatturaElettronica xmlns="...">         child is DRAGGED INTO the namespace
    //     <FatturaElettronicaHeader>             (or needs xmlns="" to escape it)
    //
    // System.Xml.Linq - which is what AL's XmlDocument is - decides an element's prefix at
    // serialisation time from the namespace declarations in scope. Creating the root in the
    // FatturaPA namespace AND declaring the p prefix on it is what produces "p:". Children are
    // then created with no namespace at all and come out unqualified.
    // ---------------------------------------------------------------------------------------

    var
        XmlDoc: XmlDocument;
        RootElement: XmlElement;
        DocumentStarted: Boolean;
        DocumentVersione: Code[10];
        ForcedProgressivo: Code[10];

        FatturaNsTok: Label 'http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2', Locked = true;
        DsigNsTok: Label 'http://www.w3.org/2000/09/xmldsig#', Locked = true;
        XsiNsTok: Label 'http://www.w3.org/2001/XMLSchema-instance', Locked = true;
        SchemaLocationTok: Label 'http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2 http://www.fatturapa.gov.it/export/fatturazione/sdi/fatturapa/v1.2/Schema_del_file_xml_FatturaPA_versione_1.2.xsd', Locked = true;
        RootNameTok: Label 'FatturaElettronica', Locked = true;
        FatturaPrefixTok: Label 'p', Locked = true;
        DsigPrefixTok: Label 'ds', Locked = true;
        XsiPrefixTok: Label 'xsi', Locked = true;
        VersioneAttrTok: Label 'versione', Locked = true;
        SchemaLocationAttrTok: Label 'schemaLocation', Locked = true;
        DefaultVersioneTok: Label 'FPR12', Locked = true;
        XmlVersionTok: Label '1.0', Locked = true;
        XmlEncodingTok: Label 'UTF-8', Locked = true;
        HeaderNameTok: Label 'FatturaElettronicaHeader', Locked = true;
        BodyNameTok: Label 'FatturaElettronicaBody', Locked = true;
        DatiTrasmissioneNameTok: Label 'DatiTrasmissione', Locked = true;
        NoSdiCodeTok: Label '0000000', Locked = true;
        PaVersioneTok: Label 'FPA12', Locked = true;
        ItalyIsoTok: Label 'IT', Locked = true;
        DefaultRegimeFiscaleTok: Label 'RF01', Locked = true;
        SocioUnicoTok: Label 'SU', Locked = true;
        SociMultipliTok: Label 'SM', Locked = true;
        InLiquidazioneTok: Label 'LS', Locked = true;
        NonInLiquidazioneTok: Label 'LN', Locked = true;
        InvoiceTipoDocumentoTok: Label 'TD01', Locked = true;
        CrMemoTipoDocumentoTok: Label 'TD04', Locked = true;
        BolloVirtualeTok: Label 'SI', Locked = true;
        ScontoTok: Label 'SC', Locked = true;
        MaggiorazioneTok: Label 'MG', Locked = true;
        RateTok: Label 'TP01', Locked = true;
        CompletoTok: Label 'TP02', Locked = true;
        ImmediataTok: Label 'I', Locked = true;
        DifferitaTok: Label 'D', Locked = true;
        SplitPaymentTok: Label 'S', Locked = true;
        SplitPaymentNormativoTok: Label 'ALIQUOTA IVA %1 SPLIT PAYMENT', Comment = '%1 = the VAT rate, exactly as written into AliquotaIVA', Locked = true;
        NotStartedErr: Label 'No FatturaPA document has been started. Call NewDocument first.';
        ProgressivoRequiredErr: Label 'ProgressivoInvio is mandatory and can be at most 10 characters.';
        CodiceDestinatarioLenErr: Label 'CodiceDestinatario must be %1 characters for %2, but %3 was supplied.', Comment = '%1 = expected length, %2 = format, %3 = value';
        PecNotAllowedErr: Label 'PECDestinatario can only be used when CodiceDestinatario is %1. It was supplied together with %2.', Comment = '%1 = 0000000, %2 = the code supplied';

    // ------------------------------------------------------------------ document

    /// <summary>
    /// Starts a new document and builds the root element:
    ///
    ///   &lt;?xml version="1.0" encoding="UTF-8"?&gt;
    ///   &lt;p:FatturaElettronica versione="FPR12"
    ///       xmlns:ds="..." xmlns:p="..." xmlns:xsi="..." xsi:schemaLocation="..."&gt;
    ///
    /// Versione is FPR12 for a private recipient, FPA12 for a public administration; pass
    /// blank for FPR12.
    /// </summary>
    procedure NewDocument(Versione: Code[10])
    begin
        if Versione = '' then
            Versione := DefaultVersioneTok;

        // Created IN the FatturaPA namespace. On its own this would serialise as a default
        // xmlns; the prefix declaration added below is what turns it into p:.
        RootElement := XmlElement.Create(RootNameTok, FatturaNsTok);

        // Attribute order follows the order they are added. SdI does not care, but matching
        // the layout everyone else emits makes the files easy to diff against a reference.
        RootElement.Add(XmlAttribute.Create(VersioneAttrTok, Versione));
        RootElement.Add(XmlAttribute.CreateNamespaceDeclaration(DsigPrefixTok, DsigNsTok));
        RootElement.Add(XmlAttribute.CreateNamespaceDeclaration(FatturaPrefixTok, FatturaNsTok));
        RootElement.Add(XmlAttribute.CreateNamespaceDeclaration(XsiPrefixTok, XsiNsTok));
        RootElement.Add(XmlAttribute.Create(SchemaLocationAttrTok, XsiNsTok, SchemaLocationTok));

        XmlDoc := XmlDocument.Create();
        XmlDoc.SetDeclaration(XmlDeclaration.Create(XmlVersionTok, XmlEncodingTok, ''));
        XmlDoc.Add(RootElement);

        // Kept because FormatoTrasmissione inside DatiTrasmissione must equal the versione
        // attribute on the root. Two places, one value - so it is remembered, not asked twice.
        DocumentVersione := Versione;
        DocumentStarted := true;
    end;

    /// <summary>
    /// Pins the ProgressivoInvio the next Build call will use, instead of drawing a new one.
    ///
    /// For dry runs only. Call it before Build; pass a blank to go back to drawing.
    /// </summary>
    procedure SetProgressivo(ProgressivoInvio: Code[10])
    begin
        ForcedProgressivo := ProgressivoInvio;
    end;

    /// <summary>
    /// The root, to hang FatturaElettronicaHeader and the bodies off.
    /// </summary>
    procedure GetRoot(): XmlElement
    begin
        TestStarted();
        exit(RootElement);
    end;

    procedure GetDocument(): XmlDocument
    begin
        TestStarted();
        exit(XmlDoc);
    end;


    // ------------------------------------------------------------------ header

    /// <summary>
    /// Adds &lt;FatturaElettronicaHeader&gt; under the root and returns it.
    /// </summary>
    procedure AddHeader() Header: XmlElement
    var
        Root: XmlElement;
    begin
        Root := GetRoot();
        Header := AddGroup(Root, HeaderNameTok);
    end;

    /// <summary>
    /// Writes &lt;DatiTrasmissione&gt; complete, in the order the schema requires:
    ///
    ///     IdTrasmittente ( IdPaese, IdCodice )
    ///     ProgressivoInvio
    ///     FormatoTrasmissione
    ///     CodiceDestinatario
    ///     ContattiTrasmittente ( Telefono, Email )    optional
    ///     PECDestinatario                             optional
    ///
    /// The order is not cosmetic: the schema declares an xs:sequence, so an element in the
    /// wrong position is rejected exactly like a missing one.
    ///
    /// Everything about the TRANSMITTER comes from Company Information - the same derivation
    /// the file name uses, so the name and the document cannot disagree. Only what belongs to
    /// the RECIPIENT is passed in.
    ///
    /// Pass ProgressivoInvio the same value that went into the file name when you want the
    /// two to match.
    /// </summary>
    procedure AddDatiTrasmissione(var Header: XmlElement; ProgressivoInvio: Code[10]; CodiceDestinatario: Code[7]; PecDestinatario: Text) DatiTrasmissione: XmlElement
    var
        CompanyInformation: Record "Company Information";
        ProgressivoMgt: Codeunit "FPA Progressivo Mgt.";
        IdTrasmittente: XmlElement;
        IdPaese: Code[10];
        IdCodice: Text;
    begin
        TestStarted();

        ProgressivoInvio := DelChr(ProgressivoInvio, '<>', ' ');
        if (ProgressivoInvio = '') or (StrLen(ProgressivoInvio) > 10) then
            Error(ProgressivoRequiredErr);

        CodiceDestinatario := ValidatedCodiceDestinatario(CodiceDestinatario);
        if (PecDestinatario <> '') and (CodiceDestinatario <> NoSdiCodeTok) then
            Error(PecNotAllowedErr, NoSdiCodeTok, CodiceDestinatario);

        ProgressivoMgt.GetTransmitter(IdPaese, IdCodice);
        CompanyInformation.Get();

        DatiTrasmissione := AddGroup(Header, DatiTrasmissioneNameTok);

        IdTrasmittente := AddGroup(DatiTrasmissione, 'IdTrasmittente');
        AddRequiredText(IdTrasmittente, 'IdPaese', IdPaese);
        AddRequiredText(IdTrasmittente, 'IdCodice', CopyStr(IdCodice, 1, 28));

        AddRequiredText(DatiTrasmissione, 'ProgressivoInvio', ProgressivoInvio);
        AddRequiredText(DatiTrasmissione, 'FormatoTrasmissione', DocumentVersione);
        AddRequiredText(DatiTrasmissione, 'CodiceDestinatario', CodiceDestinatario);

        AddContattiTrasmittente(DatiTrasmissione, CompanyInformation."Phone No.", CompanyInformation."E-Mail");

        // Last in the sequence, and only meaningful when SdI has no channel code to deliver to.
        if PecDestinatario <> '' then
            if StrLen(PecDestinatario) >= 7 then
                AddText(DatiTrasmissione, 'PECDestinatario', CopyStr(PecDestinatario, 1, 256));
    end;

    /// <summary>
    /// ContattiTrasmittente is optional, so a value that would not survive validation is
    /// better left out than written: Telefono is 5 to 12 characters and Email 7 to 256, and
    /// a company record often carries something shorter that means "not filled in".
    /// </summary>
    local procedure AddContattiTrasmittente(var DatiTrasmissione: XmlElement; Telefono: Text; Email: Text)
    var
        Contatti: XmlElement;
        CleanPhone: Text;
    begin
        CleanPhone := DelChr(Telefono, '<>', ' ');
        if StrLen(CleanPhone) < 5 then
            CleanPhone := '';
        if StrLen(Email) < 7 then
            Email := '';
        if (CleanPhone = '') and (Email = '') then
            exit;

        Contatti := AddGroup(DatiTrasmissione, 'ContattiTrasmittente');
        AddText(Contatti, 'Telefono', CopyStr(CleanPhone, 1, 12));
        AddText(Contatti, 'Email', CopyStr(Email, 1, 256));
    end;

    /// <summary>
    /// CodiceDestinatario is 6 characters for a public administration and 7 for anyone else,
    /// and 0000000 is the placeholder for "no SdI channel, deliver another way". Getting the
    /// length wrong is one of the most common causes of a rejection, so it is checked here
    /// rather than discovered on the receipt.
    /// </summary>
    local procedure ValidatedCodiceDestinatario(CodiceDestinatario: Code[7]): Code[7]
    var
        ExpectedLength: Integer;
    begin
        CodiceDestinatario := UpperCase(DelChr(CodiceDestinatario, '<>', ' '));

        if DocumentVersione = PaVersioneTok then
            ExpectedLength := 6
        else begin
            ExpectedLength := 7;
            if CodiceDestinatario = '' then
                CodiceDestinatario := NoSdiCodeTok;
        end;

        if StrLen(CodiceDestinatario) <> ExpectedLength then
            Error(CodiceDestinatarioLenErr, ExpectedLength, DocumentVersione, CodiceDestinatario);

        exit(CodiceDestinatario);
    end;

    // ------------------------------------------------------------------ whole document

    /// <summary>
    /// Builds the complete FatturaPA document for a posted sales invoice, from its primary key.
    ///
    ///     Manager.BuildFromSalesInvoice('PSI-001');
    ///     Manager.ToTempBlob(TempBlob);
    ///
    /// Returns the ProgressivoInvio it drew, because the file name has to carry the same value
    /// and the document is written before the file exists.
    /// </summary>
    procedure BuildFromSalesInvoice(DocumentNo: Code[20]) ProgressivoInvio: Code[10]
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        Customer: Record Customer;
        VatSummary: Record "FPA VAT Summary Buffer" temporary;
        Body: XmlElement;
        DatiGenerali: XmlElement;
        DatiBeniServizi: XmlElement;
        TotalInclVat: Decimal;
        TotalNet: Decimal;
        SplitPayment: Boolean;
        LineNo: Integer;
    begin
        SalesInvoiceHeader.Get(DocumentNo);
        Customer.Get(SalesInvoiceHeader."Bill-to Customer No.");

        // A first pass over the lines, before anything is written. Split payment is a property
        // of the DOCUMENT, not of the line that carries it: the reversing line has to be found
        // before the other lines are written, because it changes EsigibilitaIVA on all of them.
        SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        SalesInvoiceLine.SetFilter(Type, '<>%1', SalesInvoiceLine.Type::" ");
        if SalesInvoiceLine.FindSet() then
            repeat
                if IsSplitPaymentLine(SalesInvoiceLine."VAT Bus. Posting Group", SalesInvoiceLine."VAT Prod. Posting Group") then
                    SplitPayment := true
                else begin
                    TotalInclVat += SalesInvoiceLine."Amount Including VAT";
                    TotalNet += SalesInvoiceLine.Amount;
                end;
            until SalesInvoiceLine.Next() = 0;

        ProgressivoInvio := StartDocumentFor(Customer);
        Body := AddBody();

        DatiGenerali := AddGroup(Body, 'DatiGenerali');
        AddDatiGeneraliDocumento(
          DatiGenerali,
          TipoDocumento(SalesInvoiceHeader."Fattura Document Type", InvoiceTipoDocumentoTok),
          SalesInvoiceHeader."Currency Code", DocumentDate(SalesInvoiceHeader."Document Date", SalesInvoiceHeader."Posting Date"),
          SalesInvoiceHeader."No.", SalesInvoiceHeader."Fattura Stamp", SalesInvoiceHeader."Fattura Stamp Amount",
          TotalInclVat);
        AddDatiOrdineAcquisto(
          DatiGenerali, SalesInvoiceHeader."Customer Purchase Order No.", SalesInvoiceHeader."Your Reference",
          SalesInvoiceHeader."No.", SalesInvoiceHeader."Fattura Project Code", SalesInvoiceHeader."Fattura Tender Code");

        DatiBeniServizi := AddGroup(Body, 'DatiBeniServizi');
        if SalesInvoiceLine.FindSet() then
            repeat
                // The reversing line is bookkeeping, not something that was sold. FatturaPA
                // expresses split payment with EsigibilitaIVA, so writing the line as well
                // would deduct the VAT a second time.
                if not IsSplitPaymentLine(SalesInvoiceLine."VAT Bus. Posting Group", SalesInvoiceLine."VAT Prod. Posting Group") then begin
                    LineNo += 1;
                    AddDettaglioLinee(
                      DatiBeniServizi, LineNo, SalesInvoiceLine.Description, SalesInvoiceLine.Quantity,
                      SalesInvoiceLine."Unit of Measure", SalesInvoiceLine."Unit Price", SalesInvoiceLine.Amount,
                      SalesInvoiceLine."VAT %", SalesInvoiceHeader."Prices Including VAT",
                      SalesInvoiceLine."VAT Bus. Posting Group", SalesInvoiceLine."VAT Prod. Posting Group");
                    AccumulateRiepilogo(
                      VatSummary, LineNo, SalesInvoiceLine."VAT %", SalesInvoiceLine.Amount,
                      SalesInvoiceLine."Amount Including VAT" - SalesInvoiceLine.Amount,
                      SalesInvoiceLine."VAT Bus. Posting Group", SalesInvoiceLine."VAT Prod. Posting Group",
                      SalesInvoiceLine."VAT Identifier", SplitPayment);
                end;
            until SalesInvoiceLine.Next() = 0;
        AddDatiRiepilogo(DatiBeniServizi, VatSummary);

        AddDatiPagamento(
          Body, SalesInvoiceHeader."Payment Terms Code", SalesInvoiceHeader."Payment Method Code",
          Enum::"FPA Source Doc. Type"::"Sales Invoice", SalesInvoiceHeader."No.",
          SalesInvoiceHeader."Bill-to Customer No.", SalesInvoiceHeader."Due Date",
          PayableAmount(TotalInclVat, TotalNet, SplitPayment), SalesInvoiceHeader."Bank Account");
    end;

    /// <summary>
    /// Same for a posted credit memo. The only real differences are TD04 instead of TD01 and
    /// DatiFattureCollegate, which points back at the invoice being corrected.
    /// </summary>
    procedure BuildFromSalesCrMemo(DocumentNo: Code[20]) ProgressivoInvio: Code[10]
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        Customer: Record Customer;
        VatSummary: Record "FPA VAT Summary Buffer" temporary;
        Body: XmlElement;
        DatiGenerali: XmlElement;
        DatiBeniServizi: XmlElement;
        TotalInclVat: Decimal;
        TotalNet: Decimal;
        SplitPayment: Boolean;
        LineNo: Integer;
    begin
        SalesCrMemoHeader.Get(DocumentNo);
        Customer.Get(SalesCrMemoHeader."Bill-to Customer No.");

        SalesCrMemoLine.SetRange("Document No.", SalesCrMemoHeader."No.");
        SalesCrMemoLine.SetFilter(Type, '<>%1', SalesCrMemoLine.Type::" ");
        if SalesCrMemoLine.FindSet() then
            repeat
                if IsSplitPaymentLine(SalesCrMemoLine."VAT Bus. Posting Group", SalesCrMemoLine."VAT Prod. Posting Group") then
                    SplitPayment := true
                else begin
                    TotalInclVat += SalesCrMemoLine."Amount Including VAT";
                    TotalNet += SalesCrMemoLine.Amount;
                end;
            until SalesCrMemoLine.Next() = 0;

        ProgressivoInvio := StartDocumentFor(Customer);
        Body := AddBody();

        DatiGenerali := AddGroup(Body, 'DatiGenerali');
        AddDatiGeneraliDocumento(
          DatiGenerali,
          TipoDocumento(SalesCrMemoHeader."Fattura Document Type", CrMemoTipoDocumentoTok),
          SalesCrMemoHeader."Currency Code", DocumentDate(SalesCrMemoHeader."Document Date", SalesCrMemoHeader."Posting Date"),
          SalesCrMemoHeader."No.", SalesCrMemoHeader."Fattura Stamp", SalesCrMemoHeader."Fattura Stamp Amount",
          TotalInclVat);
        AddDatiOrdineAcquisto(
          DatiGenerali, '', SalesCrMemoHeader."Your Reference", '',
          SalesCrMemoHeader."Fattura Project Code", SalesCrMemoHeader."Fattura Tender Code");
        AddDatiFattureCollegate(DatiGenerali, SalesCrMemoHeader."Applies-to Doc. No.");

        DatiBeniServizi := AddGroup(Body, 'DatiBeniServizi');
        if SalesCrMemoLine.FindSet() then
            repeat
                if not IsSplitPaymentLine(SalesCrMemoLine."VAT Bus. Posting Group", SalesCrMemoLine."VAT Prod. Posting Group") then begin
                    LineNo += 1;
                    AddDettaglioLinee(
                      DatiBeniServizi, LineNo, SalesCrMemoLine.Description, SalesCrMemoLine.Quantity,
                      SalesCrMemoLine."Unit of Measure", SalesCrMemoLine."Unit Price", SalesCrMemoLine.Amount,
                      SalesCrMemoLine."VAT %", SalesCrMemoHeader."Prices Including VAT",
                      SalesCrMemoLine."VAT Bus. Posting Group", SalesCrMemoLine."VAT Prod. Posting Group");
                    AccumulateRiepilogo(
                      VatSummary, LineNo, SalesCrMemoLine."VAT %", SalesCrMemoLine.Amount,
                      SalesCrMemoLine."Amount Including VAT" - SalesCrMemoLine.Amount,
                      SalesCrMemoLine."VAT Bus. Posting Group", SalesCrMemoLine."VAT Prod. Posting Group",
                      SalesCrMemoLine."VAT Identifier", SplitPayment);
                end;
            until SalesCrMemoLine.Next() = 0;
        AddDatiRiepilogo(DatiBeniServizi, VatSummary);

        AddDatiPagamento(
          Body, SalesCrMemoHeader."Payment Terms Code", SalesCrMemoHeader."Payment Method Code",
          Enum::"FPA Source Doc. Type"::"Sales Credit Memo", SalesCrMemoHeader."No.",
          SalesCrMemoHeader."Bill-to Customer No.", SalesCrMemoHeader."Due Date",
          PayableAmount(TotalInclVat, TotalNet, SplitPayment), SalesCrMemoHeader."Bank Account");
    end;

    /// <summary>
    /// Everything the two document types share: the root, the header, and the two parties.
    /// Returns the ProgressivoInvio drawn for this document.
    /// </summary>
    local procedure StartDocumentFor(var Customer: Record Customer) ProgressivoInvio: Code[10]
    var
        ProgressivoMgt: Codeunit "FPA Progressivo Mgt.";
        Header: XmlElement;
    begin
        // FPA12 for a public administration, FPR12 for everyone else. It decides both the
        // root's versione attribute and how long CodiceDestinatario has to be, so it is settled
        // before anything is written.
        if Customer.IsPublicCompany() then
            NewDocument(PaVersioneTok)
        else
            NewDocument(DefaultVersioneTok);

        // A drawn progressive is never given back - NumberSequence hands values out outside
        // the transaction on purpose - so a dry run has to be able to supply its own instead of
        // burning a real one on a document nobody is going to send.
        if ForcedProgressivo <> '' then
            ProgressivoInvio := ForcedProgressivo
        else
            ProgressivoInvio := ProgressivoMgt.NextProgressivo();

        Header := AddHeader();
        AddDatiTrasmissione(Header, ProgressivoInvio, CodiceDestinatarioOf(Customer), PecDestinatarioOf(Customer));
        AddCedentePrestatore(Header);
        AddCessionarioCommittente(Header, Customer);
    end;

    // ------------------------------------------------------------------ 2.1 DatiGenerali

    local procedure AddDatiGeneraliDocumento(var DatiGenerali: XmlElement; TipoDoc: Code[20]; CurrencyCode: Code[10]; DocumentDateValue: Date; DocumentNo: Code[20]; Stamp: Boolean; StampAmount: Decimal; TotalAmount: Decimal)
    var
        DatiGeneraliDocumento: XmlElement;
        DatiBollo: XmlElement;
    begin
        DatiGeneraliDocumento := AddGroup(DatiGenerali, 'DatiGeneraliDocumento');
        AddRequiredText(DatiGeneraliDocumento, 'TipoDocumento', TipoDoc);
        AddRequiredText(DatiGeneraliDocumento, 'Divisa', Divisa(CurrencyCode));
        AddDate(DatiGeneraliDocumento, 'Data', DocumentDateValue);
        AddRequiredText(DatiGeneraliDocumento, 'Numero', DocumentNo);

        if Stamp then begin
            DatiBollo := AddGroup(DatiGeneraliDocumento, 'DatiBollo');
            AddRequiredText(DatiBollo, 'BolloVirtuale', BolloVirtualeTok);
            if StampAmount <> 0 then
                AddDecimal(DatiBollo, 'ImportoBollo', StampAmount, 2);
        end;

        // No header-level ScontoMaggiorazione on purpose. The invoice discount is already
        // inside every line's PrezzoTotale - Business Central posts it there - so repeating it
        // here would subtract it twice and break the document total.
        AddDecimal(DatiGeneraliDocumento, 'ImportoTotaleDocumento', TotalAmount, 2);
    end;

    /// <summary>
    /// DatiOrdineAcquisto exists mainly to carry CUP and CIG, which a public administration
    /// will not pay an invoice without. IdDocumento is mandatory inside the block, so when the
    /// customer gave no order number the document's own number is used rather than dropping
    /// codes the invoice cannot be paid without.
    /// </summary>
    local procedure AddDatiOrdineAcquisto(var DatiGenerali: XmlElement; CustomerOrderNo: Text; YourReference: Text; FallbackDocumentNo: Code[20]; Cup: Code[15]; Cig: Code[15])
    var
        DatiOrdineAcquisto: XmlElement;
        IdDocumento: Text;
    begin
        if (CustomerOrderNo = '') and (Cup = '') and (Cig = '') then
            exit;

        IdDocumento := CustomerOrderNo;
        if IdDocumento = '' then
            IdDocumento := YourReference;
        if IdDocumento = '' then
            IdDocumento := FallbackDocumentNo;
        if IdDocumento = '' then
            exit;

        DatiOrdineAcquisto := AddGroup(DatiGenerali, 'DatiOrdineAcquisto');
        AddRequiredText(DatiOrdineAcquisto, 'IdDocumento', CopyStr(IdDocumento, 1, 20));
        AddText(DatiOrdineAcquisto, 'CodiceCUP', Cup);
        AddText(DatiOrdineAcquisto, 'CodiceCIG', Cig);
    end;

    /// <summary>
    /// A credit memo has to say which invoice it corrects, or the recipient cannot match it.
    /// </summary>
    local procedure AddDatiFattureCollegate(var DatiGenerali: XmlElement; AppliesToDocNo: Code[20])
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        DatiFattureCollegate: XmlElement;
    begin
        if AppliesToDocNo = '' then
            exit;

        DatiFattureCollegate := AddGroup(DatiGenerali, 'DatiFattureCollegate');
        AddRequiredText(DatiFattureCollegate, 'IdDocumento', AppliesToDocNo);
        if SalesInvoiceHeader.Get(AppliesToDocNo) then
            AddDate(DatiFattureCollegate, 'Data', DocumentDate(SalesInvoiceHeader."Document Date", SalesInvoiceHeader."Posting Date"));
    end;

    // ------------------------------------------------------------------ 2.2 DatiBeniServizi

    /// <summary>
    /// One DettaglioLinee, in schema order:
    ///
    ///     NumeroLinea, Descrizione, Quantita, UnitaMisura, PrezzoUnitario,
    ///     ScontoMaggiorazione, PrezzoTotale, AliquotaIVA, Natura
    ///
    /// PrezzoTotale is the line's posted net amount, discounts and all. The discount is then
    /// expressed BACKWARDS - as the per-unit difference between quantity x unit price and that
    /// amount - so that PrezzoUnitario, Quantita, ScontoMaggiorazione and PrezzoTotale are
    /// arithmetically consistent whatever combination of line and invoice discount produced
    /// them. Computing it forwards from the discount percentages does not survive rounding.
    /// </summary>
    local procedure AddDettaglioLinee(var DatiBeniServizi: XmlElement; LineNo: Integer; Description: Text; Quantity: Decimal; UnitOfMeasure: Text; UnitPrice: Decimal; NetAmount: Decimal; VatPct: Decimal; PricesIncludingVAT: Boolean; VatBusGroup: Code[20]; VatProdGroup: Code[20])
    var
        DettaglioLinee: XmlElement;
        ScontoMaggiorazione: XmlElement;
        DiscountPerUnit: Decimal;
        NaturaCode: Code[4];
        LineDescriptionMissingErr: Label 'Line %1 has no description. FatturaPA requires one on every line.', Comment = '%1 = line number';
    begin
        if Description = '' then
            Error(LineDescriptionMissingErr, LineNo);

        // A VAT-inclusive price list is a presentation choice; FatturaPA amounts are always net.
        if PricesIncludingVAT and (VatPct <> 0) then
            UnitPrice := UnitPrice / (1 + VatPct / 100);
        // Rounded here, not only on the way out, so the discount below is computed from the
        // same number that ends up in PrezzoUnitario.
        UnitPrice := Round(UnitPrice, 0.00000001);

        DettaglioLinee := AddGroup(DatiBeniServizi, 'DettaglioLinee');
        AddInteger(DettaglioLinee, 'NumeroLinea', LineNo);
        AddRequiredText(DettaglioLinee, 'Descrizione', CopyStr(Description, 1, 1000));

        if Quantity > 0 then begin
            AddText(DettaglioLinee, 'Quantita', FormatQuantity(Quantity));
            AddText(DettaglioLinee, 'UnitaMisura', CopyStr(UnitOfMeasure, 1, 10));
        end else
            // No quantity to divide by - a service line, or a negative one. The whole amount
            // becomes the unit price, which is what keeps PrezzoUnitario mandatory and true.
            UnitPrice := NetAmount;

        AddText(DettaglioLinee, 'PrezzoUnitario', FormatQuantity(UnitPrice));

        if Quantity > 0 then begin
            DiscountPerUnit := Round((Quantity * UnitPrice - NetAmount) / Quantity, 0.00000001);
            if DiscountPerUnit <> 0 then begin
                ScontoMaggiorazione := AddGroup(DettaglioLinee, 'ScontoMaggiorazione');
                if DiscountPerUnit > 0 then
                    AddRequiredText(ScontoMaggiorazione, 'Tipo', ScontoTok)
                else
                    AddRequiredText(ScontoMaggiorazione, 'Tipo', MaggiorazioneTok);
                AddText(ScontoMaggiorazione, 'Importo', FormatQuantity(Abs(DiscountPerUnit)));
            end;
        end;

        AddDecimal(DettaglioLinee, 'PrezzoTotale', NetAmount, 2);
        AddDecimal(DettaglioLinee, 'AliquotaIVA', VatPct, 2);

        // Natura says WHY there is no VAT. Without it a zero rate is rejected.
        if VatPct = 0 then begin
            NaturaCode := VatTransactionNature(VatBusGroup, VatProdGroup);
            AddRequiredText(DettaglioLinee, 'Natura', NaturaCode);
        end;
    end;

    local procedure AccumulateRiepilogo(var VatSummary: Record "FPA VAT Summary Buffer" temporary; LineNo: Integer; VatPct: Decimal; Base: Decimal; Tax: Decimal; VatBusGroup: Code[20]; VatProdGroup: Code[20]; VatIdentifier: Code[20]; SplitPayment: Boolean)
    var
        VATIdentifierRec: Record "VAT Identifier";
        NaturaCode: Code[4];
        RiferimentoNormativo: Text;
    begin
        if VatPct = 0 then begin
            NaturaCode := VatTransactionNature(VatBusGroup, VatProdGroup);
            // The wording of the exemption, which the customer's accountant needs to see.
            if VATIdentifierRec.Get(VatIdentifier) then
                RiferimentoNormativo := VATIdentifierRec.Description;
        end;

        VatSummary.Accumulate(
          VatPct, NaturaCode, EsigibilitaIVA(VatBusGroup, VatProdGroup, SplitPayment), Base, Tax, RiferimentoNormativo, LineNo);
    end;

    local procedure AddDatiRiepilogo(var DatiBeniServizi: XmlElement; var VatSummary: Record "FPA VAT Summary Buffer" temporary)
    var
        DatiRiepilogo: XmlElement;
        AliquotaIVA: Text;
    begin
        VatSummary.Reset();
        VatSummary.SetCurrentKey("Sort Order");
        if not VatSummary.FindSet() then
            exit;

        repeat
            // Formatted once and reused: RiferimentoNormativo quotes the rate back, and the two
            // must read identically. Formatting it twice is how they drift apart.
            AliquotaIVA := FormatDecimal(VatSummary."VAT %", 2);

            DatiRiepilogo := AddGroup(DatiBeniServizi, 'DatiRiepilogo');
            AddText(DatiRiepilogo, 'AliquotaIVA', AliquotaIVA);
            AddText(DatiRiepilogo, 'Natura', VatSummary.Natura);
            AddDecimal(DatiRiepilogo, 'ImponibileImporto', VatSummary."Imponibile Importo", 2);
            AddDecimal(DatiRiepilogo, 'Imposta', VatSummary.Imposta, 2);
            AddText(DatiRiepilogo, 'EsigibilitaIVA', VatSummary."Esigibilita IVA");
            AddText(DatiRiepilogo, 'RiferimentoNormativo', RiferimentoNormativo(VatSummary, AliquotaIVA));
        until VatSummary.Next() = 0;
    end;

    /// <summary>
    /// The wording that goes with the summary block.
    ///
    /// Under split payment it states the rate the buyer pays straight to the treasury:
    /// ALIQUOTA IVA 22.00 SPLIT PAYMENT. The rate is the string ALREADY written into
    /// AliquotaIVA rather than the decimal formatted again, so the sentence cannot end up
    /// quoting a different number from the element two lines above it.
    ///
    /// A zero rate keeps the description of its VAT identifier instead. There the wording is
    /// the legal ground for charging no VAT at all - which is what the recipient's accountant
    /// needs - and overwriting it would be losing the more important of the two.
    /// </summary>
    local procedure RiferimentoNormativo(var VatSummary: Record "FPA VAT Summary Buffer" temporary; AliquotaIVA: Text): Text
    begin
        if (VatSummary."Esigibilita IVA" = SplitPaymentTok) and (VatSummary."VAT %" <> 0) then
            exit(StrSubstNo(SplitPaymentNormativoTok, AliquotaIVA));
        exit(CopyStr(VatSummary."Riferimento Normativo", 1, 100));
    end;

    // ------------------------------------------------------------------ 2.4 DatiPagamento

    /// <summary>
    /// The payment schedule, taken from the customer ledger entries the posting produced, so
    /// instalments come out as several DettaglioPagamento with their own due dates. When there
    /// are none - the entry is already closed and cleared, or the document was posted without
    /// payment terms - it falls back to one payment for the whole amount.
    ///
    /// The whole block is optional, and ModalitaPagamento is mandatory inside it, so a payment
    /// method with no FatturaPA code means the block is left out rather than written invalid.
    /// </summary>
    local procedure AddDatiPagamento(var Body: XmlElement; PaymentTermsCode: Code[10]; PaymentMethodCode: Code[10]; SourceDocType: Enum "FPA Source Doc. Type"; DocumentNo: Code[20]; CustomerNo: Code[20]; DueDate: Date; TotalAmount: Decimal; BankAccountNo: Code[20])
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        PaymentMethod: Record "Payment Method";
        PaymentTerms: Record "Payment Terms";
        DatiPagamento: XmlElement;
        ModalitaPagamento: Code[4];
        CondizioniPagamento: Code[4];
        Iban: Code[50];
        Instalments: Integer;
    begin
        if not PaymentMethod.Get(PaymentMethodCode) then
            exit;
        ModalitaPagamento := PaymentMethod."Fattura PA Payment Method";
        if ModalitaPagamento = '' then
            exit;

        Iban := IbanFor(BankAccountNo);

        FindPaymentEntries(CustLedgerEntry, SourceDocType, DocumentNo, CustomerNo);
        Instalments := CustLedgerEntry.Count();

        if PaymentTerms.Get(PaymentTermsCode) then
            CondizioniPagamento := PaymentTerms."Fattura Payment Terms Code";
        if CondizioniPagamento = '' then
            // TP01 is "in instalments", TP02 "in full". Deriving it from how many due dates
            // there actually are beats leaving a mandatory element empty.
            if Instalments > 1 then
                CondizioniPagamento := RateTok
            else
                CondizioniPagamento := CompletoTok;

        DatiPagamento := AddGroup(Body, 'DatiPagamento');
        AddRequiredText(DatiPagamento, 'CondizioniPagamento', CondizioniPagamento);

        if Instalments = 0 then begin
            AddDettaglioPagamento(DatiPagamento, ModalitaPagamento, DueDate, TotalAmount, Iban);
            exit;
        end;

        CustLedgerEntry.FindSet();
        repeat
            CustLedgerEntry.CalcFields(Amount);
            AddDettaglioPagamento(
              DatiPagamento, ModalitaPagamento, CustLedgerEntry."Due Date", Abs(CustLedgerEntry.Amount), Iban);
        until CustLedgerEntry.Next() = 0;
    end;

    local procedure AddDettaglioPagamento(var DatiPagamento: XmlElement; ModalitaPagamento: Code[4]; DueDate: Date; Amount: Decimal; Iban: Code[50])
    var
        DettaglioPagamento: XmlElement;
    begin
        DettaglioPagamento := AddGroup(DatiPagamento, 'DettaglioPagamento');
        AddRequiredText(DettaglioPagamento, 'ModalitaPagamento', ModalitaPagamento);
        AddDate(DettaglioPagamento, 'DataScadenzaPagamento', DueDate);
        AddDecimal(DettaglioPagamento, 'ImportoPagamento', Amount, 2);
        AddText(DettaglioPagamento, 'IBAN', Iban);
    end;

    local procedure FindPaymentEntries(var CustLedgerEntry: Record "Cust. Ledger Entry"; SourceDocType: Enum "FPA Source Doc. Type"; DocumentNo: Code[20]; CustomerNo: Code[20])
    begin
        // No SetCurrentKey: the due dates do not have to come out in order, and asking for a
        // key that does not start with the field would fail at runtime.
        CustLedgerEntry.SetRange("Document No.", DocumentNo);
        CustLedgerEntry.SetRange("Customer No.", CustomerNo);
        case SourceDocType of
            SourceDocType::"Sales Invoice":
                CustLedgerEntry.SetRange("Document Type", CustLedgerEntry."Document Type"::Invoice);
            SourceDocType::"Sales Credit Memo":
                CustLedgerEntry.SetRange("Document Type", CustLedgerEntry."Document Type"::"Credit Memo");
        end;
    end;

    /// <summary>
    /// The IBAN the customer should pay into: the bank account named on the document if there
    /// is one, otherwise the company's own.
    /// </summary>
    local procedure IbanFor(BankAccountNo: Code[20]): Code[50]
    var
        BankAccount: Record "Bank Account";
        CompanyInformation: Record "Company Information";
    begin
        if BankAccountNo <> '' then
            if BankAccount.Get(BankAccountNo) then
                if BankAccount.IBAN <> '' then
                    exit(BankAccount.IBAN);

        CompanyInformation.Get();
        exit(CompanyInformation.IBAN);
    end;

    // ------------------------------------------------------------------ document helpers

    local procedure TipoDocumento(FatturaDocumentType: Code[20]; DefaultType: Text): Code[20]
    begin
        if FatturaDocumentType <> '' then
            exit(FatturaDocumentType);
        exit(CopyStr(DefaultType, 1, 20));
    end;

    /// <summary>
    /// Divisa is the currency the amounts are expressed in - the document's own, or the local
    /// one when the document has none.
    /// </summary>
    local procedure Divisa(CurrencyCode: Code[10]): Code[10]
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
    begin
        if CurrencyCode <> '' then
            exit(CurrencyCode);
        GeneralLedgerSetup.Get();
        exit(GeneralLedgerSetup."LCY Code");
    end;

    local procedure DocumentDate(DocumentDateValue: Date; PostingDate: Date): Date
    begin
        if DocumentDateValue <> 0D then
            exit(DocumentDateValue);
        exit(PostingDate);
    end;

    /// <summary>
    /// The exemption code set up on the VAT posting group combination.
    /// </summary>
    local procedure VatTransactionNature(VatBusGroup: Code[20]; VatProdGroup: Code[20]): Code[4]
    var
        VATPostingSetup: Record "VAT Posting Setup";
        NaturaMissingErr: Label 'VAT posting setup %1 / %2 has a zero rate but no VAT Transaction Nature. FatturaPA needs the N-code that explains why no VAT is charged.', Comment = '%1 = VAT bus. posting group, %2 = VAT prod. posting group';
    begin
        if not VATPostingSetup.Get(VatBusGroup, VatProdGroup) then
            Error(NaturaMissingErr, VatBusGroup, VatProdGroup);
        if VATPostingSetup."VAT Transaction Nature" = '' then
            Error(NaturaMissingErr, VatBusGroup, VatProdGroup);
        exit(CopyStr(VATPostingSetup."VAT Transaction Nature", 1, 4));
    end;

    /// <summary>
    /// When the seller actually owes the VAT: S when the buyer pays it straight to the treasury
    /// under split payment, D when it becomes due only on payment, I in the ordinary case.
    /// </summary>
    local procedure EsigibilitaIVA(VatBusGroup: Code[20]; VatProdGroup: Code[20]; SplitPayment: Boolean): Code[1]
    var
        VATPostingSetup: Record "VAT Posting Setup";
    begin
        // Decided by the DOCUMENT, not by the line. Under split payment the customer pays the
        // VAT straight to the treasury for the whole invoice, so every DatiRiepilogo carries S -
        // including the ordinary goods lines, whose own posting setup knows nothing about it.
        if SplitPayment then
            exit(SplitPaymentTok);

        if not VATPostingSetup.Get(VatBusGroup, VatProdGroup) then
            exit(ImmediataTok);

        if VATPostingSetup."Unrealized VAT Type" <> VATPostingSetup."Unrealized VAT Type"::" " then
            exit(DifferitaTok);

        exit(ImmediataTok);
    end;

    /// <summary>
    /// True for the line Business Central generates to reverse the VAT under split payment
    /// (art. 17-ter): a Full VAT line whose posting setup names the groups it reverses.
    ///
    /// Same test the standard Italian export makes. Full VAT on its own is not enough - it is
    /// also how a VAT-only invoice is posted - so the reversed groups are what identify it.
    /// </summary>
    local procedure IsSplitPaymentLine(VatBusGroup: Code[20]; VatProdGroup: Code[20]): Boolean
    var
        VATPostingSetup: Record "VAT Posting Setup";
        ReversedVATPostingSetup: Record "VAT Posting Setup";
    begin
        if not VATPostingSetup.Get(VatBusGroup, VatProdGroup) then
            exit(false);
        if VATPostingSetup."VAT Calculation Type" <> VATPostingSetup."VAT Calculation Type"::"Full VAT" then
            exit(false);
        exit(
          ReversedVATPostingSetup.Get(
            VATPostingSetup."Reversed VAT Bus. Post. Group", VATPostingSetup."Reversed VAT Prod. Post. Group"));
    end;

    /// <summary>
    /// What the customer actually has to pay.
    ///
    /// Normally the document total. Under split payment the customer pays the taxable amount
    /// only and settles the VAT with the treasury directly, so DatiPagamento must show the net -
    /// otherwise they are being asked for the VAT twice.
    ///
    /// ImportoTotaleDocumento stays GROSS either way: it states what the invoice is worth, not
    /// what is being collected, and that is what the standard export writes too.
    /// </summary>
    local procedure PayableAmount(TotalInclVat: Decimal; TotalNet: Decimal; SplitPayment: Boolean): Decimal
    begin
        if SplitPayment then
            exit(TotalNet);
        exit(TotalInclVat);
    end;

    // ------------------------------------------------------------------ 1.2 CedentePrestatore

    /// <summary>
    /// Writes &lt;CedentePrestatore&gt; - the seller - entirely from Company Information:
    ///
    ///     DatiAnagrafici ( IdFiscaleIVA ( IdPaese, IdCodice ), CodiceFiscale,
    ///                      Anagrafica ( Denominazione ), RegimeFiscale )
    ///     Sede ( Indirizzo, CAP, Comune, Provincia, Nazione )
    ///     IscrizioneREA ( Ufficio, NumeroREA, CapitaleSociale, SocioUnico, StatoLiquidazione )
    ///     Contatti ( Telefono, Fax, Email )
    ///
    /// The field-to-element mapping is the same one the standard Italian export uses, so a
    /// company already set up for FatturaPA needs nothing new configured.
    /// </summary>
    procedure AddCedentePrestatore(var Header: XmlElement) CedentePrestatore: XmlElement
    var
        CompanyInformation: Record "Company Information";
        ProgressivoMgt: Codeunit "FPA Progressivo Mgt.";
        DatiAnagrafici: XmlElement;
        IdFiscaleIVA: XmlElement;
        Anagrafica: XmlElement;
        IdPaese: Code[10];
        IdCodice: Text;
    begin
        TestStarted();
        CompanyInformation.Get();
        CompanyInformation.TestField(Name);

        CedentePrestatore := AddGroup(Header, 'CedentePrestatore');

        DatiAnagrafici := AddGroup(CedentePrestatore, 'DatiAnagrafici');

        // Same derivation as IdTrasmittente and as the file name. The seller's VAT number is
        // the one thing all three have to agree on.
        ProgressivoMgt.GetTransmitter(IdPaese, IdCodice);
        IdFiscaleIVA := AddGroup(DatiAnagrafici, 'IdFiscaleIVA');
        AddRequiredText(IdFiscaleIVA, 'IdPaese', IdPaese);
        AddRequiredText(IdFiscaleIVA, 'IdCodice', CopyStr(IdCodice, 1, 28));

        AddText(DatiAnagrafici, 'CodiceFiscale', CleanCode(CompanyInformation."Fiscal Code"));

        Anagrafica := AddGroup(DatiAnagrafici, 'Anagrafica');
        AddRequiredText(Anagrafica, 'Denominazione', CopyStr(CompanyInformation.Name, 1, DenominazioneMaxLength()));

        // RegimeFiscale closes DatiAnagrafici - it comes AFTER Anagrafica, not inside it.
        AddRequiredText(DatiAnagrafici, 'RegimeFiscale', RegimeFiscale(CompanyInformation));

        AddSede(
          CedentePrestatore, 'Sede', CompanyInformation.Address, CompanyInformation."Post Code",
          CompanyInformation.City, CompanyInformation.County, CompanyInformation."Country/Region Code");

        AddIscrizioneREA(CedentePrestatore, CompanyInformation);
        AddContatti(
          CedentePrestatore, CompanyInformation."Phone No.", CompanyInformation."Fax No.",
          CompanyInformation."E-Mail");
    end;

    /// <summary>
    /// RF01 for the ordinary regime, RF19 for the flat rate one, and so on. Business Central
    /// keeps only the two digits, in Company Information."Company Type".
    /// </summary>
    local procedure RegimeFiscale(var CompanyInformation: Record "Company Information"): Text
    var
        CompanyType: Text;
    begin
        CompanyType := DelChr(CompanyInformation."Company Type", '<>', ' ');
        if CompanyType = '' then
            exit(DefaultRegimeFiscaleTok);
        while StrLen(CompanyType) < 2 do
            CompanyType := '0' + CompanyType;
        exit('RF' + CopyStr(CompanyType, 1, 2));
    end;

    /// <summary>
    /// IscrizioneREA is optional as a whole, but Ufficio, NumeroREA and StatoLiquidazione are
    /// all mandatory once it is there. A half-filled registration would therefore be REJECTED,
    /// where leaving the block out is perfectly valid - so it is written only when complete.
    /// </summary>
    local procedure AddIscrizioneREA(var CedentePrestatore: XmlElement; var CompanyInformation: Record "Company Information")
    var
        IscrizioneREA: XmlElement;
        Ufficio: Text;
        NumeroREA: Text;
    begin
        Ufficio := UpperCase(DelChr(CompanyInformation."Registry Office Province", '<>', ' '));
        NumeroREA := DelChr(CompanyInformation."REA No.", '<>', ' ');

        // Ufficio is the province code of the chamber of commerce: exactly two letters.
        if (NumeroREA = '') or (StrLen(Ufficio) <> 2) then
            exit;

        IscrizioneREA := AddGroup(CedentePrestatore, 'IscrizioneREA');
        AddRequiredText(IscrizioneREA, 'Ufficio', Ufficio);
        AddRequiredText(IscrizioneREA, 'NumeroREA', CopyStr(NumeroREA, 1, 20));

        if CompanyInformation."Paid-In Capital" <> 0 then
            AddDecimal(IscrizioneREA, 'CapitaleSociale', CompanyInformation."Paid-In Capital", 2);

        case CompanyInformation."Shareholder Status" of
            CompanyInformation."Shareholder Status"::"One Shareholder":
                AddText(IscrizioneREA, 'SocioUnico', SocioUnicoTok);
            CompanyInformation."Shareholder Status"::"Multiple Shareholders":
                AddText(IscrizioneREA, 'SocioUnico', SociMultipliTok);
        end;

        // Blank means "nobody said", and a company that is not being wound up is the safe
        // reading of that.
        if CompanyInformation."Liquidation Status" = CompanyInformation."Liquidation Status"::"In Liquidation" then
            AddRequiredText(IscrizioneREA, 'StatoLiquidazione', InLiquidazioneTok)
        else
            AddRequiredText(IscrizioneREA, 'StatoLiquidazione', NonInLiquidazioneTok);
    end;

    /// <summary>
    /// Contatti of the seller. Optional, and skipped when nothing survives the length rules.
    /// </summary>
    local procedure AddContatti(var CedentePrestatore: XmlElement; Telefono: Text; Fax: Text; Email: Text)
    var
        Contatti: XmlElement;
    begin
        Telefono := ValidatedPhone(Telefono);
        Fax := ValidatedPhone(Fax);
        if StrLen(Email) < 7 then
            Email := '';
        if (Telefono = '') and (Fax = '') and (Email = '') then
            exit;

        Contatti := AddGroup(CedentePrestatore, 'Contatti');
        AddText(Contatti, 'Telefono', Telefono);
        AddText(Contatti, 'Fax', Fax);
        AddText(Contatti, 'Email', CopyStr(Email, 1, 256));
    end;

    // ------------------------------------------------------------------ 1.4 CessionarioCommittente

    /// <summary>
    /// Writes &lt;CessionarioCommittente&gt; - the buyer - from a Customer:
    ///
    ///     DatiAnagrafici ( IdFiscaleIVA, CodiceFiscale, Anagrafica )
    ///     Sede ( Indirizzo, CAP, Comune, Provincia, Nazione )
    ///
    /// A private individual has no VAT number, so IdFiscaleIVA is left out and CodiceFiscale
    /// carries the identification; a company normally has both. What is NOT allowed is having
    /// neither, and that is checked here rather than left to the receipt.
    /// </summary>
    procedure AddCessionarioCommittente(var Header: XmlElement; Customer: Record Customer) CessionarioCommittente: XmlElement
    var
        CompanyInformation: Record "Company Information";
        DatiAnagrafici: XmlElement;
        IdFiscaleIVA: XmlElement;
        Anagrafica: XmlElement;
        CustomerCountry: Code[10];
        VatNo: Text;
        FiscalCode: Text;
        Identified: Boolean;
        NoIdErr: Label 'Customer %1 has neither a VAT Registration No. nor a Fiscal Code. FatturaPA requires at least one of the two for CessionarioCommittente.', Comment = '%1 = customer no.';
    begin
        TestStarted();
        CompanyInformation.Get();

        CustomerCountry := CountryIso(Customer."Country/Region Code");
        VatNo := CleanCode(Customer."VAT Registration No.");
        VatNo := WithoutCountryPrefix(VatNo, CustomerCountry);
        FiscalCode := CleanCode(Customer."Fiscal Code");

        CessionarioCommittente := AddGroup(Header, 'CessionarioCommittente');
        DatiAnagrafici := AddGroup(CessionarioCommittente, 'DatiAnagrafici');

        // A private individual is identified by the fiscal code alone; some are also flagged
        // with the company VAT number by mistake, and writing it would make them a business.
        if (VatNo <> '') and not Customer."Individual Person" then begin
            IdFiscaleIVA := AddGroup(DatiAnagrafici, 'IdFiscaleIVA');
            AddRequiredText(IdFiscaleIVA, 'IdPaese', CustomerCountry);
            AddRequiredText(IdFiscaleIVA, 'IdCodice', CopyStr(VatNo, 1, 28));
            Identified := true;
        end;

        // An Italian fiscal code on a foreign customer would be nonsense, and the schema
        // pattern would reject it.
        if CustomerCountry = CountryIso(CompanyInformation."Country/Region Code") then
            if FiscalCode <> '' then begin
                AddText(DatiAnagrafici, 'CodiceFiscale', CopyStr(FiscalCode, 1, 16));
                Identified := true;
            end;

        if not Identified then
            Error(NoIdErr, Customer."No.");

        Anagrafica := AddGroup(DatiAnagrafici, 'Anagrafica');
        AddAnagrafica(Anagrafica, Customer."Individual Person", Customer."First Name", Customer."Last Name", Customer.Name);

        AddSede(
          CessionarioCommittente, 'Sede', Customer.Address, Customer."Post Code",
          Customer.City, Customer.County, Customer."Country/Region Code");
    end;

    /// <summary>
    /// Anagrafica is a choice: either Denominazione, or Nome AND Cognome - never a mix, never
    /// both. A customer flagged as an individual but with the name only in the Name field
    /// would otherwise produce an empty Cognome, so it falls back to Denominazione.
    /// </summary>
    local procedure AddAnagrafica(var Anagrafica: XmlElement; IndividualPerson: Boolean; FirstName: Text; LastName: Text; Name: Text)
    begin
        if IndividualPerson and (FirstName <> '') and (LastName <> '') then begin
            AddRequiredText(Anagrafica, 'Nome', CopyStr(FirstName, 1, 60));
            AddRequiredText(Anagrafica, 'Cognome', CopyStr(LastName, 1, 60));
            exit;
        end;
        AddRequiredText(Anagrafica, 'Denominazione', CopyStr(Name, 1, DenominazioneMaxLength()));
    end;

    /// <summary>
    /// CodiceDestinatario for a customer: the PA Code, or 0000000 when there is none, which is
    /// what tells SdI to deliver through the PEC address instead.
    /// </summary>
    procedure CodiceDestinatarioOf(Customer: Record Customer): Code[7]
    var
        PaCode: Code[7];
    begin
        PaCode := UpperCase(DelChr(Customer."PA Code", '<>', ' '));
        if PaCode = '' then
            exit(NoSdiCodeTok);
        exit(PaCode);
    end;

    /// <summary>
    /// PECDestinatario for a customer - only meaningful, and only accepted, alongside 0000000.
    /// </summary>
    procedure PecDestinatarioOf(Customer: Record Customer): Text
    begin
        if CodiceDestinatarioOf(Customer) <> NoSdiCodeTok then
            exit('');
        exit(Customer."PEC E-Mail Address");
    end;

    // ------------------------------------------------------------------ 2. FatturaElettronicaBody

    /// <summary>
    /// Adds one &lt;FatturaElettronicaBody&gt; under the root and returns it.
    ///
    /// Call it once per invoice: a file carries ONE header and N bodies, which is how a single
    /// transmission can hold several invoices to the same customer.
    /// </summary>
    procedure AddBody() Body: XmlElement
    var
        Root: XmlElement;
    begin
        Root := GetRoot();
        Body := AddGroup(Root, BodyNameTok);
    end;

    // ------------------------------------------------------------------ shared address logic

    /// <summary>
    /// Sede, in schema order. Used for both parties, because the type is the same one.
    /// </summary>
    local procedure AddSede(var Parent: XmlElement; Name: Text; Indirizzo: Text; PostCode: Code[20]; Comune: Text; Provincia: Text; CountryRegionCode: Code[10]) Sede: XmlElement
    var
        Nazione: Code[10];
    begin
        Nazione := CountryIso(CountryRegionCode);

        Sede := AddGroup(Parent, Name);
        AddRequiredText(Sede, 'Indirizzo', CopyStr(Indirizzo, 1, 60));
        AddRequiredText(Sede, 'CAP', ValidatedCap(PostCode, Nazione));
        AddRequiredText(Sede, 'Comune', CopyStr(Comune, 1, 60));
        AddText(Sede, 'Provincia', ValidatedProvincia(Provincia, Nazione));
        AddRequiredText(Sede, 'Nazione', Nazione);
    end;

    /// <summary>
    /// The ISO 3166-1 alpha-2 code for a Business Central country code.
    ///
    /// A blank country code means "the company's own country" throughout Business Central -
    /// most Italian customers are entered that way - so it resolves to Company Information
    /// rather than producing an invalid empty Nazione.
    /// </summary>
    local procedure CountryIso(CountryRegionCode: Code[10]): Code[10]
    var
        CompanyInformation: Record "Company Information";
        CountryRegion: Record "Country/Region";
        Result: Code[10];
    begin
        if CountryRegionCode = '' then begin
            CompanyInformation.Get();
            CountryRegionCode := CompanyInformation."Country/Region Code";
        end;

        Result := CountryRegionCode;
        if CountryRegion.Get(CountryRegionCode) then
            if CountryRegion."ISO Code" <> '' then
                Result := CountryRegion."ISO Code";
        exit(UpperCase(Result));
    end;

    /// <summary>
    /// CAP is five digits, always. A foreign address has no Italian postcode, and the agreed
    /// convention - the one the standard export uses - is to write 00000 there.
    /// </summary>
    local procedure ValidatedCap(PostCode: Code[20]; Nazione: Code[10]): Text
    var
        Digits: Text;
        Index: Integer;
        Character: Char;
        ForeignCapTok: Label '00000', Locked = true;
        CapErr: Label 'Post code "%1" is not a valid Italian CAP. FatturaPA needs five digits.', Comment = '%1 = post code';
    begin
        if Nazione <> ItalyIsoTok then
            exit(ForeignCapTok);

        for Index := 1 to StrLen(PostCode) do begin
            Character := PostCode[Index];
            if Character in ['0' .. '9'] then
                Digits += Format(Character);
        end;

        if StrLen(Digits) <> 5 then
            Error(CapErr, PostCode);
        exit(Digits);
    end;

    /// <summary>
    /// Provincia is optional and must be the two-letter code. Business Central's County is a
    /// free-text field that often holds the full name of the province, or nothing at all, so
    /// anything that is not exactly two letters is left out instead of being written wrong.
    /// </summary>
    local procedure ValidatedProvincia(Provincia: Text; Nazione: Code[10]): Text
    begin
        if Nazione <> ItalyIsoTok then
            exit('');
        Provincia := UpperCase(DelChr(Provincia, '<>', ' '));
        if StrLen(Provincia) <> 2 then
            exit('');
        exit(Provincia);
    end;

    /// <summary>
    /// Telefono and Fax are 5 to 12 characters. Separators are not part of that count in
    /// practice, and a number written with them would blow the limit, so they come out.
    /// </summary>
    local procedure ValidatedPhone(Phone: Text): Text
    begin
        Phone := DelChr(Phone, '=', ' -./()');
        if StrLen(Phone) < 5 then
            exit('');
        exit(CopyStr(Phone, 1, 12));
    end;

    /// <summary>
    /// Uppercase, with the punctuation people put in VAT and fiscal codes removed.
    /// </summary>
    local procedure CleanCode(Value: Text): Text
    begin
        exit(DelChr(UpperCase(Value), '=', ' .-/'));
    end;

    /// <summary>
    /// Drops a country prefix repeated inside the number itself, so IT01234567890 entered in
    /// the VAT field of an Italian customer does not become IdPaese=IT IdCodice=IT01234567890.
    /// </summary>
    local procedure WithoutCountryPrefix(Value: Text; CountryIsoCode: Code[10]): Text
    begin
        if CountryIsoCode = '' then
            exit(Value);
        if StrLen(Value) <= StrLen(CountryIsoCode) then
            exit(Value);
        if CopyStr(Value, 1, StrLen(CountryIsoCode)) <> CountryIsoCode then
            exit(Value);
        exit(CopyStr(Value, StrLen(CountryIsoCode) + 1));
    end;

    local procedure DenominazioneMaxLength(): Integer
    begin
        exit(80);
    end;

    // ------------------------------------------------------------------ building

    /// <summary>
    /// Adds an unqualified container element and returns it, so the next level can be hung
    /// off the result:
    ///
    ///     Header := Manager.AddGroup(Manager.GetRoot(), 'FatturaElettronicaHeader');
    ///     Trasm  := Manager.AddGroup(Header, 'DatiTrasmissione');
    ///     Manager.AddText(Trasm, 'ProgressivoInvio', '00001');
    ///
    /// No namespace on purpose - see the note at the top of this codeunit.
    /// </summary>
    procedure AddGroup(var Parent: XmlElement; Name: Text) Child: XmlElement
    begin
        Child := XmlElement.Create(Name);
        Parent.Add(Child);
    end;

    /// <summary>
    /// Adds a leaf element, and SKIPS IT ENTIRELY when the value is blank.
    ///
    /// Most FatturaPA elements are optional, and an empty one is not the same as an absent
    /// one: the schema types have a minLength, so &lt;Elemento/&gt; is rejected where leaving
    /// it out is fine. Callers can therefore map every field unconditionally and let this
    /// decide. Use AddRequiredText where the schema really demands a value.
    /// </summary>
    procedure AddText(var Parent: XmlElement; Name: Text; Value: Text)
    begin
        if Value = '' then
            exit;
        Parent.Add(XmlElement.Create(Name, '', Value));
    end;

    /// <summary>
    /// Same, but a blank value is a bug rather than an omission, so it stops here with a
    /// message naming the element instead of letting SdI reject the file later.
    /// </summary>
    procedure AddRequiredText(var Parent: XmlElement; Name: Text; Value: Text)
    var
        MissingErr: Label 'FatturaPA element %1 is mandatory but no value was supplied.', Comment = '%1 = element name';
    begin
        if Value = '' then
            Error(MissingErr, Name);
        Parent.Add(XmlElement.Create(Name, '', Value));
    end;

    /// <summary>
    /// xs:date, always YYYY-MM-DD. A blank date is skipped.
    /// </summary>
    procedure AddDate(var Parent: XmlElement; Name: Text; Value: Date)
    begin
        if Value = 0D then
            exit;
        // Format 9 is AL's XML format, which for a Date is exactly YYYY-MM-DD.
        AddText(Parent, Name, Format(Value, 0, 9));
    end;

    /// <summary>
    /// A decimal with a fixed number of places and a DOT as the separator, whatever the
    /// user's regional settings say - FatturaPA amounts are xs:decimal, not localised text.
    /// Decimals is 2 for amounts, up to 8 for PrezzoUnitario and Quantita.
    /// </summary>
    procedure AddDecimal(var Parent: XmlElement; Name: Text; Value: Decimal; Decimals: Integer)
    begin
        AddText(Parent, Name, FormatDecimal(Value, Decimals));
    end;

    procedure AddInteger(var Parent: XmlElement; Name: Text; Value: Integer)
    begin
        AddText(Parent, Name, Format(Value, 0, 9));
    end;

    /// <summary>
    /// Exposed on its own because callers often need the formatted string before deciding
    /// whether to emit it at all.
    /// </summary>
    procedure FormatDecimal(Value: Decimal; Decimals: Integer): Text
    var
        FormatTok: Label '<Precision,%1:%1><Standard Format,9>', Locked = true;
    begin
        if Decimals < 2 then
            Decimals := 2;
        // Standard Format 9 is the XML format: '.' as the decimal separator, no thousands
        // separator, no currency symbol. Precision pins the number of places, because
        // FatturaPA wants 2 written out even on a round amount.
        exit(Format(Value, 0, StrSubstNo(FormatTok, Decimals)));
    end;

    /// <summary>
    /// A quantity or a unit price: at least 2 decimals, at most 8, with the zeros nobody needs
    /// trimmed off the end.
    ///
    /// Fixing it at 2 would silently round a quantity of 0.333 and leave PrezzoUnitario x
    /// Quantita no longer equal to PrezzoTotale, which SdI checks. Fixing it at 8 would write
    /// 5.00000000 for five pieces. So the precision follows the number.
    /// </summary>
    procedure FormatQuantity(Value: Decimal): Text
    var
        Result: Text;
        MinLength: Integer;
    begin
        Result := FormatDecimal(Value, 8);

        // Two decimals is the floor: '5.00' must not shrink to '5.'. AL does not short-circuit
        // boolean operators, so the length test alone has to keep the index below valid.
        MinLength := StrPos(Result, '.') + 2;
        if MinLength < 3 then
            exit(Result);

        while (StrLen(Result) > MinLength) and (Result[StrLen(Result)] = '0') do
            Result := CopyStr(Result, 1, StrLen(Result) - 1);
        exit(Result);
    end;

    // ------------------------------------------------------------------ output

    /// <summary>
    /// Serialises the document into a Temp Blob, ready for "FPA Xml File" or a download.
    /// </summary>
    procedure ToTempBlob(var TempBlob: Codeunit "Temp Blob")
    var
        OutStr: OutStream;
    begin
        TestStarted();
        Clear(TempBlob);
        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        XmlDoc.WriteTo(OutStr);
    end;

    /// <summary>
    /// The document as text. Handy in tests and when comparing against a reference file.
    /// </summary>
    procedure ToText() Result: Text
    begin
        TestStarted();
        XmlDoc.WriteTo(Result);
    end;

    local procedure TestStarted()
    begin
        if not DocumentStarted then
            Error(NotStartedErr);
    end;
}
