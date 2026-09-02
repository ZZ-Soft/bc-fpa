namespace ZZSoft.FPA;

using Microsoft.EServices.EDocument;


codeunit 73049 "FPA App Installer"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    begin
        // Code for company related operations
        //MetodiDiPagamento();
    end;

    trigger OnInstallAppPerDatabase()
    begin
        //MetodiDiPagamento();
    end;


}