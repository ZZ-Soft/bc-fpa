namespace ZZSoft.FPA;

enum 73006 "FPA Source Doc. Type"
{
    Extensible = true;
    Caption = 'Source Document Type';

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; "Sales Invoice")
    {
        Caption = 'Sales Invoice';
    }
    value(2; "Sales Credit Memo")
    {
        Caption = 'Sales Credit Memo';
    }
}
