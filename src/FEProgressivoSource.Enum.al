namespace ZZSoft.SDIBase;

enum 73005 "FE Progressivo Source"
{
    // How the 5-character progressive in the file name is produced.
    //
    // FatturaPA names a file <IdPaese><IdCodice>_<progressivo>.xml, where the progressive
    // only has to be unique per transmitter - it is NOT required to equal the
    // DatiTrasmissione/ProgressivoInvio inside the XML, though matching them is tidier.

    Extensible = true;
    Caption = 'Progressive Source';

    value(0; Sequential)
    {
        Caption = 'Sequential';
    }
    value(1; Random)
    {
        Caption = 'Random';
    }
    value(2; "From Document")
    {
        Caption = 'From Document (ProgressivoInvio)';
    }
}
