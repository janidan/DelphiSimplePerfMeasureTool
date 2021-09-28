object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 123
  ClientWidth = 500
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  PixelsPerInch = 96
  TextHeight = 13
  object Button1: TButton
    Left = 8
    Top = 16
    Width = 75
    Height = 25
    Caption = 'Code In Exe'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 89
    Top = 16
    Width = 75
    Height = 25
    Caption = 'Code In BPL'
    TabOrder = 1
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 170
    Top = 16
    Width = 75
    Height = 25
    Caption = 'Code in .Unit'
    TabOrder = 2
    OnClick = Button3Click
  end
  object Button4: TButton
    Left = 251
    Top = 16
    Width = 75
    Height = 25
    Caption = 'CallClass'
    TabOrder = 3
    OnClick = Button4Click
  end
  object Button5: TButton
    Left = 332
    Top = 16
    Width = 75
    Height = 25
    Caption = 'GenericClass'
    TabOrder = 4
    OnClick = Button5Click
  end
  object Button6: TButton
    Left = 251
    Top = 47
    Width = 75
    Height = 25
    Caption = 'CallClassMeth'
    TabOrder = 5
    OnClick = Button6Click
  end
  object Button7: TButton
    Left = 332
    Top = 47
    Width = 75
    Height = 25
    Caption = 'CallGenericMeth'
    TabOrder = 6
    OnClick = Button7Click
  end
  object Button8: TButton
    Left = 413
    Top = 16
    Width = 75
    Height = 25
    Caption = 'AnonMeth'
    TabOrder = 7
    OnClick = Button8Click
  end
  object Button9: TButton
    Left = 413
    Top = 47
    Width = 75
    Height = 25
    Caption = 'MetaAttr'
    TabOrder = 8
    OnClick = Button9Click
  end
end
