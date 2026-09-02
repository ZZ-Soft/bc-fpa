namespace ZZSoft.FPA;

enum 73004 "FPA File Origin"
{
    Extensible = true;
    Caption = 'File Origin';

    value(0; Upload)
    {
        Caption = 'Upload';
    }
    value(1; "Sales Export")
    {
        Caption = 'Sales Export';
    }
}
