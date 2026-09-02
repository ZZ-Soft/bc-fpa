namespace ZZSoft.FPA;

using Microsoft.Sales.Document;

codeunit 73088 "FPA Sales Header Subscriber"
{
    [EventSubscriber(ObjectType::Table, Database::"Sales Header", OnBeforeSendToPosting, '', false, false)]
    local procedure OnBeforeSendToPosting(var SalesHeader: Record "Sales Header"; var IsSuccess: Boolean; var IsHandled: Boolean; PostingCodeunitID: Integer)
    var
        msgPaymentMethodMandatory: Label 'Payment Method Code is mandatory';
        msgPaymentTermsMandatory: Label 'Payment Terms Code is mandatory';
    begin
        if (SalesHeader."Payment Method Code" = '') then
            Error(msgPaymentMethodMandatory);
        if (SalesHeader."Payment Terms Code" = '') then
            Error(msgPaymentTermsMandatory);
        SalesHeader.TestField("Payment Method Code");
        SalesHeader.TestField("Payment Terms Code");
    end;

}