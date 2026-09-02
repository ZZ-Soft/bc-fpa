namespace ZZSoft.FPA;

enum 73002 "FPA Receipt Type"
{
    // The two-letter code SdI appends to the invoice file name:
    //     IT02155810225_HV1GH_RC_003.xml   ->  delivery receipt of IT02155810225_HV1GH
    //
    // All nine types SdI can emit. An unrecognised code still lands as Other with the raw
    // code kept in "Receipt Type Code", so nothing is ever silently dropped.

    Extensible = true;
    Caption = 'Receipt Type';

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; RC)
    {
        Caption = 'RC - Ricevuta di consegna';
    }
    value(2; NS)
    {
        Caption = 'NS - Notifica di scarto';
    }
    value(3; MC)
    {
        Caption = 'MC - Notifica di mancata consegna';
    }
    value(4; MT)
    {
        Caption = 'MT - File dei metadati';
    }
    value(5; NE)
    {
        Caption = 'NE - Notifica esito cedente/prestatore';
    }
    value(6; EC)
    {
        Caption = 'EC - Notifica esito cessionario/committente';
    }
    value(7; SE)
    {
        Caption = 'SE - Notifica di scarto esito committente';
    }
    value(8; DT)
    {
        Caption = 'DT - Notifica decorrenza termini';
    }
    value(9; AT)
    {
        Caption = 'AT - Attestazione di trasmissione con impossibilita di recapito';
    }
    value(99; Other)
    {
        Caption = 'Other';
    }
}
