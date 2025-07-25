unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, FireDAC.Stan.Intf,
  FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.PG, FireDAC.Phys.PGDef,
  FireDAC.VCLUI.Wait, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf,
  FireDAC.DApt, FireDAC.Comp.Client, Data.DB, FireDAC.Comp.DataSet,
  Vcl.Buttons, Vcl.DBCtrls, Vcl.Grids, Vcl.DBGrids, Vcl.StdCtrls,
  Vcl.ExtCtrls, System.Skia, System.ImageList, Vcl.ImgList,
  Vcl.Imaging.pngimage;

{.$DEFINE IANB}

type
  TForm1 = class(TForm)
    FDConnection1: TFDConnection;
    FDPhysPgDriverLink1: TFDPhysPgDriverLink;
    TopPanel: TPanel;
    ConnectButton: TButton;
    FillTestDataButton: TButton;
    DarkModeCheck: TCheckBox;
    CenterPanel: TPanel;
    DetailPanel: TPanel;
    TopDetailPanel: TPanel;
    Label1: TLabel;
    PersonLabel: TLabel;
    Label2: TLabel;
    MinutiaeLabel: TLabel;
    BottomDetailPanel: TPanel;
    DBGrid1: TDBGrid;
    DBNavigator1: TDBNavigator;
    ImageList1: TImageList;
    Image1: TImage;
    ListTable: TFDTable;
    ListSource: TDataSource;
    ListTablethe_person: TWideStringField;
    ListTablethe_minutiae: TDataSetField;
    FDUpdateQuery: TFDQuery;
    FDMemTable1: TFDMemTable;
    FDMemTable1the_minutiae: TIntegerField;
    procedure FormCreate(Sender: TObject);
    procedure ConnectButtonClick(Sender: TObject);
    procedure DarkModeCheckClick(Sender: TObject);
    procedure FillTestDataButtonClick(Sender: TObject);
    procedure ListTableAfterScroll(DataSet: TDataSet);
  private
    procedure GetNewFingerPrint;
    procedure ActivateDatabase;
    procedure ChangeTablesActiveStatus(const ASetToActive: boolean);
    procedure HandleTheme;
    procedure ListMinutiae;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses WindowsDarkMode;


const
  cDarkTheme  = 'Windows11 Impressive Dark';
  cLightTheme = 'Windows11 Impressive Light';

{$IFDEF IANB}

{$i 'connection.inc'}

{$ELSE}

// Change these const values to suit your server, database, user name and password settings
// then edit the following lines to begin with {.$MESSAGE to make the warnings go away
{$MESSAGE Warn '#####################################################################'}
{$MESSAGE Warn '#####################################################################'}
{$MESSAGE Warn 'Did you remember to change the const lines to your own settings? :)'}
{$MESSAGE Warn '#####################################################################'}
{$MESSAGE Warn '#####################################################################'}

const
  cServer    = 'your_server_name_goes_here';
  cDatabase  = 'this_should_be_your_databasename';
  cUser_Name = 'this_should_be_your_username';
  cPassword  = 'this_should_be_the_password';

{$ENDIF}

procedure TForm1.FormCreate(Sender: TObject);
begin
  DarkModeCheck.Checked := DarkModeIsEnabled;

  ///////////////////////////////////////////////////////////////////////////////////
  //                                                                              ///
  // You should never do this in a production app - it would be VERY easy for     ///
  // someone to examine the strings in your app and get the database credentials! ///
  // We are doing this here for the sake of an easy/configurable demo             ///
  //                                                                              ///
  // You should either store it encrypted (and then decrypt it) or use techniques ///
  // like private encrypted environment variables or indeed anything other than   ///
  // plain text!                                                                  ///
  //                                                                              ///
  FDConnection1.Params.Clear;                                                     ///
  FDConnection1.Params.Add('DriverName=PG');                                      ///
  FDConnection1.Params.Add('DriverID=PG');                                        ///
  FDConnection1.Params.Add('Database='  + cDatabase);                             ///
  FDConnection1.Params.Add('Server='    + cServer);                               ///
  FDConnection1.Params.Add('User_Name=' + cUser_Name);                            ///
  FDConnection1.Params.Add('Password='  + cPassword);                             ///
  //                                                                              ///
  ///////////////////////////////////////////////////////////////////////////////////
