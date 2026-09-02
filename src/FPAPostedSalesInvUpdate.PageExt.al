namespace ZZSoft.FPA;

using Microsoft.Sales.History;

pageextension 73097 "FPA Posted Sales Inv. Update" extends "Posted Sales Invoice - Update"
{

    layout
    {
        // Add changes to page layout here
        addafter("Fattura Document Type")
        {
            field(FPAPaymentMethodCode; Rec."Payment Method Code")
            {
                ApplicationArea = All;
            }
        }
    }

}