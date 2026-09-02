namespace ZZSoft.FPA;

codeunit 73004 "FPA File Name Parser"
{
    // Tells an invoice from an SdI receipt purely by file name.
    //
    //   IT02155810225_HV1GH.xml              1 underscore  -> invoice
    //   IT02155810225_HV1GH_RC_003.xml       more          -> receipt of that invoice
    //                 ^base^      ^^ ^^^
    //                             |  progressive
    //                             receipt type
    //
    // The rule holds because neither part of the invoice name can contain an underscore:
    // it is IdPaese + IdCodice (letters and digits) + '_' + ProgressivoInvio ([A-Za-z0-9]{1,5}).
    //
    // The shared prefix - "SdI Base Name" - is what links a receipt back to its invoice.
    // It is stored WITHOUT extension on purpose: an invoice can arrive as .xml or .xml.p7m
    // while its receipts are always .xml, so joining on the full file name would break.

    var
        RcTok: Label 'RC', Locked = true;
        NsTok: Label 'NS', Locked = true;
        McTok: Label 'MC', Locked = true;
        MtTok: Label 'MT', Locked = true;
        NeTok: Label 'NE', Locked = true;
        EcTok: Label 'EC', Locked = true;
        SeTok: Label 'SE', Locked = true;
        DtTok: Label 'DT', Locked = true;
        AtTok: Label 'AT', Locked = true;

    /// <summary>
    /// Splits a file name into its SdI parts. ReceiptCode and ReceiptProgressive stay blank
    /// for an invoice.
    /// </summary>
    procedure Parse(FileName: Text; var FileType: Enum "FPA File Type"; var SdiBaseName: Code[250]; var ReceiptCode: Code[10]; var ReceiptProgressive: Code[10])
    var
        Segments: List of [Text];
        BaseName: Text;
    begin
        FileType := FileType::Unknown;
        SdiBaseName := '';
        ReceiptCode := '';
        ReceiptProgressive := '';

        BaseName := StripExtension(FileName);
        if BaseName = '' then
            exit;

        Segments := BaseName.Split('_');

        case Segments.Count() of
            2:
                begin
                    FileType := FileType::Invoice;
                    SdiBaseName := CopyStr(UpperCase(BaseName), 1, MaxStrLen(SdiBaseName));
                end;
            // 3 segments: a receipt without the progressive suffix. Rare, but SdI has emitted
            // them, and treating it as Unknown would orphan it from its invoice.
            3, 4:
                begin
                    FileType := FileType::Receipt;
                    SdiBaseName := CopyStr(UpperCase(Segments.Get(1) + '_' + Segments.Get(2)), 1, MaxStrLen(SdiBaseName));
                    ReceiptCode := CopyStr(UpperCase(Segments.Get(3)), 1, MaxStrLen(ReceiptCode));
                    if Segments.Count() = 4 then
                        ReceiptProgressive := CopyStr(Segments.Get(4), 1, MaxStrLen(ReceiptProgressive));
                end;
            else
                SdiBaseName := CopyStr(UpperCase(BaseName), 1, MaxStrLen(SdiBaseName));
        end;
    end;

    /// <summary>
    /// Removes .xml, .p7m or the .xml.p7m pair. Case-insensitive.
    /// </summary>
    procedure StripExtension(FileName: Text) Result: Text
    var
        LowerName: Text;
    begin
        Result := FileName;
        LowerName := LowerCase(Result);

        if LowerName.EndsWith('.p7m') then begin
            Result := CopyStr(Result, 1, StrLen(Result) - 4);
            LowerName := LowerCase(Result);
        end;
        if LowerName.EndsWith('.xml') then
            Result := CopyStr(Result, 1, StrLen(Result) - 4);
    end;

    /// <summary>
    /// Maps the two-letter code to the enum. Unrecognised codes become Other - the raw code
    /// is still kept on the record, so no receipt is ever silently dropped.
    /// </summary>
    procedure ReceiptTypeFromCode(ReceiptCode: Code[10]): Enum "FPA Receipt Type"
    var
        NormalisedCode: Code[10];
    begin
        NormalisedCode := UpperCase(ReceiptCode);

        if NormalisedCode = '' then
            exit(Enum::"FPA Receipt Type"::" ");
        if NormalisedCode = RcTok then
            exit(Enum::"FPA Receipt Type"::RC);
        if NormalisedCode = NsTok then
            exit(Enum::"FPA Receipt Type"::NS);
        if NormalisedCode = McTok then
            exit(Enum::"FPA Receipt Type"::MC);
        if NormalisedCode = MtTok then
            exit(Enum::"FPA Receipt Type"::MT);
        if NormalisedCode = NeTok then
            exit(Enum::"FPA Receipt Type"::NE);
        if NormalisedCode = EcTok then
            exit(Enum::"FPA Receipt Type"::EC);
        if NormalisedCode = SeTok then
            exit(Enum::"FPA Receipt Type"::SE);
        if NormalisedCode = DtTok then
            exit(Enum::"FPA Receipt Type"::DT);
        if NormalisedCode = AtTok then
            exit(Enum::"FPA Receipt Type"::AT);

        exit(Enum::"FPA Receipt Type"::Other);
    end;

    /// <summary>
    /// Second opinion from the XML itself: the root element name of an SdI message.
    /// Used when the file name does not carry a recognisable code - the name is the rule, this
    /// only fills the gaps.
    ///
    /// TWO schema families are in circulation and both are legitimate:
    ///
    ///   MessaggiTypes_v1.1.xsd   ns http://www.fatturapa.gov.it/sdi/messaggi/v1.0
    ///                            NotificaScarto, NotificaMancataConsegna, MetadatiInvioFile,
    ///                            plus the five types the other family does not define
    ///   SDIRicevute.xsd          ns http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fattura/messaggi/v1.0
    ///                            RicevutaScarto, RicevutaImpossibilitaRecapito, FileMetadati
    ///
    /// RicevutaConsegna is spelled the same in both. The rest are not, so both spellings are
    /// mapped here - the receipts ZZ Soft actually receives come from the second family.
    /// </summary>
    procedure ReceiptCodeFromRootName(RootLocalName: Text): Code[10]
    begin
        case RootLocalName of
            'RicevutaConsegna':
                exit(RcTok);
            'NotificaScarto',
            'RicevutaScarto':
                exit(NsTok);
            'NotificaMancataConsegna',
            'RicevutaImpossibilitaRecapito':
                exit(McTok);
            'MetadatiInvioFile',
            'FileMetadati':
                exit(MtTok);
            'NotificaEsito':
                exit(NeTok);
            'NotificaEsitoCommittente':
                exit(EcTok);
            'ScartoEsitoCommittente':
                exit(SeTok);
            'NotificaDecorrenzaTermini':
                exit(DtTok);
            'AttestazioneTrasmissioneFattura':
                exit(AtTok);
        end;
        exit('');
    end;

    /// <summary>
    /// Key of the compiled stylesheet that renders a given receipt code, or '' when there is
    /// none. Kept next to the code mapping so the two cannot drift apart.
    /// </summary>
    procedure StylesheetKeyForReceipt(ReceiptCode: Code[10]): Text
    var
        NormalisedCode: Code[10];
    begin
        NormalisedCode := UpperCase(ReceiptCode);
        if ReceiptTypeFromCode(NormalisedCode) = Enum::"FPA Receipt Type"::Other then
            exit('');
        exit(NormalisedCode);
    end;
}