end;

procedure TForm1.ActivateDatabase;
begin
  if FDConnection1.Connected then
    begin
      FDConnection1.Connected := False;
      ConnectButton.Caption   := 'Connect';
      Caption                 := 'Disconnected';
      ChangeTablesActiveStatus(False);
    end
  else
    begin
      try
        FDConnection1.Connected := True;
        ChangeTablesActiveStatus(True);
        ConnectButton.Caption   := 'Disconnect';
        Caption := 'Connected';
      except On E: Exception do
        ShowMessage('Unable to connect - "' + E.Message + '"');
      end;
    end;
  CenterPanel.Visible := FDConnection1.Connected;
  // We want to make it so the user can immediately use the arrow keys to
  // move from one record to the next in the dbgrid when the database is connected.
  // We don't need to check if the database is connected since the
  // DBGrid is not visible when the DB is disconnected. The CanFocus method
  // will check it's visible and can be focused.
  if DBGrid1.CanFocus then DBGrid1.SetFocus;
end;

procedure TForm1.ChangeTablesActiveStatus(const ASetToActive: boolean);
begin
  ListTable.Active   := ASetToActive;
  FDMemTable1.Active := ASetToActive;
end;

procedure TForm1.ConnectButtonClick(Sender: TObject);
begin
  ActivateDatabase;
end;

procedure TForm1.DarkModeCheckClick(Sender: TObject);
begin
  HandleTheme;
end;

procedure TForm1.FillTestDataButtonClick(Sender: TObject);
begin
  // This creates 128 fake 'people' records with random fake fingerprint 'minutiae'
  // values. The fingerprint images and the minutiae are all completely fake and
  // are generated randomly. The fingerprint images were created by AI and
  // are totally imaginary
  if not FDConnection1.Connected then ActivateDatabase;
  if FDConnection1.Connected then
  begin
    var sCaption: string := FillTestDataButton.Caption;
    CenterPanel.Visible := False;
    try
      ChangeTablesActiveStatus(False);
      FDUpdateQuery.Sql.Text := 'TRUNCATE TABLE TABLE_WITH_ARRAY'; // Fastest way to empty the table
      FDUpdateQuery.ExecSQL;
      FDUpdateQuery.SQL.text := 'insert into TABLE_WITH_ARRAY values (:person, :mins)';
      FDUpdateQuery.Params[1].ArrayType := atTable;
      FDUpdateQuery.Params[1].ArraySize := 24; // TFDParam.ArraySize must be set to array size
      for var PersonNumber := 1 to 128 do
      begin
        FillTestDataButton.Caption := PersonNumber.ToString;
        Application.ProcessMessages;
        FDUpdateQuery.Params[0].AsString := 'Fake person ' + Format('%.3d', [PersonNumber]);
        for var Minutiae := 0 to 23 do
          FDUpdateQuery.Params[1].Values[Minutiae] := Random(150);
        FDUpdateQuery.ExecSQL;
      end;
    finally
      ChangeTablesActiveStatus(True);
    end;
    FillTestDataButton.Caption := sCaption;
    CenterPanel.Visible        := True;
  end;
end;

procedure TForm1.GetNewFingerPrint;
begin
  Image1.Picture := Nil;
  ImageList1.GetBitmap(Random(6), Image1.Picture.Bitmap);
end;

procedure TForm1.HandleTheme;
begin
  SetSpecificThemeMode(DarkModeCheck.Checked, cDarkTheme, cLightTheme);
end;

procedure TForm1.ListMinutiae;

