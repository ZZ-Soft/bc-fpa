namespace ZZSoft.FPA;

profile "FPA SDI"
{
    // Makes the role centre selectable from My Settings and assignable to users.
    // Without a profile the page exists but nobody can get to it.

    Caption = 'FatturaPA / SdI';
    ProfileDescription = 'Electronic invoicing for Italy: outgoing files and their SdI receipts, incoming invoices, and the setup they depend on.';
    RoleCenter = "FPA SDI Role Center";
    Enabled = true;
}
