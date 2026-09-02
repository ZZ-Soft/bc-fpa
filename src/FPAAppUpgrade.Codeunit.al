namespace ZZSoft.FPA;

using Microsoft.EServices.EDocument;


codeunit 73048 "FPA App Upgrade"
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