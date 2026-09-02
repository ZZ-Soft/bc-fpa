namespace ZZSoft.SDIBase;

enum 73003 "FE SDI Status"
{
    // Where an invoice got to at SDI, derived from the receipts sharing its base name.
    //
    // The flow has two stages. SDI first accepts or rejects the file (NS), then tries to
    // deliver it (RC / MC / AT). For a public administration a third stage follows: the
    // recipient accepts or refuses (EC), or the deadline passes (DT). A later stage overrides
    // an earlier one - except a rejection, which means the invoice never existed.

    Extensible = true;
    Caption = 'SDI Status';

    value(0; " ")
    {
        // Just uploaded the file, can be deleted or modified. No receipt yet.
        Caption = 'Draft';
    }
    value(1; "Sent")
    {
        //Sent to SDI, waiting for a receipt. The file is locked and cannot be modified or deleted.
        Caption = 'Sent (waiting for receipt)';
    }
    value(2; Delivered)
    {
        // SDI has accepted the file and delivered it to the recipient. The file is locked and cannot be modified or deleted.
        Caption = 'Delivered';
    }
    value(3; Rejected)
    {
        // SDI has rejected the file.
        Caption = 'Rejected';
    }
    value(4; "Not Delivered")
    {
        Caption = 'Not Delivered';
    }
    value(5; "Metadata Notified")
    {
        Caption = 'Metadata Notified';
    }
    value(6; "Accepted by Customer")
    {
        Caption = 'Accepted by Customer';
    }
    value(7; "Refused by Customer")
    {
        Caption = 'Refused by Customer';
    }
    value(8; "Terms Expired")
    {
        Caption = 'Terms Expired (deemed accepted)';
    }
    value(9; "Transmission Attested")
    {
        Caption = 'Transmission Attested (not deliverable)';
    }
}
