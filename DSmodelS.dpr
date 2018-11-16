library DSmodelS;
  {-Exports a procedure 'DSDriver' to create and handle an Instance of
    TDSmodels (=model). The shell can send predefined requests to 'model'.}

  { Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters.. }

{.$define test}

uses
  ShareMem,
  {$ifdef test}
  forms,
  {$endif }
  Windows,
  SysUtils,
  Classes,
  uINTodeClass,
  UdsModelS,
  uAlgRout,
  uError,
  Dialogs;

var
  Model: TDSmodelS;      {-Instance of TDSmodels}

Procedure DSDriver( var Settings, tTS, vTS, tResult, vResult: Real ); stdcall;
var
  SettingsArray: Array of Real;
  IErr: Integer;
  Area: Real;
  {$ifdef test}
  S: String;
  {$endif}

Function GetArea: Real;
var
  Pval: ^Real;
  i: Integer;
begin
  Pval := @Settings;
  for i:=0 to c_Area-1 do
    Inc( Pval );
  Result := Pval^;
end;

Procedure InitialiseSettingArray;
var
  Pval: ^Real;
  i: Integer;

  {$ifdef test}
  lf: textfile;
  {$endif}
begin
  {$ifdef test}
  Assignfile ( lf, 'dsmodels.log' ); rewrite( lf );
  writeln( lf, 'settingsarray:' );
  {$endif}
  Pval := @Settings;
  {$ifdef test}
  Writeln( lf, 'Pval^= ', Pval^ );
  Writeln( lf, 'Settings  =', Settings );
  {$endif}
  SetLength( SettingsArray, c_Length_Of_Settings_Array );
  for i:=0 to Length( SettingsArray )-1 do begin
    {Inc( Pval );} SettingsArray[ i ] := Pval^; Inc( Pval );
    {$ifdef test}
    writeln( lf, i, ' ', SettingsArray[ i ] );
    {$endif}
  end;
  {$ifdef test}
  Writeln( lf, 'Area=', GetArea );
  CloseFile( lf );
  {$endif}
end;

Procedure WriteSettingArray;
var
  Pval: ^Real;
  i: Integer;
begin
  Pval := @Settings; {Pval^ := Length( SettingsArray );}
  for i:=0 to Length( SettingsArray )-1 do begin
     Pval^ := SettingsArray[ i ]; Inc( Pval );
  end;
end;

Procedure FreeSettingsArray;
begin
  SetLength( SettingsArray, 0 );
end;

Function ModelNr: Integer;
begin
  Result := Trunc( SettingsArray[ c_ModelID ] );
end;

Function Request: Integer;
begin
  Result := Trunc( SettingsArray[ c_Request ] );
end;

Procedure SetErr( const IErr: Integer );
var
  Pval: ^Real;
begin
  Pval := @vResult; Pval^ := IErr;
end;

begin
  IErr := cNoError;
  InitialiseSettingArray;

  {$ifdef test}
//  S := 'Request: ' + IntToStr( Request );
//  Application.MessageBox( PChar( S ), 'Info', MB_OKCANCEL );
  {$endif}

  case Request of
    cRQInitialise:
      begin
        Try model.Destroy; except end;
        Model := TDSmodels.Create( ModelNr, IErr );
        if ( IErr <> cNoError ) then begin
          Try model.Destroy; except end;
        end else begin
          Model.OverWriteDefaultSettings( Trunc( SettingsArray[ c_MaxStp ] ),
                                          SettingsArray[ c_Htry ],
                                          SettingsArray[ c_Hmin ],
                                          SettingsArray[ c_Eps  ] );
          SettingsArray[ c_nRP ]     := Model.nRP;
          SettingsArray[ c_nSQ ]     := Model.nSQ;
          SettingsArray[ c_nRQ ]     := Model.nRQ;
          SettingsArray[ c_nResPar ] := Model.nResPar;
          WriteSettingArray;
        end;
      end;
    cRQRun:
      begin
        if Model.ModelIsLoaded then begin
          Try
           Area := GetArea;
             Model.Run( Area, tTS, vTS, tResult, vResult, IErr );
             {ShowMessage( IErr.tostring );}
          except
            IErr := cRequestToRunUninitialisedModel;
          end;
        end else begin
          IErr := cRequestToRunUninitialisedModel;
        end;
      end;
    cRQRFinalise:
      begin
        Try Model.Free; except end;
      end;
  else
    IErr := cInvalidRequest;
  end;

  FreeSettingsArray;
  SetErr( IErr );
end;

Exports DSDriver index 1;


end.
