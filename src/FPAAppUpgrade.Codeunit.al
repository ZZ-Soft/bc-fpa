namespace ZZSoft.SDIBase;

using Microsoft.EServices.EDocument;


codeunit 73048 "ZZS FE App Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    begin
        // Code for company related operations
        Codeunit.Run(73099);

    end;

    trigger OnValidateUpgradePerDatabase()
    begin
        //MetodiDiPagamento();
    end;

}