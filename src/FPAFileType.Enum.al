namespace ZZSoft.FPA;

enum 73001 "FPA File Type"
{
    Extensible = true;
    Caption = 'FatturaPA File Type';

    value(0; Unknown)
    {
        Caption = 'Unknown';
    }
    value(1; Invoice)
    {
        Caption = 'Invoice';
    }
    value(2; Receipt)
    {
        Caption = 'Receipt';
    }
}
