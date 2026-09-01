pageextension 73097 "Posted Sales Invoice - UpdExt" extends "Posted Sales Invoice - Update"
{

    layout
    {
        // Add changes to page layout here
        addafter("Fattura Document Type")
        {
            field("Payment Method Code"; Rec."Payment Method Code")
            {
                ApplicationArea = All;
            }
        }
    }

}