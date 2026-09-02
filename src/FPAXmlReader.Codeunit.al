namespace ZZSoft.FPA;

using System.Utilities;

codeunit 73000 "FPA Xml Reader"
{
    // Imports an SdI XML file. What happens next depends on what the file IS, which is
    // decided by its name (see codeunit "FPA File Name Parser"):
    //
    //   IT..._HV1GH.xml         invoice  -> 1 "FPA Xml File" + N "FPA Xml File Document"
    //                                       (one per FatturaElettronicaBody)
    //   IT..._HV1GH_RC_003.xml  receipt  -> 1 "FPA Xml File" only, linked to the invoice
    //                                       through "SdI Base Name", no documents
    //
    // Parsing uses only the AL XmlDocument API - no .NET interop, so it runs unchanged on
    // Business Central online.
    //
    // Namespaces: in FatturaPA only the ROOT element is namespace-qualified (prefix p: or ns2:,
    // URI http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2). All descendants are
    // unqualified. XPath expressions below therefore carry the 'a:' prefix on the root only.

    var
        FatturaNsV12Txt: Label 'http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2', Locked = true;
        FatturaNsV11Txt: Label 'http://www.fatturapa.gov.it/sdi/fatturapa/v1.1', Locked = true;
        FatturaNsV10Txt: Label 'http://www.fatturapa.gov.it/sdi/fatturapa/v1.0', Locked = true;
        DsigNsTxt: Label 'http://www.w3.org/2000/09/xmldsig#', Locked = true;
        BodyElementNameTxt: Label 'FatturaElettronicaBody', Locked = true;
        NotAFatturaErr: Label 'File %1 does not contain a FatturaElettronica root element.', Comment = '%1 = file name';
        MalformedErr: Label 'File %1 is not well-formed XML: %2', Comment = '%1 = file name, %2 = parser message';
        InsertDocumentErr: Label 'Cannot file document no. %1 of file %2.\\Error code: %3\\%4', Comment = '%1 = body no., %2 = file name, %3 = error code, %4 = error text';
        NoBodyErr: Label 'File %1 contains no FatturaElettronicaBody element.', Comment = '%1 = file name';
        UnknownFileErr: Label 'File %1 is neither a FatturaPA invoice nor a recognised SdI receipt. Expected a name like IT01234567890_ABCDE.xml or IT01234567890_ABCDE_RC_001.xml.', Comment = '%1 = file name';
        ErrorTok: Label '%1 %2', Locked = true;
        InvoiceRootNameTok: Label 'FatturaElettronica', Locked = true;
        SignatureElementNameTok: Label 'Signature', Locked = true;
        NotePairTok: Label '%1 - %2', Locked = true;
        DestinatarioPathTok: Label '/*/*[local-name()=''Destinatario'']', Locked = true;
        RootChildPathTok: Label '/*/*[local-name()=''%1'']', Locked = true;
        ChildPathTok: Label '*[local-name()=''%1'']', Locked = true;
        ErrorPathTok: Label '//*[local-name()=''Errore'']', Locked = true;
        AnyPathTok: Label '//*[local-name()=''%1'']', Locked = true;
        RiferimentoFatturaPathTok: Label '//*[local-name()=''RiferimentoFattura'']', Locked = true;
        ReplaceExistingQst: Label 'Some of the selected files have already been imported. Replace them?';
        SummaryTok: Label '%1 file(s) imported: %2 invoice(s) with %3 document(s), %4 receipt(s).', Comment = '%1 = file count, %2 = invoice count, %3 = document count, %4 = receipt count';
        ReplacedTok: Label '\%1 already existed and were replaced.', Comment = '%1 = replaced count';
        SkippedTok: Label '\%1 already existed and were skipped.', Comment = '%1 = skipped count';
        FailedTok: Label '\%1 could not be read - see the Validation Message on those files.', Comment = '%1 = failed count';
        NothingTok: Label 'No file was imported.';

    /// <summary>
    /// Imports every uploaded file. Called from a fileuploadaction, so the user can select
    /// or drag several XML files at once.
    ///
    /// One bad file must not abort the batch, so Explode runs inside a TryFunction: on
    /// failure the reason is written on that file record and the loop moves on.
    /// </summary>
    procedure ImportFiles(Files: List of [FileUpload]; var LastXmlFile: Record "FPA Xml File"): Text
    var
        XmlFile: Record "FPA Xml File";
        CurrentFile: FileUpload;
        InStr: InStream;
        FileKey: Code[250];
        ReplaceExisting: Boolean;
        FileExists: Boolean;
        Succeeded: Integer;
        Replaced: Integer;
        Skipped: Integer;
        Failed: Integer;
        DocumentCount: Integer;
        InvoiceCount: Integer;
        ReceiptCount: Integer;
    begin
        // Ask BEFORE writing anything. Confirm is a dialog, and Business Central refuses to
        // open one once the transaction has written to the database - so asking lazily on the
        // first collision would blow up whenever that collision is not the first file.
        ReplaceExisting := ConfirmReplaceExisting(Files);

        foreach CurrentFile in Files do begin
            FileKey := MakeFileKey(CurrentFile.FileName());
            FileExists := XmlFile.Get(FileKey);

            if FileExists and not ReplaceExisting then
                Skipped += 1
            else begin
                if FileExists then begin
                    XmlFile.Delete(true); // cascades to the exploded documents
                    Replaced += 1;
                end;

                CurrentFile.CreateInStream(InStr, TextEncoding::UTF8);
                StoreFile(InStr, CurrentFile.FileName(), FileKey, XmlFile);

                if TryExplode(XmlFile) then begin
                    XmlFile.CalcFields("No. of Documents");
                    DocumentCount += XmlFile."No. of Documents";
                    case XmlFile."File Type" of
                        XmlFile."File Type"::Invoice:
                            InvoiceCount += 1;
                        XmlFile."File Type"::Receipt:
                            ReceiptCount += 1;
                    end;
                    Succeeded += 1;
                    LastXmlFile := XmlFile;
                end else begin
                    RecordFailure(FileKey, GetLastErrorText());
                    Failed += 1;
                end;
            end;
        end;

        exit(BuildSummary(Succeeded, Replaced, Skipped, Failed, DocumentCount, InvoiceCount, ReceiptCount));
    end;

    /// <summary>
    /// Asks once, up front, whether files already imported should be replaced - and only if
    /// at least one of them actually is.
    /// </summary>
    local procedure ConfirmReplaceExisting(Files: List of [FileUpload]): Boolean
    var
        XmlFile: Record "FPA Xml File";
        CurrentFile: FileUpload;
    begin
        foreach CurrentFile in Files do
            if XmlFile.Get(MakeFileKey(CurrentFile.FileName())) then
                exit(Confirm(ReplaceExistingQst, false));
        exit(false);
    end;

    /// <summary>
    /// Programmatic entry point: stores a stream and explodes it, no dialogs.
    /// Reusable from a job queue, an API page or a test.
    /// </summary>
    procedure ImportFromStream(var InStr: InStream; FileName: Text; ReplaceExisting: Boolean; var XmlFile: Record "FPA Xml File"): Boolean
    var
        FileKey: Code[250];
    begin
        FileKey := MakeFileKey(FileName);

        if XmlFile.Get(FileKey) then begin
            if not ReplaceExisting then
                exit(false);
            XmlFile.Delete(true);
        end;

        StoreFile(InStr, FileName, FileKey, XmlFile);
        Explode(XmlFile);
        exit(true);
    end;

    local procedure MakeFileKey(FileName: Text): Code[250]
    var
        XmlFile: Record "FPA Xml File";
    begin
        // Code fields are upper-cased by the platform anyway; doing it here keeps the
        // Get() lookups above predictable. Original casing lives in "Original File Name".
        exit(CopyStr(UpperCase(FileName), 1, MaxStrLen(XmlFile."File Name")));
    end;

    local procedure StoreFile(var InStr: InStream; FileName: Text; FileKey: Code[250]; var XmlFile: Record "FPA Xml File")
    var
        OutStr: OutStream;
    begin
        XmlFile.Init();
        XmlFile."File Name" := FileKey;
        XmlFile."Original File Name" := CopyStr(FileName, 1, MaxStrLen(XmlFile."Original File Name"));
        XmlFile.Insert(true);

        XmlFile.Xml.CreateOutStream(OutStr, TextEncoding::UTF8);
        CopyStream(OutStr, InStr);
        XmlFile.Modify(true);
    end;

    [TryFunction]
    local procedure TryExplode(var XmlFile: Record "FPA Xml File")
    begin
        Explode(XmlFile);
    end;

    local procedure RecordFailure(FileKey: Code[250]; ErrorText: Text)
    var
        XmlFile: Record "FPA Xml File";
    begin
        // A failed TryFunction rolls back everything it wrote, so the record has to be
        // re-read before the reason can be stored on it.
        if not XmlFile.Get(FileKey) then
            exit;
        XmlFile."Validation Status" := XmlFile."Validation Status"::"Not Well Formed";
        XmlFile."Validation Message" := CopyStr(ErrorText, 1, MaxStrLen(XmlFile."Validation Message"));
        XmlFile.Modify(true);
    end;

    local procedure BuildSummary(Succeeded: Integer; Replaced: Integer; Skipped: Integer; Failed: Integer; DocumentCount: Integer; InvoiceCount: Integer; ReceiptCount: Integer): Text
    var
        Summary: TextBuilder;
    begin
        if (Succeeded = 0) and (Failed = 0) then
            exit(NothingTok);

        Summary.Append(StrSubstNo(SummaryTok, Succeeded, InvoiceCount, DocumentCount, ReceiptCount));
        if Replaced > 0 then
            Summary.Append(StrSubstNo(ReplacedTok, Replaced));
        if Skipped > 0 then
            Summary.Append(StrSubstNo(SkippedTok, Skipped));
        if Failed > 0 then
            Summary.Append(StrSubstNo(FailedTok, Failed));
        exit(Summary.ToText());
    end;

    /// <summary>
    /// Re-reads the stored XML. Classifies the file, then either explodes its bodies
    /// (invoice) or reads its SdI fields (receipt). Safe to run again on an existing file.
    /// </summary>
    procedure Explode(var XmlFile: Record "FPA Xml File")
    var
        FileNameParser: Codeunit "FPA File Name Parser";
        SdiStatusMgt: Codeunit "FPA SdI Status Mgt.";
        TempBlob: Codeunit "Temp Blob";
        XmlDoc: XmlDocument;
        InStr: InStream;
        FileType: Enum "FPA File Type";
        SdiBaseName: Code[250];
        ReceiptCode: Code[10];
        ReceiptProgressive: Code[10];
    begin
        // Read through a Temp Blob, never straight off the record's BLOB field: the whole
        // procedure ends in a Modify, and a stream bound to that field would still be open
        // when it runs. See "FPA Xml File".GetXmlTempBlob.
        if not XmlFile.GetXmlTempBlob(TempBlob) then
            exit;

        TempBlob.CreateInStream(InStr, TextEncoding::UTF8);
        if not XmlDocument.ReadFrom(InStr, XmlDoc) then begin
            XmlFile."Validation Status" := XmlFile."Validation Status"::"Not Well Formed";
            XmlFile."Validation Message" := CopyStr(StrSubstNo(MalformedErr, XmlFile."Original File Name", GetLastErrorText()), 1, MaxStrLen(XmlFile."Validation Message"));
            XmlFile.Modify(true);
            exit;
        end;

        // Name first (it carries the receipt type and the link to the invoice), then the
        // root element gets the final say on invoice vs receipt. See ClassifyFromXml.
        FileNameParser.Parse(XmlFile."Original File Name", FileType, SdiBaseName, ReceiptCode, ReceiptProgressive);
        ClassifyFromXml(XmlDoc, XmlFile."Original File Name", FileType, SdiBaseName, ReceiptCode, ReceiptProgressive);

        ReadRootFacts(XmlFile, XmlDoc);

        XmlFile."File Type" := FileType;
        XmlFile."SdI Base Name" := SdiBaseName;
        XmlFile."Receipt Type Code" := ReceiptCode;
        XmlFile."Receipt Progressive" := ReceiptProgressive;
        XmlFile."Receipt Type" := FileNameParser.ReceiptTypeFromCode(ReceiptCode);
        XmlFile."File Size (Bytes)" := TempBlob.Length();

        // Rebuild the children from scratch: an XML file is immutable once imported,
        // so a partial refresh would only leave stale rows behind.
        DeleteChildren(XmlFile."File Name");

        case FileType of
            FileType::Invoice:
                ExplodeInvoice(XmlFile, XmlDoc);
            FileType::Receipt:
                ReadReceipt(XmlFile, XmlDoc);
            else
                Error(UnknownFileErr, XmlFile."Original File Name");
        end;

        // ONE write, at the end. The reading helpers above only fill fields in memory - a
        // Modify per helper would be several round trips for no gain, and each one is another
        // chance to fail halfway through with the record half-updated.
        XmlFile.Modify(true);

        // Whatever just arrived may change the outcome of the invoice it belongs to -
        // and receipts routinely land before the invoice they refer to.
        SdiStatusMgt.UpdateInvoiceStatus(XmlFile."SdI Base Name");
        XmlFile.Get(XmlFile."File Name");
    end;

    local procedure DeleteChildren(FileName: Code[250])
    var
        XmlFileDocument: Record "FPA Xml File Document";
        ReceiptError: Record "FPA Receipt Error";
    begin
        XmlFileDocument.Init();
        XmlFileDocument.SetRange("File Name", FileName);
        if (XmlFileDocument.FindSet()) then
            XmlFileDocument.DeleteAll(true);
        ReceiptError.Init();
        ReceiptError.SetRange("File Name", FileName);
        if (ReceiptError.FindSet()) then
            ReceiptError.DeleteAll(true);
    end;

    /// <summary>
    /// Reads the two facts that live on the root element of BOTH kinds of file: the versione
    /// attribute and whether the document is signed.
    ///
    /// Receipts are signed too - SdI signs them with its own certificate - so this cannot
    /// live in the invoice-only path.
    /// </summary>
    local procedure ReadRootFacts(var XmlFile: Record "FPA Xml File"; XmlDoc: XmlDocument)
    var
        Root: XmlElement;
        VersioneAttribute: XmlAttribute;
    begin
        if not XmlDoc.GetRoot(Root) then
            exit;
        if Root.Attributes().Get('versione', VersioneAttribute) then
            XmlFile.Versione := CopyStr(VersioneAttribute.Value(), 1, MaxStrLen(XmlFile.Versione));
        XmlFile."Has Signature" := Root.GetChildElements(SignatureElementNameTok, DsigNsTxt).Count() > 0;
    end;

    /// <summary>
    /// Reconciles the name-based classification with what the document actually is.
    ///
    /// Division of authority:
    ///   * the ROOT ELEMENT decides invoice vs receipt. A file whose root is
    ///     FatturaElettronica is an invoice even if somebody renamed it to something with
    ///     four underscores in it - otherwise it would be filed as a receipt of a
    ///     non-existent invoice, under a base name cut out of its own name.
    ///   * the FILE NAME decides WHICH receipt type it is, and the base name that links it
    ///     back to its invoice. That is the rule, and a code the file name carries is never
    ///     overwritten - an unrecognised one becomes "Other" with the raw code kept, rather
    ///     than being silently relabelled from the root element.
    /// </summary>
    local procedure ClassifyFromXml(XmlDoc: XmlDocument; FileName: Text; var FileType: Enum "FPA File Type"; var SdiBaseName: Code[250]; var ReceiptCode: Code[10]; var ReceiptProgressive: Code[10])
    var
        FileNameParser: Codeunit "FPA File Name Parser";
        Root: XmlElement;
        RootName: Text;
        CodeFromRoot: Code[10];
    begin
        if not XmlDoc.GetRoot(Root) then
            exit;
        RootName := Root.LocalName();

        if RootName = InvoiceRootNameTok then begin
            if FileType <> FileType::Invoice then begin
                FileType := FileType::Invoice;
                // The name was not an SdI name, so its segments mean nothing: fall back to
                // the whole name as the base, and drop the receipt parts read out of it.
                SdiBaseName := CopyStr(UpperCase(FileNameParser.StripExtension(FileName)), 1, MaxStrLen(SdiBaseName));
                ReceiptCode := '';
                ReceiptProgressive := '';
            end;
            exit;
        end;

        CodeFromRoot := FileNameParser.ReceiptCodeFromRootName(RootName);
        if CodeFromRoot = '' then
            exit;

        FileType := FileType::Receipt;
        if ReceiptCode = '' then
            ReceiptCode := CodeFromRoot;
    end;

    /// <summary>
    /// Invoice path: one header onto the file record, one document per body.
    /// </summary>
    local procedure ExplodeInvoice(var XmlFile: Record "FPA Xml File"; XmlDoc: XmlDocument)
    var
        NsMgr: XmlNamespaceManager;
        Root: XmlElement;
        Bodies: XmlNodeList;
        BodyNode: XmlNode;
        RootPath: Text;
        Index: Integer;
    begin
        InitNamespaceManager(XmlDoc, NsMgr);
        RootPath := DetectRootPath(XmlDoc, NsMgr);
        if RootPath = '' then
            Error(NotAFatturaErr, XmlFile."Original File Name");

        XmlDoc.GetRoot(Root);
        ReadFileHeader(XmlFile, XmlDoc, NsMgr, Root, RootPath);

        Bodies := Root.GetChildElements(BodyElementNameTxt);
        if Bodies.Count() = 0 then
            Error(NoBodyErr, XmlFile."Original File Name");

        for Index := 1 to Bodies.Count() do begin
            Bodies.Get(Index, BodyNode);
            InsertDocument(XmlFile, Index, BodyNode.AsXmlElement());
        end;

        XmlFile."No. of Bodies" := Bodies.Count();
    end;

    // ------------------------------------------------------------------ receipt

    /// <summary>
    /// Receipt path. Every lookup goes through local-name() rather than a namespace manager,
    /// which is what makes this robust: the real messages use
    ///   http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fattura/messaggi/v1.0
    /// under prefix ns3 - NOT the fatturapa.gov.it/sdi/messaggi URI the documentation for
    /// the message types is usually filed under. Hard-coding either would have been wrong.
    ///
    /// The scalar fields are addressed as direct children of the root (/*/...), NOT with a
    /// descendant search: a delivery receipt has a Destinatario/Descrizione nested inside it
    /// that a // search happily returns instead of the one meant here.
    /// </summary>
    local procedure ReadReceipt(var XmlFile: Record "FPA Xml File"; XmlDoc: XmlDocument)
    var
        Errors: XmlNodeList;
        ReceiptDateTime: Text;
    begin
        // Common to all four message types in SDIRicevute.xsd.
        XmlFile."Identificativo SdI" := CopyStr(GetRootChildText(XmlDoc, 'IdentificativoSdI'), 1, MaxStrLen(XmlFile."Identificativo SdI"));
        XmlFile."Referenced File Name" := CopyStr(GetRootChildText(XmlDoc, 'NomeFile'), 1, MaxStrLen(XmlFile."Referenced File Name"));
        XmlFile."File Hash" := CopyStr(GetRootChildText(XmlDoc, 'Hash'), 1, MaxStrLen(XmlFile."File Hash"));
        XmlFile."Message Id" := CopyStr(GetRootChildText(XmlDoc, 'MessageId'), 1, MaxStrLen(XmlFile."Message Id"));
        XmlFile."Pec Message Id" := CopyStr(GetRootChildText(XmlDoc, 'PecMessageId'), 1, MaxStrLen(XmlFile."Pec Message Id"));

        // A delivery receipt carries both; the delivery instant is the interesting one.
        // FileMetadati carries neither - it is a notification, not an outcome.
        ReceiptDateTime := GetRootChildText(XmlDoc, 'DataOraConsegna');
        if ReceiptDateTime = '' then
            ReceiptDateTime := GetRootChildText(XmlDoc, 'DataOraRicezione');
        XmlFile."Receipt Date/Time" := ParseXmlDateTime(ReceiptDateTime);

        // Failed delivery only: the date from which the invoice counts as received, because
        // it was placed in the recipient's reserved area.
        XmlFile."Data Messa A Disposizione" := ParseXmlDate(GetRootChildText(XmlDoc, 'DataMessaADisposizione'));

        // Metadata notification only. Both reuse fields that already exist on the record and
        // mean exactly the same thing on an invoice.
        if XmlFile."Codice Destinatario" = '' then
            XmlFile."Codice Destinatario" := CopyStr(GetRootChildText(XmlDoc, 'CodiceDestinatario'), 1, MaxStrLen(XmlFile."Codice Destinatario"));
        if XmlFile."Formato Trasmissione" = '' then
            XmlFile."Formato Trasmissione" := CopyStr(GetRootChildText(XmlDoc, 'Formato'), 1, MaxStrLen(XmlFile."Formato Trasmissione"));
        if not Evaluate(XmlFile."Tentativi Invio", GetRootChildText(XmlDoc, 'TentativiInvio')) then
            XmlFile."Tentativi Invio" := 0;

        // EC and SE identify the invoice by number/year rather than by file name.
        XmlFile."Riferimento Fattura" := CopyStr(BuildRiferimentoFattura(XmlDoc), 1, MaxStrLen(XmlFile."Riferimento Fattura"));
        XmlFile."Message Id Committente" := CopyStr(GetAnyText(XmlDoc, 'MessageIdCommittente'), 1, MaxStrLen(XmlFile."Message Id Committente"));

        // EC carries Esito at the root; NE carries the same value nested inside
        // EsitoCommittente, so a descendant search is right here - unlike the scalar fields.
        XmlFile.Esito := CopyStr(GetAnyText(XmlDoc, 'Esito'), 1, MaxStrLen(XmlFile.Esito));
        XmlFile."Scarto Esito" := CopyStr(GetRootChildText(XmlDoc, 'Scarto'), 1, MaxStrLen(XmlFile."Scarto Esito"));

        // AT names its digest HashFileOriginale instead of Hash.
        if XmlFile."File Hash" = '' then
            XmlFile."File Hash" := CopyStr(GetRootChildText(XmlDoc, 'HashFileOriginale'), 1, MaxStrLen(XmlFile."File Hash"));

        // Rejection only. Every error is stored: the schema allows up to 200 of them, each
        // with a Suggerimento that is the part telling you what to fix.
        if XmlDoc.SelectNodes(ErrorPathTok, Errors) then begin
            XmlFile."Error Count" := Errors.Count();
            StoreErrors(XmlFile, Errors);
            XmlFile."Receipt Note" := CopyStr(FirstErrorText(Errors), 1, MaxStrLen(XmlFile."Receipt Note"));
        end else begin
            XmlFile."Error Count" := 0;
            XmlFile."Receipt Note" := CopyStr(PlainNote(XmlDoc), 1, MaxStrLen(XmlFile."Receipt Note"));
        end;

        XmlFile."No. of Bodies" := 0;
    end;

    /// <summary>
    /// Writes the ListaErrori of a rejection into "FPA Receipt Error", one row per Errore.
    /// </summary>
    local procedure StoreErrors(var XmlFile: Record "FPA Xml File"; var Errors: XmlNodeList)
    var
        ReceiptError: Record "FPA Receipt Error";
        ErrorNode: XmlNode;
        Index: Integer;
    begin
        ReceiptError.SetRange("File Name", XmlFile."File Name");
        ReceiptError.DeleteAll(true);

        for Index := 1 to Errors.Count() do begin
            Errors.Get(Index, ErrorNode);
            ReceiptError.Init();
            ReceiptError."File Name" := XmlFile."File Name";
            ReceiptError."Line No." := Index;
            ReceiptError.Codice := CopyStr(GetChildTextByLocalName(ErrorNode, 'Codice'), 1, MaxStrLen(ReceiptError.Codice));
            ReceiptError.Descrizione := CopyStr(GetChildTextByLocalName(ErrorNode, 'Descrizione'), 1, MaxStrLen(ReceiptError.Descrizione));
            ReceiptError.Suggerimento := CopyStr(GetChildTextByLocalName(ErrorNode, 'Suggerimento'), 1, MaxStrLen(ReceiptError.Suggerimento));
            ReceiptError.Insert(true);
        end;
    end;

    local procedure FirstErrorText(var Errors: XmlNodeList): Text
    var
        FirstError: XmlNode;
    begin
        if Errors.Count() = 0 then
            exit('');
        Errors.Get(1, FirstError);
        exit(DelChr(StrSubstNo(ErrorTok,
            GetChildTextByLocalName(FirstError, 'Codice'),
            GetChildTextByLocalName(FirstError, 'Descrizione')), '<>', ' '));
    end;

    local procedure PlainNote(XmlDoc: XmlDocument): Text
    var
        DestinatarioNode: XmlNode;
        Note: Text;
    begin
        // A failed delivery explains itself in Descrizione, some receipts carry a Note.
        Note := GetRootChildText(XmlDoc, 'Descrizione');
        if Note = '' then
            Note := GetRootChildText(XmlDoc, 'Note');
        if Note <> '' then
            exit(Note);

        // A delivery receipt has neither: the only prose in it sits under Destinatario, and
        // it is worth keeping ("Trasmesso su canale registrato dal cessionario/committente"
        // says something quite different from a PEC delivery).
        if XmlDoc.SelectSingleNode(DestinatarioPathTok, DestinatarioNode) then
            exit(DelChr(StrSubstNo(NotePairTok,
                GetChildTextByLocalName(DestinatarioNode, 'Codice'),
                GetChildTextByLocalName(DestinatarioNode, 'Descrizione')), '<>', ' -'));
        exit('');
    end;

    /// <summary>
    /// Composes "1111/2013 pos. 2" out of RiferimentoFattura.
    /// </summary>
    local procedure BuildRiferimentoFattura(XmlDoc: XmlDocument): Text
    var
        Node: XmlNode;
        Numero: Text;
        Anno: Text;
        Posizione: Text;
        RefTok: Label '%1/%2', Locked = true;
        PosTok: Label '%1 pos. %2', Locked = true;
    begin
        if not XmlDoc.SelectSingleNode(RiferimentoFatturaPathTok, Node) then
            exit('');
        Numero := GetChildTextByLocalName(Node, 'NumeroFattura');
        Anno := GetChildTextByLocalName(Node, 'AnnoFattura');
        Posizione := GetChildTextByLocalName(Node, 'PosizioneFattura');
        if Numero = '' then
            exit('');
        if Posizione <> '' then
            exit(StrSubstNo(PosTok, StrSubstNo(RefTok, Numero, Anno), Posizione));
        exit(StrSubstNo(RefTok, Numero, Anno));
    end;

    /// <summary>
    /// Descendant search by local name. Only for the handful of fields that legitimately sit
    /// at different depths across message types - Esito is at the root on EC and nested in
    /// EsitoCommittente on NE.
    /// </summary>
    local procedure GetAnyText(XmlDoc: XmlDocument; LocalName: Text): Text
    var
        Node: XmlNode;
    begin
        if not XmlDoc.SelectSingleNode(StrSubstNo(AnyPathTok, LocalName), Node) then
            exit('');
        if not Node.IsXmlElement() then
            exit('');
        exit(Node.AsXmlElement().InnerText());
    end;

    local procedure GetRootChildText(XmlDoc: XmlDocument; LocalName: Text): Text
    var
        Node: XmlNode;
    begin
        if not XmlDoc.SelectSingleNode(StrSubstNo(RootChildPathTok, LocalName), Node) then
            exit('');
        if not Node.IsXmlElement() then
            exit('');
        exit(Node.AsXmlElement().InnerText());
    end;

    local procedure GetChildTextByLocalName(ParentNode: XmlNode; LocalName: Text): Text
    var
        Node: XmlNode;
    begin
        if not ParentNode.SelectSingleNode(StrSubstNo(ChildPathTok, LocalName), Node) then
            exit('');
        if not Node.IsXmlElement() then
            exit('');
        exit(Node.AsXmlElement().InnerText());
    end;

    local procedure ParseXmlDateTime(Value: Text): DateTime
    var
        Result: DateTime;
    begin
        if Value = '' then
            exit(0DT);
        // SdI uses xs:dateTime with an offset, e.g. 2026-01-22T10:20:11.000+01:00,
        // which is exactly AL's XML format (9).
        if not Evaluate(Result, Value, 9) then
            exit(0DT);
        exit(Result);
    end;

    // ------------------------------------------------------------------ file header

    local procedure ReadFileHeader(var XmlFile: Record "FPA Xml File"; XmlDoc: XmlDocument; NsMgr: XmlNamespaceManager; Root: XmlElement; RootPath: Text)
    var
        HeaderPath: Text;
    begin
        HeaderPath := RootPath + '/FatturaElettronicaHeader';

        XmlFile."Id Trasmittente" := CopyStr(
            GetText(XmlDoc, NsMgr, HeaderPath + '/DatiTrasmissione/IdTrasmittente/IdPaese') +
            GetText(XmlDoc, NsMgr, HeaderPath + '/DatiTrasmissione/IdTrasmittente/IdCodice'),
            1, MaxStrLen(XmlFile."Id Trasmittente"));
        XmlFile."Formato Trasmissione" := CopyStr(GetText(XmlDoc, NsMgr, HeaderPath + '/DatiTrasmissione/FormatoTrasmissione'), 1, MaxStrLen(XmlFile."Formato Trasmissione"));
        XmlFile."Progressivo Invio" := CopyStr(GetText(XmlDoc, NsMgr, HeaderPath + '/DatiTrasmissione/ProgressivoInvio'), 1, MaxStrLen(XmlFile."Progressivo Invio"));
        XmlFile."Codice Destinatario" := CopyStr(GetText(XmlDoc, NsMgr, HeaderPath + '/DatiTrasmissione/CodiceDestinatario'), 1, MaxStrLen(XmlFile."Codice Destinatario"));
        XmlFile."PEC Destinatario" := CopyStr(GetText(XmlDoc, NsMgr, HeaderPath + '/DatiTrasmissione/PECDestinatario'), 1, MaxStrLen(XmlFile."PEC Destinatario"));

        XmlFile."Cedente Denominazione" := CopyStr(GetPartyName(XmlDoc, NsMgr, HeaderPath + '/CedentePrestatore/DatiAnagrafici/Anagrafica'), 1, MaxStrLen(XmlFile."Cedente Denominazione"));
        XmlFile."Cedente P.IVA" := CopyStr(GetVatNo(XmlDoc, NsMgr, HeaderPath + '/CedentePrestatore/DatiAnagrafici'), 1, MaxStrLen(XmlFile."Cedente P.IVA"));
        XmlFile."Cedente Codice Fiscale" := CopyStr(GetText(XmlDoc, NsMgr, HeaderPath + '/CedentePrestatore/DatiAnagrafici/CodiceFiscale'), 1, MaxStrLen(XmlFile."Cedente Codice Fiscale"));
        XmlFile."Cedente Comune" := CopyStr(GetText(XmlDoc, NsMgr, HeaderPath + '/CedentePrestatore/Sede/Comune'), 1, MaxStrLen(XmlFile."Cedente Comune"));
        XmlFile."Cedente Provincia" := CopyStr(GetText(XmlDoc, NsMgr, HeaderPath + '/CedentePrestatore/Sede/Provincia'), 1, MaxStrLen(XmlFile."Cedente Provincia"));

        XmlFile."Cessionario Denominazione" := CopyStr(GetPartyName(XmlDoc, NsMgr, HeaderPath + '/CessionarioCommittente/DatiAnagrafici/Anagrafica'), 1, MaxStrLen(XmlFile."Cessionario Denominazione"));
        XmlFile."Cessionario P.IVA" := CopyStr(GetVatNo(XmlDoc, NsMgr, HeaderPath + '/CessionarioCommittente/DatiAnagrafici'), 1, MaxStrLen(XmlFile."Cessionario P.IVA"));
        XmlFile."Cessionario Codice Fiscale" := CopyStr(GetText(XmlDoc, NsMgr, HeaderPath + '/CessionarioCommittente/DatiAnagrafici/CodiceFiscale'), 1, MaxStrLen(XmlFile."Cessionario Codice Fiscale"));
    end;

    // ------------------------------------------------------------------ one body

    local procedure InsertDocument(var XmlFile: Record "FPA Xml File"; BodyNo: Integer; BodyElement: XmlElement)
    var
        XmlFileDocument: Record "FPA Xml File Document";
    begin
        XmlFileDocument.Init();
        XmlFileDocument."File Name" := XmlFile."File Name";
        XmlFileDocument."Body No." := BodyNo;

        XmlFileDocument."Tipo Documento" := CopyStr(GetChildText(BodyElement, 'DatiGenerali/DatiGeneraliDocumento/TipoDocumento'), 1, MaxStrLen(XmlFileDocument."Tipo Documento"));
        XmlFileDocument.Numero := CopyStr(GetChildText(BodyElement, 'DatiGenerali/DatiGeneraliDocumento/Numero'), 1, MaxStrLen(XmlFileDocument.Numero));
        XmlFileDocument.Divisa := CopyStr(GetChildText(BodyElement, 'DatiGenerali/DatiGeneraliDocumento/Divisa'), 1, MaxStrLen(XmlFileDocument.Divisa));
        XmlFileDocument.Data := ParseXmlDate(GetChildText(BodyElement, 'DatiGenerali/DatiGeneraliDocumento/Data'));
        XmlFileDocument."Importo Totale Documento" := ParseXmlDecimal(GetChildText(BodyElement, 'DatiGenerali/DatiGeneraliDocumento/ImportoTotaleDocumento'));
        XmlFileDocument.Causale := CopyStr(GetChildText(BodyElement, 'DatiGenerali/DatiGeneraliDocumento/Causale'), 1, MaxStrLen(XmlFileDocument.Causale));

        SummariseRiepilogo(BodyElement, XmlFileDocument);
        SummarisePagamento(BodyElement, XmlFileDocument);

        XmlFileDocument."No. of Lines" := CountDescendants(BodyElement, 'DatiBeniServizi', 'DettaglioLinee');

        // One write, with every field already in place - no Insert-then-Modify dance.
        //
        // Wrapped so that a failure reports the platform's own error code and text. Note that
        // Rec.Modify() used in a boolean context does NOT raise an error and does NOT set the
        // last error, so testing it and then calling GetLastErrorText() yields an empty
        // message - an "error with no reason". Only a TryFunction fills those in.
        if not TryInsertDocument(XmlFileDocument) then
            Error(InsertDocumentErr, BodyNo, XmlFile."Original File Name", GetLastErrorCode(), GetLastErrorText());
    end;

    [TryFunction]
    local procedure TryInsertDocument(var XmlFileDocument: Record "FPA Xml File Document")
    begin
        XmlFileDocument.Insert(true);
    end;

    local procedure SummariseRiepilogo(BodyElement: XmlElement; var XmlFileDocument: Record "FPA Xml File Document")
    var
        DatiBeniServizi: XmlElement;
        Riepilogo: XmlNodeList;
        Node: XmlNode;
        Index: Integer;
        Imponibile: Decimal;
        Imposta: Decimal;
    begin
        if not GetChildElement(BodyElement, 'DatiBeniServizi', DatiBeniServizi) then
            exit;
        Riepilogo := DatiBeniServizi.GetChildElements('DatiRiepilogo');
        for Index := 1 to Riepilogo.Count() do begin
            Riepilogo.Get(Index, Node);
            Imponibile += ParseXmlDecimal(GetChildText(Node.AsXmlElement(), 'ImponibileImporto'));
            Imposta += ParseXmlDecimal(GetChildText(Node.AsXmlElement(), 'Imposta'));
        end;
        XmlFileDocument."Imponibile Importo" := Imponibile;
        XmlFileDocument.Imposta := Imposta;
        XmlFileDocument."No. of VAT Rates" := Riepilogo.Count();
    end;

    local procedure SummarisePagamento(BodyElement: XmlElement; var XmlFileDocument: Record "FPA Xml File Document")
    var
        DatiPagamento: XmlElement;
        Dettagli: XmlNodeList;
        Node: XmlNode;
        Index: Integer;
        DueDate: Date;
        EarliestDueDate: Date;
    begin
        if not GetChildElement(BodyElement, 'DatiPagamento', DatiPagamento) then
            exit;
        Dettagli := DatiPagamento.GetChildElements('DettaglioPagamento');
        for Index := 1 to Dettagli.Count() do begin
            Dettagli.Get(Index, Node);
            if XmlFileDocument."Modalita Pagamento" = '' then
                XmlFileDocument."Modalita Pagamento" := CopyStr(GetChildText(Node.AsXmlElement(), 'ModalitaPagamento'), 1, MaxStrLen(XmlFileDocument."Modalita Pagamento"));
            DueDate := ParseXmlDate(GetChildText(Node.AsXmlElement(), 'DataScadenzaPagamento'));
            if DueDate <> 0D then
                if (EarliestDueDate = 0D) or (DueDate < EarliestDueDate) then
                    EarliestDueDate := DueDate;
        end;
        XmlFileDocument."Data Scadenza Pagamento" := EarliestDueDate;
    end;

    // ------------------------------------------------------------------ XML helpers

    local procedure InitNamespaceManager(XmlDoc: XmlDocument; var NsMgr: XmlNamespaceManager)
    begin
        NsMgr.NameTable(XmlDoc.NameTable());
        NsMgr.AddNamespace('a', FatturaNsV12Txt);
        NsMgr.AddNamespace('b', FatturaNsV11Txt);
        NsMgr.AddNamespace('c', FatturaNsV10Txt);
    end;

    local procedure DetectRootPath(XmlDoc: XmlDocument; NsMgr: XmlNamespaceManager): Text
    var
        Node: XmlNode;
    begin
        if XmlDoc.SelectSingleNode('/a:FatturaElettronica', NsMgr, Node) then
            exit('/a:FatturaElettronica');
        if XmlDoc.SelectSingleNode('/b:FatturaElettronica', NsMgr, Node) then
            exit('/b:FatturaElettronica');
        if XmlDoc.SelectSingleNode('/c:FatturaElettronica', NsMgr, Node) then
            exit('/c:FatturaElettronica');
        if XmlDoc.SelectSingleNode('/FatturaElettronica', NsMgr, Node) then
            exit('/FatturaElettronica');
        exit('');
    end;

    /// <summary>
    /// InnerText of the first node matching an absolute XPath, or '' if absent.
    /// </summary>
    procedure GetText(XmlDoc: XmlDocument; NsMgr: XmlNamespaceManager; XPath: Text): Text
    var
        Node: XmlNode;
    begin
        if not XmlDoc.SelectSingleNode(XPath, NsMgr, Node) then
            exit('');
        if not Node.IsXmlElement() then
            exit('');
        exit(Node.AsXmlElement().InnerText());
    end;

    /// <summary>
    /// Walks a '/'-separated chain of unqualified child element names starting at ParentElement.
    /// Used instead of XPath because body elements are relative to a node, not to the document,
    /// and none of them carry a namespace.
    /// </summary>
    local procedure GetChildText(ParentElement: XmlElement; RelativePath: Text): Text
    var
        Target: XmlElement;
    begin
        if not GetChildElementByPath(ParentElement, RelativePath, Target) then
            exit('');
        exit(Target.InnerText());
    end;

    local procedure GetChildElementByPath(ParentElement: XmlElement; RelativePath: Text; var Result: XmlElement): Boolean
    var
        Current: XmlElement;
        Next: XmlElement;
        Segments: List of [Text];
        Segment: Text;
    begin
        Current := ParentElement;
        Segments := RelativePath.Split('/');
        foreach Segment in Segments do begin
            if not GetChildElement(Current, Segment, Next) then
                exit(false);
            Current := Next;
        end;
        Result := Current;
        exit(true);
    end;

    local procedure GetChildElement(ParentElement: XmlElement; ElementName: Text; var Result: XmlElement): Boolean
    var
        Children: XmlNodeList;
        Node: XmlNode;
    begin
        Children := ParentElement.GetChildElements(ElementName);
        if Children.Count() = 0 then
            exit(false);
        Children.Get(1, Node);
        Result := Node.AsXmlElement();
        exit(true);
    end;

    local procedure CountDescendants(ParentElement: XmlElement; ContainerName: Text; ElementName: Text): Integer
    var
        Container: XmlElement;
    begin
        if not GetChildElement(ParentElement, ContainerName, Container) then
            exit(0);
        exit(Container.GetChildElements(ElementName).Count());
    end;

    local procedure GetPartyName(XmlDoc: XmlDocument; NsMgr: XmlNamespaceManager; BasePath: Text): Text
    var
        Denominazione: Text;
        Nome: Text;
        Cognome: Text;
    begin
        Denominazione := GetText(XmlDoc, NsMgr, BasePath + '/Denominazione');
        if Denominazione <> '' then
            exit(Denominazione);
        Nome := GetText(XmlDoc, NsMgr, BasePath + '/Nome');
        Cognome := GetText(XmlDoc, NsMgr, BasePath + '/Cognome');
        exit(DelChr(Cognome + ' ' + Nome, '<>', ' '));
    end;

    local procedure GetVatNo(XmlDoc: XmlDocument; NsMgr: XmlNamespaceManager; BasePath: Text): Text
    var
        Paese: Text;
        Codice: Text;
    begin
        Paese := GetText(XmlDoc, NsMgr, BasePath + '/IdFiscaleIVA/IdPaese');
        Codice := GetText(XmlDoc, NsMgr, BasePath + '/IdFiscaleIVA/IdCodice');
        if Codice <> '' then
            exit(Paese + Codice);
        exit(GetText(XmlDoc, NsMgr, BasePath + '/CodiceFiscale'));
    end;

    local procedure ParseXmlDate(Value: Text): Date
    var
        Result: Date;
    begin
        // FatturaPA dates are xs:date (YYYY-MM-DD), which is exactly AL's XML format (9).
        if StrLen(Value) < 10 then
            exit(0D);
        if not Evaluate(Result, CopyStr(Value, 1, 10), 9) then
            exit(0D);
        exit(Result);
    end;

    local procedure ParseXmlDecimal(Value: Text): Decimal
    var
        Result: Decimal;
    begin
        if Value = '' then
            exit(0);
        // XML numeric content always uses '.' as decimal separator -> XML format (9).
        if not Evaluate(Result, Value, 9) then
            exit(0);
        exit(Result);
    end;
}
