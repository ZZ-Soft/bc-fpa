namespace ZZSoft.SDIBase;

codeunit 73005 "FE SdI Status Mgt."
{
    // Rolls the receipts of an invoice up into a single outcome on the invoice record.
    //
    // Receipts and invoices can arrive in any order - a receipt is often imported before
    // anyone gets round to importing the invoice - so the status is recomputed from scratch
    // every time any file with that base name is imported or deleted, rather than being
    // nudged incrementally. Cheap, and it cannot drift.

    /// <summary>
    /// Recomputes the SdI status of the invoice(s) with this base name from what is in the table.
    /// </summary>
    procedure UpdateInvoiceStatus(BaseName: Code[250])
    var
        Receipts: Record "FE Xml File";
    begin
        if BaseName = '' then
            exit;
        Receipts.SetRange("SdI Base Name", BaseName);
        Receipts.SetRange("File Type", Receipts."File Type"::Receipt);
        UpdateInvoiceStatusFrom(BaseName, Receipts);
    end;

    /// <summary>
    /// Same, but over a caller-supplied set of receipts. Used by OnDelete, which has to
    /// exclude the receipt currently being deleted - it is still in the table at that point.
    /// </summary>
    procedure UpdateInvoiceStatusFrom(BaseName: Code[250]; var Receipts: Record "FE Xml File")
    var
        Invoice: Record "FE Xml File";
        NewStatus: Enum "FE SdI Status";
    begin
        if BaseName = '' then
            exit;

        NewStatus := DeriveStatus(Receipts);

        Invoice.SetRange("SdI Base Name", BaseName);
        Invoice.SetRange("File Type", Invoice."File Type"::Invoice);
        // FindSet(true): the loop modifies what it reads. A plain FindSet takes a read-only
        // recordset, and modifying inside it is how you get "another user has modified the
        // record" on a system with exactly one user.
        if not Invoice.FindSet(true) then
            exit;
        repeat
            if (Invoice."SdI Status" <> NewStatus) and not KeepsCurrentStatus(Invoice, NewStatus) then begin
                Invoice."SdI Status" := NewStatus;
                Invoice.Modify(true);
            end;
        until Invoice.Next() = 0;
    end;

    /// <summary>
    /// Guards the one direction this must never move in: BACKWARDS into Draft.
    ///
    /// DeriveStatus returns the blank value when no receipt says anything, and blank is Draft.
    /// For a file we sent that is wrong twice over - it has gone to SdI, and Draft would make it
    /// deletable again - so a sales export keeps whatever it had. An uploaded file has no such
    /// history to protect: deleting its last receipt legitimately takes it back to unknown.
    /// </summary>
    local procedure KeepsCurrentStatus(var Invoice: Record "FE Xml File"; NewStatus: Enum "FE SdI Status"): Boolean
    begin
        if NewStatus <> NewStatus::" " then
            exit(false);
        exit(Invoice.Origin = Invoice.Origin::"Sales Export");
    end;

    /// <summary>
    /// The SdI flow runs in stages, and a later stage overrides an earlier one:
    ///
    ///   1. acceptance of the FILE      NS         rejected - the invoice never existed
    ///   2. delivery                    RC MC AT
    ///   3. outcome from the CUSTOMER   EC DT      public administration only
    ///
    /// So a customer outcome outranks a delivery receipt, and a rejection outranks everything:
    /// a file SdI threw out cannot later be "delivered" by a receipt that arrived first.
    ///
    /// EC and NE both carry the customer's Esito (EC01 accepted, EC02 refused) - NE is the
    /// same outcome relayed to the seller, so both are read the same way.
    /// SE is deliberately ignored: it says the customer's outcome message was malformed,
    /// which leaves the invoice where it was rather than moving it anywhere.
    /// </summary>
    local procedure DeriveStatus(var Receipts: Record "FE Xml File"): Enum "FE SdI Status"
    var
        HasRejection: Boolean;
        HasRefusedByCustomer: Boolean;
        HasAcceptedByCustomer: Boolean;
        HasTermsExpired: Boolean;
        HasAttestation: Boolean;
        HasFailedDelivery: Boolean;
        HasDelivery: Boolean;
        HasMetadata: Boolean;
    begin
        if Receipts.FindSet() then
            repeat
                case Receipts."Receipt Type" of
                    Receipts."Receipt Type"::NS:
                        HasRejection := true;
                    Receipts."Receipt Type"::MC:
                        HasFailedDelivery := true;
                    Receipts."Receipt Type"::RC:
                        HasDelivery := true;
                    Receipts."Receipt Type"::MT:
                        HasMetadata := true;
                    Receipts."Receipt Type"::AT:
                        HasAttestation := true;
                    Receipts."Receipt Type"::DT:
                        HasTermsExpired := true;
                    Receipts."Receipt Type"::EC,
                    Receipts."Receipt Type"::NE:
                        if IsRefusal(Receipts.Esito) then
                            HasRefusedByCustomer := true
                        else
                            if Receipts.Esito <> '' then
                                HasAcceptedByCustomer := true;
                end;
            until Receipts.Next() = 0;

        if HasRejection then
            exit(Enum::"FE SdI Status"::Rejected);
        if HasRefusedByCustomer then
            exit(Enum::"FE SdI Status"::"Refused by Customer");
        if HasAcceptedByCustomer then
            exit(Enum::"FE SdI Status"::"Accepted by Customer");
        if HasTermsExpired then
            exit(Enum::"FE SdI Status"::"Terms Expired");
        if HasAttestation then
            exit(Enum::"FE SdI Status"::"Transmission Attested");
        if HasFailedDelivery then
            exit(Enum::"FE SdI Status"::"Not Delivered");
        if HasDelivery then
            exit(Enum::"FE SdI Status"::Delivered);
        if HasMetadata then
            exit(Enum::"FE SdI Status"::"Metadata Notified");
        exit(Enum::"FE SdI Status"::" ");
    end;

    local procedure IsRefusal(EsitoCode: Code[10]): Boolean
    var
        RefusalTok: Label 'EC02', Locked = true;
    begin
        exit(UpperCase(EsitoCode) = RefusalTok);
    end;
}
