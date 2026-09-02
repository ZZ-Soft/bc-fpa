codeunit 73099 "FE Base"
{

    trigger OnRun()
    var
        lblMsgInizio: Label 'Aggiornamento codici FE';
        lblMsgFine: Label 'Aggiornamento codici FE completato';
    begin
        Message(lblMsgInizio);
        FECodiciPAgamenti();
        FECodNaturaIVA();
        Message(lblMsgFine);
    end;

    local procedure FECodiciPAgamenti()
    begin
        UpdateMPRecord('MP01', 'contanti');
        UpdateMPRecord('MP02', 'assegno');
        UpdateMPRecord('MP03', 'assegno circolare');
        UpdateMPRecord('MP04', 'contanti presso Tesoreria');
        UpdateMPRecord('MP05', 'bonifico');
        UpdateMPRecord('MP06', 'vaglia cambiario');
        UpdateMPRecord('MP07', 'bollettino bancario');
        UpdateMPRecord('MP08', 'carta di pagamento');
        UpdateMPRecord('MP09', 'RID');
        UpdateMPRecord('MP10', 'RID utenze');
        UpdateMPRecord('MP11', 'RID veloce');
        UpdateMPRecord('MP12', 'RIBA');
        UpdateMPRecord('MP13', 'MAV');
        UpdateMPRecord('MP14', 'quietanza erario');
        UpdateMPRecord('MP15', 'giroconto su conti di contabilità speciale');
        UpdateMPRecord('MP16', 'domiciliazione bancaria');
        UpdateMPRecord('MP17', 'domiciliazione postale');
        UpdateMPRecord('MP18', 'bollettino di c/c postale');
        UpdateMPRecord('MP19', 'SEPA Direct Debit');
        UpdateMPRecord('MP20', 'SEPA Direct Debit CORE');
        UpdateMPRecord('MP21', 'SEPA Direct Debit B2B');
        UpdateMPRecord('MP22', 'Trattenuta su somme già riscosse');
        UpdateMPRecord('MP23', 'PagoPA');

        UpdateTPRecord('TP01', 'pagamento a rate');
        UpdateTPRecord('TP02', 'pagamento completo');
        UpdateTPRecord('TP03', 'anticipo');


    end;

    local procedure FECodNaturaIVA()
    begin
        UpdateVNRecord('N1', 'escluse ex art. 15 del DPR 633/72');
        UpdateVNRecord('N2.1', 'non soggette ad IVA ai sensi degli artt. da 7 a 7-septies del DPR 633/72');
        UpdateVNRecord('N2.2', 'non soggette - altri casi');
        UpdateVNRecord('N3.1', 'non imponibili - esportazioni');
        UpdateVNRecord('N3.2', 'non imponibili - cessioni intracomunitarie');
        UpdateVNRecord('N3.3', 'non imponibili - cessioni verso San Marino');
        UpdateVNRecord('N3.4', 'non imponibili - operazioni assimilate alle cessioni all''esportazione');
        UpdateVNRecord('N3.5', 'non imponibili - a seguito di dichiarazioni d''intento');
        UpdateVNRecord('N3.6', 'non imponibili - altre operazioni che non concorrono alla formazione del plafond');
        UpdateVNRecord('N4', 'esenti');
        UpdateVNRecord('N5', 'regime del margine / IVA non esposta in fattura');
        UpdateVNRecord('N6.1', 'inversione contabile - cessione di rottami e altri materiali di recupero');
        UpdateVNRecord('N6.2', 'inversione contabile - cessione di oro e argento ai sensi della legge 7/2000 nonché di oreficeria usata ad OPO');
        UpdateVNRecord('N6.3', 'inversione contabile - subappalto nel settore edile');
        UpdateVNRecord('N6.4', 'inversione contabile - cessione di fabbricati');
        UpdateVNRecord('N6.5', 'inversione contabile - cessione di telefoni cellulari');
        UpdateVNRecord('N6.6', 'inversione contabile - cessione di prodotti elettronici');
        UpdateVNRecord('N6.7', 'inversione contabile - prestazioni comparto edile e settori connessi');
        UpdateVNRecord('N6.8', 'inversione contabile - operazioni settore energetico');
        UpdateVNRecord('N6.9', 'inversione contabile - altri casi');
        UpdateVNRecord('N7', 'IVA assolta in altro stato UE (prestazione di servizi di telecomunicazioni, tele-radiodiffusione ed elettronici ex art. 7-octies, comma 1 lett. a, b, art. 74-sexies DPR 633/72)');

    end;

    local procedure UpdateMPRecord(cod: code[4]; desc: Text[250])
    var
        recMpCode: Record "Fattura Code";
    begin
        recMpCode.Init();
        if (recMpCode.get(cod, "Fattura Code Type"::"Payment Method")) then begin
            if (recMpCode.Description <> desc) then begin
                recMpCode.Description := desc;
                recMpCode.Modify(true);
            end;
        end
        else begin
            recMpCode.Init();
            recMpCode.Validate("Code", cod);
            recMpCode.Validate(Type, "Fattura Code Type"::"Payment Method");
            recMpCode.Validate(Description, desc);
            recMpCode.Insert();
        end;
    end;

    local procedure UpdateTPRecord(cod: code[4]; desc: Text[250])
    var
        recMpCode: Record "Fattura Code";
    begin
        recMpCode.Init();
        if (recMpCode.get(cod, "Fattura Code Type"::"Payment Terms")) then begin
            if (recMpCode.Description <> desc) then begin
                recMpCode.Description := desc;
                recMpCode.Modify(true);
            end;
        end
        else begin
            recMpCode.Init();
            recMpCode.Validate("Code", cod);
            recMpCode.Validate(Type, "Fattura Code Type"::"Payment Terms");
            recMpCode.Validate(Description, desc);
            recMpCode.Insert();
        end;
    end;

    local procedure UpdateVNRecord(cod: code[4]; desc: Text[250])
    var
        recVNCode: Record "VAT Transaction Nature";
    begin
        recVNCode.Init();
        if (recVNCode.get(cod)) then begin
            if (recVNCode.Description <> desc) then begin
                recVNCode.Description := desc;
                recVNCode.Modify(true);
            end;
        end
        else begin
            recVNCode.Init();
            recVNCode.Validate("Code", cod);
            recVNCode.Validate(Description, desc);
            recVNCode.Insert();
        end;
    end;

}