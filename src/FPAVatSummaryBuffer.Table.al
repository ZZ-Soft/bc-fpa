namespace ZZSoft.FPA;

table 73005 "FPA VAT Summary Buffer"
{
    // Collects the DatiRiepilogo blocks while the document lines are being written.
    //
    // FatturaPA wants ONE DatiRiepilogo per combination of rate, nature and VAT chargeability,
    // with the bases and the tax already summed - SdI rejects the same combination twice. That
    // is a grouping, and the lines arrive in whatever order the document has them, so they are
    // accumulated here first and written afterwards.
    //
    // TableType = Temporary: this never touches the database. It exists only to give the
    // grouping a key the runtime can maintain, which is cheaper and clearer than scanning the
    // lines once per rate.

    Caption = 'FatturaPA VAT Summary Buffer';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "VAT %"; Decimal)
        {
            Caption = 'VAT %';
            DecimalPlaces = 0 : 5;
        }
        field(2; Natura; Code[4])
        {
            Caption = 'Natura';
            ToolTip = 'The exemption code - N1 to N7 - that has to be there whenever the rate is zero.';
        }
        field(3; "Esigibilita IVA"; Code[1])
        {
            Caption = 'Esigibilita IVA';
            ToolTip = 'I for immediate, D for deferred, S for split payment.';
        }
        field(10; "Imponibile Importo"; Decimal)
        {
            Caption = 'Imponibile Importo';
        }
        field(11; Imposta; Decimal)
        {
            Caption = 'Imposta';
        }
        field(20; "Riferimento Normativo"; Text[100])
        {
            Caption = 'Riferimento Normativo';
        }
        field(30; "Sort Order"; Integer)
        {
            Caption = 'Sort Order';
            ToolTip = 'The position of the first line that fed this group, so the summary comes out in the order of the document rather than by rate.';
        }
    }

    keys
    {
        key(PK; "VAT %", Natura, "Esigibilita IVA")
        {
            Clustered = true;
        }
        key(DocumentOrder; "Sort Order")
        {
        }
    }

    /// <summary>
    /// Adds one line's contribution to its group, creating the group the first time it is seen.
    /// </summary>
    procedure Accumulate(VatPct: Decimal; NaturaCode: Code[4]; Esigibilita: Code[1]; Base: Decimal; Tax: Decimal; RiferimentoNormativo: Text; LinePosition: Integer)
    begin
        if not Rec.Get(VatPct, NaturaCode, Esigibilita) then begin
            Rec.Init();
            Rec."VAT %" := VatPct;
            Rec.Natura := NaturaCode;
            Rec."Esigibilita IVA" := Esigibilita;
            Rec."Riferimento Normativo" := CopyStr(RiferimentoNormativo, 1, MaxStrLen(Rec."Riferimento Normativo"));
            Rec."Sort Order" := LinePosition;
            Rec.Insert();
        end;

        Rec."Imponibile Importo" += Base;
        Rec.Imposta += Tax;

        // A group can be met first on a line that has no wording set up and later on one that
        // has: keep the first one that says something.
        if Rec."Riferimento Normativo" = '' then
            Rec."Riferimento Normativo" := CopyStr(RiferimentoNormativo, 1, MaxStrLen(Rec."Riferimento Normativo"));

        Rec.Modify();
    end;
}
