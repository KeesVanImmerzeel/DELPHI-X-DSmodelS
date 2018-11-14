unit UdsModelS;
  {-Class for dynamic simulation models linked to shell.}

interface
uses
  Windows, Classes, Forms, SysUtils, LargeArrays, UDSmodel, xyTable, DUtils,
  ExtParU, uError, uAlgRout, dialogs, Math;

{.$define test}
{.$define test3}
{.$define test4}

type
  PDouble = ^Double;
  TDSDriver = Procedure( var Settings, tTS, vTS, tResult, vResult: Real );
    {-Format of DSdriver routine (ref. DSmodfor.pas)}
  TDSmodels = Class( TDSmodel )
    private
    protected
    public
      Labels: TStringList; {-Lijst met Labels voor NResPar-berekeningsresulta-
                             ten }
      ModelIsLoaded: Boolean; {-True als er een model geladen is. De flag
                           'ReadyToRun' kan dan nog 'false' zijn omdat het model
                           nog RP* gegevens vanuit de schil nodig heeft om te
                           kunnen draaien}
      Function nRP: Integer; Virtual;
       {-Aant. vlak-tijdreeksen die het model verwacht van de schil. De waarde
         moet worden ingevuld door boot-procedure op EP[0]}
      Function nSQ: Integer; Virtual;
        {-Aant. punt-tijdreeksen die het model verwacht van de schil. De waarde
          moet worden ingevuld door boot-procedure op EP[0]}
      Function nRQ: Integer; Virtual;
        {-Aant. lijn-tijdreeksen die het model verwacht van de schil. De waarde
          moet worden ingevuld door boot-procedure op EP[0]}
      Function nTS: Integer; Virtual;
        {-Totaal aantal tijdreeksen dat van de shell wordt verwacht (>=0) }
      Function Area: Double; Virtual;
        {-Oppervlak van het representatieve gebied dat is geassocieerd met
          een punt. In een aan de Shell-gekoppeld model wordt de waarde op de
          EP[0]-array vervangen in de 'Run' procedure}
      Constructor Create( const ModelNr: Word; var IErr: Integer ); Reintroduce;
        {-Initiate Model from DLL-file }
      Destructor Destroy; Override;
      Procedure Run( var cArea, tTS, vTS, tResult, vResult: Real;
                var IErr: Integer ); Reintroduce;
      {-Do the integration on all time-intervals, assuming that the
        start is at x1=0. In- and output IS in 'shell' format (real-array's).
        Rem: Error-code in vResult array is NOT set to IErr by 'Run' }
      Procedure OverWriteDefaultSettings( const cMaxStp: Integer; const cHtry,
                cHmin, cEps: Double ); Virtual;
        {-Overschrijf enkele integratie-settings door waarden vanuit de Shell.
          Is op dit moment een 'lege huls'}
   end;

Function DefaultBootEPForShell( const
  cnRP,                  {-Nr. of RP-time series expected from shell}
  cnSQ,                  {-Nr. of point-time series expected from shell}
  cnRQ                   {-Nr. of line-time series expected from shell}
  : Integer;
  var Indx: Integer;     {-BootEPArrayVariantIndex}
  var EP:                {-EParray that is partially filled in this procedure}
  TExtParArray ): Integer;
  {-This general boot procedure sets default EP-values for shell usage}
  {-Rem.:
   - Fill OutputProcMatrix (=EP[0].xIndep.Items[1]) prior to calling this proce-
     dure!
   - ReadyToRun flag is NOT set by this procedure: the model may need more data
   from the shell}

Procedure ScaleTimesFromShell( const TimeMultFact: Double;
                               var EP: TExtParArray );
  {-Deze procedure kan worden aangeroepen vanuit de DerivsProc op het moment dat
    (Context = UpdateYstart). Op dat moment zijn immers alle tijdreeksen
    afkomstig van de shell aanwezig en is de simulatie nog (net) niet gestart.

    Vermenigvuldigt alle tijdstippen in de tijdreeksen die uit de schil
    afkomstig zijn (=EP[ cEP2 ].xDep) PLUS de uitvoertijdstippen
    (=EP[ cEP1 ].xInDep.Item[ 0 ]) met de opgegeven factor.
    }

Function Area( var EP: TExtParArray ): Double;
  {-Maakt het gegeven 'Area' beschikbaar voor de snelheidsprocedure}

Const
  cModelIndxForTDSmodels = 999;

  cEP2   = 2;               {-EP-Array-index reserved for models connected to Trishell}
  cBoot2 = cEP2 + 1;        {-Verander dit niet!}

  {-Mapping of Settings-array in TDSDriver routine (zero-based)}
  c_Length_Of_Settings_Array = 11; {-Length of Settings_Array}
  c_ModelID      = 0;  {-Modelnr. dat de schil wil initialiseren (input)}
  c_nRP         = 1;  {-Aantal RP-tijdreeksen dat het model van de schil
                        verwacht(output)}
  c_nSQ         = 2;  {-Aantal punt-tijdreeksen dat het model van de schil
                        verwacht(output)}
  c_nRQ         = 3;  {-Aantal lijn-tijdreeksen dat het model van de schil
                        verwacht(output)}
  c_nResPar     = 4;  {-Aantal uitvoer-tijdreeksen; wordt bepaald
                        door boot-procedure in dsmodel*.dll (output)}
  c_Request      = 5;  {-Type opdracht dat de schil wil uitvoeren (input,
                        zie hieronder)}
  c_MaxStp       = 6;  {-Max. aantal stappen voor integratie (input)
                        HIERMEE WORDT NOG NIKS GEDAAN: de input vanuit het
                        bestand *.EP0 wordt gebruikt}
  c_Htry         = 7;  {-Initiele stapgrootte [tijd](input)
                        HIERMEE WORDT NOG NIKS GEDAAN: de input vanuit het
                        bestand *.EP0 wordt gebruikt}
  c_Hmin         = 8;  {-Minimale stapgrootte [tijd](input)
                        HIERMEE WORDT NOG NIKS GEDAAN: de input vanuit het
                        bestand *.EP0 wordt gebruikt}
  c_Eps          = 9;  {-Nauwkeurigheidscriterium(input)
                        HIERMEE WORDT NOG NIKS GEDAAN: de input vanuit het
                        bestand *.EP0 wordt gebruikt}
  c_Area         = 10; {-Invloedsoppervlak (input)}

  {-Mogelijke waarden van cRequest}
  cRQInitialise = 1; {-Laadt het model uit dll; hierna is doorgaans de flag
                       'ReadyToRun' nog false, omdat het model nog tijdreeks-
                       gegevens vanuit de schil nodig heeft om te kunnen
                       draaien}
  cRQRun        = 2; {-Draai het model voor de gevraagde tijdstappen; extra
                       tijdreeks-gegevens worden door de shell aangeleverd}
  cRQRFinalise  = 3;

  cLabelFileNameExtension = '.lab';

  cNrOfDaysPerYear = 366;
  cFromDayToYear = 1 / cNrOfDaysPerYear;
   {-Invoer vanuit de Shell is doorgaans op dagbasis. Als het model op jaarbasis
     rekent kan deze fractie worden gebruikt in de aanroep van de procedure
     ScaleTimesFromShell om de schaal van de tijdreeksen van de Shell a.h. model
     aan te passen}

  {-Error codes that may be used by external TDSDriver-routine }
  cModelNotReady  = -909;
  cInvalidRequest = -910;
  cRequestToRunUninitialisedModel = -911;

  cCannotCreateHandleTo_DSmodfor_DLL = -912; {-uDSmodelS_Service_Routines}
  cCannotCreateHandleToDSDriver = -913;      {-uDSmodelS_Service_Routines}
  cRequestToInitialiseModelFailed = -914;    {-uDSmodelS_Service_Routines}
  cCallToDSDriverRoutineResultedInCriticalError = -915; {-uDSmodelS_Service_Routines}

Type
  ECannotCreateHandleTo_DSmodfor_DLL = class( Exception );
  ECannotCreateHandleToDSDriver = class( Exception );
  ERequestToInitialiseModelFailed = class( Exception );
  ERequestToInitialiseResultedInError = class( Exception );
  ECallToDSDriverRoutineResultedInCriticalError = class( Exception );

Resourcestring
  sCannotCreateHandleTo_DSmodfor_DLL = 'Cannot create handle to: "%s".';
  sCannotCreateHandleToDSDriver = 'Cannot create handle to routine "%s"';
  sRequestToInitialiseModelFailed = 'Request to IntialiseModel "%d" failed.';
  sRequestToInitialiseResultedInError = 'Request to IntialiseModel resulted in an Error "%d" failed.';
  sCallToDSDriverRoutineResultedInCriticalError = 'Call to DSDriver routine resulted in an critical Error.';

    {$ifdef test4}
var
  OutputCount: Integer;
  {$endif}
implementation

Const
  {-Internal Error-codes}
  cWrongModelType = -900;
  cWrongNTSout = -901;
  cNegativenRP = -902;
  cNegativenSQ = -903;
  cErrorUpdatingEP1 = -904;
  cErrorUpdatingEP2 = -905;
  cErrorCreatingResultBuf =-906;
  cNegativenRQ = -907;
  cErrorUpdatingEP0 = -908;


Constructor TDSmodels.Create( const ModelNr: Word; var IErr: Integer );
var
  DLLFileName, LabelFileName, S: String;
  i, nrLabelsRead: integer;
begin
  ModelIsLoaded := false;

  DLLFileName   := AlgRootDir + cDSmodelFileName + IntToStr( ModelNr ) + '.dll';
  {$ifdef test}
  ShowMessage( 'TDSmodels.Create. DLLFileName = ' + DLLFileName );
  {$endif}

  Inherited Create( DLLFileName, cModelIndxForTDSmodels,
                    cBoot2, IErr );
  {$ifdef test}
  Application.MessageBox( 'Inherited Create DONE', 'Info', MB_OKCANCEL );
  {$endif}

  if ( IErr = cNoError ) then begin
    {$ifdef test}
    Application.MessageBox( 'IErr=0', 'Info', MB_OKCANCEL );
    {$endif}
    if ( ModelID <> ModelNr ) then begin
      IErr := cWrongModelType;
      {$ifdef test}
      Application.MessageBox( 'IErr=cWrongModelType', 'Info', MB_OKCANCEL );
      {$endif}
      exit;
    end;
    if ( nRP < 0 ) then begin
      IErr := cNegativenRP; exit;
    end;
    if ( nSQ < 0 ) then begin
      IErr := cNegativenSQ; exit;
    end;
    if ( nRQ < 0 ) then begin
      IErr := cNegativenRQ; exit;
    end;

    {-Voeg tabel met uitvoertijd=0 in}
    EP[ cEP1 ].xIndep.Add( TDoubleMatrix.CreateF( 1, 1, 0, nil ) );

    {-Probeer labels uit tekstbestand te lezen; vul zonodig met default-waarden}
    LabelFileName := AlgRootDir + cDSbootFileName + IntToStr( ModelNr )
                   + cLabelFileNameExtension;
    Labels := TStringList.Create;
    Try Labels.LoadFromFile( PChar( LabelFileName ) );
    except;
      {-Blijf stil als het lezen van de labels niet is gelukt: niet zo
        belangrijk}
    end;
    nrLabelsRead := Labels.Count;
    for i:= nrLabelsRead+1 to NResPar do begin
      S := 'Result' + IntToStr( i );
      Labels.Add( PChar( S ) );
    end;
    {$ifdef test}
    Application.MessageBox( 'Labels initiated.', 'Info', MB_OKCANCEL );
    {$endif}

    ModelIsLoaded := true; {-Model is geladen}

  end;
end;

Destructor TDSmodels.Destroy;
begin
  ModelIsLoaded := false;
  try Labels.Clear; except end;
  Inherited Destroy;
end;

Function TDSmodels.nRP: Integer;
begin
  with EP[ cEP0 ].xInDep do
    Result := Trunc( Items[ 0 ].GetValue( cmpnRP, 1 ) );
end;

Function TDSmodels.nSQ: Integer;
begin
  with EP[ cEP0 ].xInDep do
    Result := Trunc( Items[ 0 ].GetValue( cmpnSQ, 1 ) );
end;

Function TDSmodels.nRQ: Integer;
begin
  with EP[ cEP0 ].xInDep do
    Result := Trunc( Items[ 0 ].GetValue( cmpnRQ, 1 ) );
end;

Function TDSmodels.Area: Double;
begin
  with EP[ cEP0 ].xInDep do
    Result := Items[ 0 ].GetValue( cmpArea, 1 );
end;

Function TDSmodels.nTS: Integer;
begin
  Result := nRP + nSQ + nRQ;
end;

Procedure TDSmodels.OverWriteDefaultSettings( const cMaxStp: Integer;
          const cHtry, cHmin, cEps: Double );
begin
  {MaxStp := cMaxStp;
  Htry   := cHtry;
  Hmin   := cHmin;
  Eps    := cEps;}
end;

Procedure TDSmodels.Run( var cArea, tTS, vTS, tResult, vResult: Real;
                         var IErr: Integer );
var
  ResultBuf: TDoubleMatrix;
   {-Resultaat berekeningen Kolom 1: uitvoertijden; Kolommen 2..NResPar+1:
     berekeningsresultaten v.d. uitvoervariabelen 1..NResPar}

Function UpDateEP0: Boolean;
  {-Zet 'Area' op EP[0]-array}
begin
  if ( cArea > 0 ) then begin
    with EP[ cEP0 ].xInDep do
      Items[ 0 ].SetValue( cmpArea, 1, cArea );
    Result := true;
  end else
    Result := false;
end;

Function UpDateEP1: Boolean;
  {-Zet de gewenste uitvoertijdstippen in EP[1]}
  Function NrOfOutputTimesNEW: Integer;
  begin
    Result := Trunc( tResult );
  end;
var
  P1: PDouble;
  i, n: Integer;
begin
  Result := true;
  {-Gooi evt. bestaande uitvoertijdstippen weg}
  try EP[ cEP1 ].xInDep.Clear; except; Result := false; end;
  n := NrOfOutputTimesNEW;
  {$ifdef test}
    Application.MessageBox( PChar( IntToStr( n ) ), 'NrOfOutputTimesNEW',
    MB_OKCANCEL );
  {$endif}
  try
    EP[ cEP1 ].xInDep.Add( TDoubleMatrix.Create( 1, n, nil ) );
  except
    Result := false; exit;
  end;
  {$ifdef test}
    Application.MessageBox( PChar( 'TDoubleMatrix created' ), 'info',
    MB_OKCANCEL );
  {$endif}
  P1 := @tResult; {-Points at aant.uitv.tijden N now}
  for i:=1 to n do begin {-Alle uitvoertijdstippen}
    Inc( P1 );
    EP[ cEP1 ].xInDep.Items[ 0 ].SetValue( 1, i, P1^ );
  end;
  {$ifdef test}
  Application.MessageBox( PChar( 'TDoubleMatrix filled' ), 'info',
  MB_OKCANCEL );
  {$endif}
end;

Function UpDateEP2: Boolean;
  {-Zet de gegevens uit de RP-, SQ- en RQ-tijdreeksen in EP[2]}
var
  i, j, k, n, nTSfromShell: Integer;
  P1, P2: PDouble;
  DefValue: Double;
{$ifdef test3}
  g: TextFile;
  x, y: Double;
{$endif}

begin
  Result := true;

  {-Try to drop existing values and create new values}
  try EP[ cEP2 ].xDep.Clear; except Result := false; end;
  SetReadyToRun( false );

  with EP[ cEP2 ] do begin
    P1 := @tTS; P2 := @vTS;
    nTSfromShell := nTS;
    for i:=1 to nTSfromShell do begin
      n := Max( Trunc( P1^ ) + 1, 1 ); DefValue := P2^;
      try
        xDep.Add( TxyTable.Create( n, nil ) ); {result=i-1 }
      except
        Result := false; exit;
      end;
      j := i-1;
      {-Set default value. Assume first x-value (time) is 0!}
      xDep.Items[ j ].Setxy( 1, 0, DefValue );
      for k:=2 to n do begin
        Inc( P1 ); Inc( P2 );
        xDep.Items[ j ].Setxy( k, P1^, P2^ );
      end;
      Inc( P1 ); Inc( P2 );
    end; {-for i:=1 to nTS}

    {$ifdef test3}
    AssignFile( g, 'EP.log' ); Rewrite( g );
    Writeln( g, 'nRP= ', nRP );
    Writeln( g, 'nSQ= ', nSQ );
    Writeln( g, 'nRQ= ', nRQ );
    Writeln( g, 'xDep.Count= ', xDep.Count );
    Writeln( g, 'xDep.LastIndex= ', xDep.LastIndex );
    for i:=1 to nTSfromShell do begin
      Writeln( g, 'Table ', i );
      j := i-1;
      with xDep.Items[ j ] do begin
        n := NrOfElements;
        Writeln( g, 'NrOfElements: ', n );
        {for k:=1 to n do begin
          Getxy( k, x, y );
          Writeln( g, i:5, ' ', x:8:2, ' ', y:8:2 );
        end;}
      end;
    end;
    CloseFile( g );
    {$endif}

  end; {-with EP[ cEP2 ]}
  SetReadyToRun( true );
end;

Procedure WriteResultBuf;
var
  i, j: Integer;
  P1: PDouble;
  {$ifdef test4}
  f: Textfile;
  {$endif}
begin
  P1 := @vResult; {-Points at Error code now}
  for j:=1 to NResPar do
    for i:=1 to NrOfOutputTimes do begin
      Inc( P1 ); P1^ := ResultBuf.GetValue( i, j+1 );
    end;
  {$ifdef test4}
  Inc( OutputCount );
  AssignFile( f, 'TestDSmodelS' + IntToStr( OutputCount ) + '.out' ); Rewrite( f );
  Writeln( f, 'NResPar= ', NResPar, '; NrOfOutputTimes= ', NrOfOutputTimes );
  ResultBuf.WriteToTextFile( f );
  Closefile( f );
  {$endif}
end;

Procedure ResetResults;
var
  i, j: Integer;
  P1: PDouble;
begin
  P1 := @vResult; {-Points at Error code now}
  for j:=1 to NResPar do
    for i:=1 to NrOfOutputTimes do begin
      Inc( P1 ); P1^ := cResultUndefined;
    end;
end;

begin
  IErr := cUnknownError;

  if ( not ModelIsLoaded ) then begin  {-Als geen model geladen, dan niet reageren op 'run' verzoek}
    IErr := cModelNotReady; Exit;
  end;

  ResetResults;

  {-Zet 'Area' in EP[0]-array}
  if not UpDateEP0 then begin
    IErr := cErrorUpdatingEP0; exit;
  end;

  {-Zet de gewenste uitvoertijdstippen in EP[1]}
  if not UpDateEP1 then begin
    IErr := cErrorUpdatingEP1; exit;
  end;

  {-Zet RP-, SQ- en RQ-tijdreeksen in EP[cEP2]}
  if not UpDateEP2 then begin
    IErr := cErrorUpdatingEP2; exit;
  end;

  if ( not ReadyToRun ) then begin
    IErr := cModelIsNotReadyToRun; exit;
  end;

  Try ResultBuf.free; except end; {-Drop ResultBuf}
  {-Initiate ResultBuf with cResultUndefined}
  Try
    ResultBuf := TDoubleMatrix.CreateF( NrOfOutputTimes, NResPar+1,
                 cResultUndefined, nil );
  except
    IErr := cErrorCreatingResultBuf; exit;
  end;

  {ShowMessage( 'Run' );}
  Inherited Run( ResultBuf, IErr ); {ShowMessage( IErr.tostring );}
  WriteResultBuf;

  Try ResultBuf.free; except end; {-Drop ResultBuf}

  {IErr := cNoError;}
end;

Function DefaultBootEPForShell( const
  cnRP,                  {-Nr. of RP-time series expected from shell}
  cnSQ,                  {-Nr. of point-time series expected from shell}
  cnRQ                   {-Nr. of line-time series expected from shell}
  : Integer;
  var Indx: Integer;     {-BootEPArrayVariantIndex}
  var EP:                {-EParray that is partially filled in this procedure}
  TExtParArray ): Integer;
  {-Rem.:
   - Set values in OutputProcMatrix (=EP[0].xIndep.Items[1]) before calling
     this procedure!
   - ReadyToRun flag is NOT set by this procedure}
Function nResPar: Integer; {-Deze functie moet hetzelfde zijn als TDSmodel.NResPar!}
var
  nr, nc, i, j: Integer;
begin
  Result := 0;
  with EP[ cEP0 ].xInDep.Items[ 1 ] do begin
    nc := GetNCols;
    nr := GetNRows;
    for j:=2 to nc do {-Opm.: kolom 1 bevat start-waarden}
      for i:=1 to nr do
        if ( GetValue( i, j ) <> 0 ) then
          Inc( Result );
  end;
end;
begin
  EP[ cEP2 ] := TExtPar.Create;

  {-Set reserved values in xInDep.Items[ 0 ]}
  with EP[ cEP0 ].xInDep do begin
    Items[ 0 ].SetValue( cmpnRP, 1, cnRP );
    Items[ 0 ].SetValue( cmpnSQ, 1, cnSQ );
    Items[ 0 ].SetValue( cmpnRQ, 1, cnRQ );
    {-Kijk of het aantal uitvoerparameters wel >= 1 is (nResPar >= 1)}
    if ( NResPar >= 1 ) then begin
      Indx   := cBoot2;
      Result := cNoError;
    end else begin
      Indx   := cBootEPArrayVariantIndexUnknown;
      Result := cWrongNTSout;
    end;
  end; {-with}
end;

Procedure ScaleTimesFromShell( const TimeMultFact: Double; var EP: TExtParArray );
var
  cTable, i, NrOfOutputTimes: Integer;
  OutputTime: Double;
begin
  {-Schaal alle tijdreeksen afkomstig van de Shell (EP[ cEP2 ].xDep) }
  with EP[ cEP2 ].xDep do
    for cTable:=0 to Count-1 do
      with Items[ cTable ] do
        for i:=1 to NrOfElements do
          Setx( i, TimeMultFact * Getx( i ) );

  {-Schaal de uitvoertijdstippen overeenkomstig}
  with EP[ cEP1 ].xInDep.Items[ 0 ] do begin
    NrOfOutputTimes := GetNCols;
    for i:=1 to NrOfOutputTimes do begin
      OutputTime := Getvalue( 1, i );
      OutputTime := TimeMultFact * OutputTime;
      SetValue( 1, i, OutputTime );
    end;
  end;
end;

Function Area( var EP: TExtParArray ): Double;
begin
  with EP[ cEP0 ].xInDep do
    Result := Items[ 0 ].GetValue( cmpArea, 1 );
end;

begin
//  ModelIsLoaded := false;
  {$ifdef test4}
  OutputCount := 0;
  {$endif}
end.

