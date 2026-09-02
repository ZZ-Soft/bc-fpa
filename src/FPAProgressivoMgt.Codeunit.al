namespace ZZSoft.SDIBase;

using Microsoft.Foundation.Address;
using Microsoft.Foundation.Company;

codeunit 73006 "FE Progressivo Mgt."
{
    // Builds the SdI file name for an outgoing invoice:
    //
    //     <IdPaese><IdCodice>_<progressivo>.xml        e.g. IT02155810225_HV1GH.xml
    //      \___ Company Information ___/  \_ 5 chars _/
    //
    // The progressive only has to be unique per transmitter, forever. It is NOT required to
    // equal DatiTrasmissione/ProgressivoInvio inside the XML - matching them is tidier, and
    // that is what the "From Document" source does.

    var
        Base36Tok: Label '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', Locked = true;
        SequenceNameTok: Label 'FE-PROGRESSIVO', Locked = true;
        FileNameTok: Label '%1_%2.xml', Locked = true;
        NoUniqueNameErr: Label 'Could not build a unique file name for transmitter %1 after %2 attempts.', Comment = '%1 = transmitter id, %2 = attempts';
        VatTooShortErr: Label 'The VAT Registration No. on Company Information is too short to build an SdI file name.';

    /// <summary>
    /// Number of characters in the progressive. Five is what SdI files use in practice and
    /// what ProgressivoInvio allows at most ([A-Za-z0-9]{1,5}).
    /// </summary>
    procedure ProgressivoLength(): Integer
    begin
        exit(5);
    end;

    local procedure MaxAttempts(): Integer
    begin
        exit(20);
    end;

    /// <summary>
    /// Returns a file name that is not yet present in "FE Xml File".
    /// DocumentProgressivo is the ProgressivoInvio read out of the generated XML; it is only
    /// used when the setup asks for it.
    /// </summary>
    procedure NextFileName(ProgressivoSource: Enum "FE Progressivo Source"; DocumentProgressivo: Code[10]) FileName: Code[250]
    var
        XmlFile: Record "FE Xml File";
        TransmitterId: Text;
        Progressivo: Text;
        Attempt: Integer;
    begin
        TransmitterId := GetTransmitterId();

        for Attempt := 1 to MaxAttempts() do begin
            Progressivo := BuildProgressivo(ProgressivoSource, DocumentProgressivo, Attempt);
            FileName := CopyStr(UpperCase(StrSubstNo(FileNameTok, TransmitterId, Progressivo)), 1, MaxStrLen(FileName));
            if not XmlFile.Get(FileName) then
                exit(FileName);
        end;

        Error(NoUniqueNameErr, TransmitterId, MaxAttempts());
    end;

    /// <summary>
    /// Draws the next progressive on its own, without building the file name yet.
    ///
    /// Needed when this extension GENERATES the XML rather than filing one it was handed:
    /// DatiTrasmissione/ProgressivoInvio has to be known before the document is written, and
    /// the file name has to end up with the same value. Drawing it once and passing it to both
    /// is the only way the two cannot drift apart.
    ///
    /// The value returned is one whose file name is still free.
    /// </summary>
    procedure NextProgressivo(): Code[10]
    var
        SalesExportSetup: Record "FE Sales Export Setup";
        XmlFile: Record "FE Xml File";
        Progressivo: Code[10];
        Attempt: Integer;
    begin
        SalesExportSetup.GetSetup();

        for Attempt := 1 to MaxAttempts() do begin
            // '' as the document progressive: there is no document to read one from - we are
            // about to write it - so "From Document" falls through to the counter.
            Progressivo := CopyStr(BuildProgressivo(SalesExportSetup."Progressivo Source", '', Attempt), 1, 10);
            if not XmlFile.Get(FileNameFor(Progressivo)) then
                exit(Progressivo);
        end;

        Error(NoUniqueNameErr, GetTransmitterId(), MaxAttempts());
    end;

    /// <summary>
    /// The SdI file name for a progressive already drawn.
    /// </summary>
    procedure FileNameFor(Progressivo: Code[10]) FileName: Code[250]
    begin
        FileName := CopyStr(UpperCase(StrSubstNo(FileNameTok, GetTransmitterId(), Progressivo)), 1, MaxStrLen(FileName));
    end;

    /// <summary>
    /// IdPaese + IdCodice of the transmitter, concatenated, for the SdI file name.
    /// </summary>
    procedure GetTransmitterId(): Text
    var
        IdPaese: Code[10];
        IdCodice: Text;
    begin
        GetTransmitter(IdPaese, IdCodice);
        exit(IdPaese + IdCodice);
    end;

    /// <summary>
    /// The two halves separately, for DatiTrasmissione/IdTrasmittente in the XML.
    ///
    /// Same derivation as the file name on purpose: the name says who transmitted the file
    /// and so does the document, and a mismatch between the two is the kind of thing SdI
    /// notices and nobody spots by reading the invoice.
    /// </summary>
    procedure GetTransmitter(var IdPaese: Code[10]; var IdCodice: Text)
    var
        CompanyInformation: Record "Company Information";
        CountryRegion: Record "Country/Region";
    begin
        CompanyInformation.Get();
        CompanyInformation.TestField("VAT Registration No.");
        CompanyInformation.TestField("Country/Region Code");

        // FatturaPA wants the ISO 3166-1 alpha-2 code. Business Central's Country/Region Code
        // is free-form and can differ from it, so prefer the ISO Code when one is set up.
        IdPaese := CompanyInformation."Country/Region Code";
        if CountryRegion.Get(CompanyInformation."Country/Region Code") then
            if CountryRegion."ISO Code" <> '' then
                IdPaese := CountryRegion."ISO Code";
        IdPaese := UpperCase(IdPaese);

        IdCodice := DelChr(UpperCase(CompanyInformation."VAT Registration No."), '=', ' .-/');

        // Italian companies normally store the VAT number bare, but some enter it with the
        // country prefix. Without this the name would come out as ITIT02155810225_...
        if StrLen(IdCodice) > StrLen(IdPaese) then
            if CopyStr(IdCodice, 1, StrLen(IdPaese)) = IdPaese then
                IdCodice := CopyStr(IdCodice, StrLen(IdPaese) + 1);

        if StrLen(IdCodice) < 2 then
            Error(VatTooShortErr);
    end;

    local procedure BuildProgressivo(ProgressivoSource: Enum "FE Progressivo Source"; DocumentProgressivo: Code[10]; Attempt: Integer): Text
    begin
        // On a retry the document's own progressive cannot help - it would collide again -
        // so any source falls back to the counter, which never repeats.
        if Attempt > 1 then
            if ProgressivoSource = ProgressivoSource::"From Document" then
                ProgressivoSource := ProgressivoSource::Sequential;

        case ProgressivoSource of
            ProgressivoSource::Sequential:
                exit(NextSequential());
            ProgressivoSource::Random:
                exit(RandomProgressivo());
            ProgressivoSource::"From Document":
                begin
                    if DocumentProgressivo <> '' then
                        exit(NormaliseProgressivo(DocumentProgressivo));
                    exit(NextSequential());
                end;
        end;

        exit(NextSequential());
    end;

    /// <summary>
    /// A counter rendered in base 36, so five characters cover 60,466,176 files.
    ///
    /// A counter rather than randomness on purpose: it cannot collide, so there is no retry
    /// loop that could in principle fail. NumberSequence values are handed out outside the
    /// transaction and are not rolled back, which is what we want - a progressive consumed by
    /// an export that then failed must never be handed out again.
    /// </summary>
    local procedure NextSequential(): Text
    var
        SalesExportSetup: Record "FE Sales Export Setup";
        NextValue: BigInteger;
    begin
        SalesExportSetup.GetSetup();

        if not NumberSequence.Exists(SequenceNameTok) then
            NumberSequence.Insert(SequenceNameTok, SalesExportSetup."Progressivo Start No.", 1);

        NextValue := NumberSequence.Next(SequenceNameTok);
        exit(ToBase36(NextValue, ProgressivoLength()));
    end;

    local procedure RandomProgressivo(): Text
    var
        Result: Text;
        Index: Integer;
    begin
        for Index := 1 to ProgressivoLength() do
            Result += CopyStr(Base36Tok, Random(StrLen(Base36Tok)), 1);
        exit(Result);
    end;

    /// <summary>
    /// Pads or trims a ProgressivoInvio taken from the document to the file-name length.
    /// </summary>
    local procedure NormaliseProgressivo(Progressivo: Code[10]): Text
    var
        Result: Text;
    begin
        Result := DelChr(UpperCase(Progressivo), '=', ' ');
        while StrLen(Result) < ProgressivoLength() do
            Result := '0' + Result;
        exit(CopyStr(Result, StrLen(Result) - ProgressivoLength() + 1, ProgressivoLength()));
    end;

    local procedure ToBase36(Value: BigInteger; TargetLength: Integer): Text
    var
        Result: Text;
        DigitValue: Integer;
        Index: Integer;
    begin
        // Wraps past 36^TargetLength. The caller checks the resulting name against the table,
        // so a wrap is caught rather than producing a duplicate.
        for Index := 1 to TargetLength do begin
            DigitValue := Value mod 36;
            Result := CopyStr(Base36Tok, DigitValue + 1, 1) + Result;
            Value := Value div 36;
        end;
        exit(Result);
    end;
}
