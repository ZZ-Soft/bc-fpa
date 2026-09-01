namespace ZZSoft.SDIBase;

enum 73000 "FE Validation Status"
{
    Extensible = true;
    Caption = 'FatturaPA Validation Status';

    value(0; " ")
    {
        Caption = 'Not Validated';
    }
    value(1; Valid)
    {
        Caption = 'Valid';
    }
    value(2; Invalid)
    {
        Caption = 'Invalid';
    }
    value(3; "Not Well Formed")
    {
        Caption = 'Not Well Formed';
    }
}
