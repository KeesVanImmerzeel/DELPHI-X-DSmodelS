unit UTESTdsModelS;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  UdsModelS, StdCtrls;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Label1: TLabel;
    Button2: TButton;
    Edit1: TEdit;
    Label2: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  model: TDSmodels;

implementation

{$R *.DFM}

procedure TForm1.Button1Click(Sender: TObject);
var
  IErr: Integer;
begin
  model := TDSmodels.Create( StrToInt( Edit1.text ), IErr );
  Label1.Caption := 'Result= ' + IntToStr( IErr );
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  try model.Free except end;
  Label1.Caption := 'Result=?';
end;

end.