const
  cTheLeft   = 15;
  cTheTop    = 15;
  cTheRight  = 146;
  cTheBottom = 240;
  cBoxColor  = 7901512;

  var
    LX, LY:           integer;
    LRect:            TRect;
    LBoundRect:       TRect;
    LNumberOfMatches: integer;

  procedure PrepareCanvas;
  begin
    // Make sure our pen, for the 'dots' is red, and the rectangles
    // will be filled with red too
    Image1.Picture.Bitmap.Canvas.Pen.Color   := clRed;
    Image1.Picture.Bitmap.Canvas.Pen.Width   := 3;
    Image1.Picture.Bitmap.Canvas.Pen.Style   := psSolid;
    Image1.Picture.Bitmap.Canvas.Brush.Color := clRed;
    Image1.Picture.Bitmap.Canvas.Brush.Style := bsSolid;
  end;

  procedure DrawDots;
  begin
    // Create some partially random 'minutiae dots' on the bitmap image.
    if LY < cTheLeft  then LX := cTheLeft + LY else LX := LY;
    if LX > cTheRight then LX := cTheRight - FDMemTable1the_minutiae.AsInteger;
    LY := FDMemTable1the_minutiae.AsInteger + 50;
    if LY < cTheTop    then LY := cTheTop + FDMemTable1the_minutiae.AsInteger;
    if LY > cTheBottom then LY := cTheBottom - FDMemTable1the_minutiae.AsInteger;
    LRect := Rect(LX, LY, LX + 5, LY + 5);
    // To make sure that the pseudorandom X,Y coordinates stay within
    // the green imaginary bounding area we use the IntersectRect function
    // and only draw 'dots' rectangles which fall within it
    // This fakes the minutiae actually matching the fake AI fingerprint
    // which, of course, it doesn't - but it makes a cool demo :)
    if IntersectRect(LRect, LRect, LBoundRect) then
    begin
      Image1.Picture.Bitmap.Canvas.FillRect(LRect);
      Inc(LNumberOfMatches);
    end;
  end;

  procedure DrawColoredBox;
  begin
    // Draw a rectangle to highlight the bounding area of the fingerprint
    Image1.Picture.Bitmap.Canvas.Brush.Style := bsClear;
    Image1.Picture.Bitmap.Canvas.Pen.Color   := cBoxColor;
    LRect := TRect.Create(cTheLeft, cTheTop, cTheRight, cTheBottom);
    Image1.Picture.Bitmap.Canvas.Rectangle(LRect);
  end;

begin

  // Note that the detail panel on which the image control is located has the DoubleBuffered property set to true
  // This is to prevent flashing while drawing.
  var LString: string := '';
  var LComma:  string := '';
  LNumberOfMatches    := 0;

  if FDMemTable1.RecordCount > 0 then
  begin
    PrepareCanvas;
    LBoundRect := Rect(cTheLeft, cTheTop, cTheRight, cTheBottom);
    FDMemTable1.First;
    LY  := Image1.Picture.Bitmap.Width div 2;
    Image1.Picture.Bitmap.Canvas.MoveTo(Image1.Picture.Bitmap.Width div 2, LY);
    // The FDMemTable will contain one record for each array member in the
    // DB array field. So we just iterate through the DB.
    // We draw some fake 'minutiae dots' to make the fingerprint look cool :)
    while not FDMemTable1.Eof do
    begin
      LString := LString + LComma + FDMemTable1the_minutiae.AsString;
      LComma := ',';
      DrawDots;
      FDMemTable1.Next;
    end;
    DrawColoredBox;
  end;
  MinutiaeLabel.Caption := LString;
  PersonLabel.Caption := PersonLabel.Caption + ' has ' + LNumberOfMatches.ToString + ' matching point';
  // I am pedantic about "1 matching point", "0 matching points", "3 matching points" :)
  if LNumberOfMatches <> 1 then PersonLabel.Caption := PersonLabel.Caption + 's';
end;

procedure TForm1.ListTableAfterScroll(DataSet: TDataSet);
begin
  // After the database cursor moves to a different record
  // we update our screen controls with the record's details
  // and draw a fake fingerprint with simulated minutiae on
  // it
  PersonLabel.Caption := ListTablethe_person.AsString;
  GetNewFingerPrint;
  ListMinutiae;
end;

end.
