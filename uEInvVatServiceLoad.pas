unit uEInvVatServiceLoad;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxContainer,
  cxEdit, dxLayoutcxEditAdapters, System.Actions, Vcl.ActnList, Vcl.Buttons, cxMemo, dxLayoutContainer, cxProgressBar,
  cxTextEdit, cxClasses, dxLayoutControl, Vcl.ExtCtrls, uResource, uEInvVatService, Generics.Collections, uVars;

type
  TfmEInvVatServiceLoad = class(TForm)
    Panel1: TPanel;
    Panel2: TPanel;
    dxLayoutControl1Group_Root: TdxLayoutGroup;
    dxLayoutControl1: TdxLayoutControl;
    edOperation: TcxTextEdit;
    dxLayoutItem1: TdxLayoutItem;
    edStatus: TcxTextEdit;
    dxLayoutItem2: TdxLayoutItem;
    cxProgressBar1: TcxProgressBar;
    dxLayoutItem3: TdxLayoutItem;
    dxLayoutAutoCreatedGroup1: TdxLayoutAutoCreatedGroup;
    mResult: TcxMemo;
    btnRun: TSpeedButton;
    ActionList1: TActionList;
    actRun: TAction;
    actStop: TAction;
    actExit: TAction;
    SpeedButton1: TSpeedButton;
    procedure actRunExecute(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure actStopUpdate(Sender: TObject);
    procedure actStopExecute(Sender: TObject);
    procedure actExitExecute(Sender: TObject);
  private
    { Private declarations }
    vat: TEInvVatService;
  public
    { Public declarations }

  end;

var
  fmEInvVatServiceLoad: TfmEInvVatServiceLoad;
{-----------------------------------------------------------------------------------}
{        ��� �������������: ��������� �������������� � ������� �� �����             }
{        � using ���������� �������� ������� ���� uEInvVatServiceLoad               }
  // 1) ������������� �����  pMode: 0 - �������� ����, 1 - �������� �������, file_path - ���� � ������, AOwner - ���� �� ������������
function VatServiceInit(pMode: Integer; file_path: string = ''; AOwner: TComponent = nil): boolean;
 // 2) ���������� ������ ���� � ������ ��� ���������
procedure VatServiceAddFile(name: string);
 // 3) ������ ������
procedure VatServiceRun;
 // 4) ��������� ���������� (������ �������� TSendInfo)
function VatServiceGetResultInfo: TList<TSendInfo>;
 // 5) ���������� ������
procedure VatServiceDestroy;
{-----------------------------------------------------------------------------------}

implementation

{$R *.dfm}

//pMode : ����� ������ 0 - �������� ����, 1 - �������� ������� , file_path - ���� � ������, AOwner - ���� �� ������������
function VatServiceInit(pMode: Integer; file_path: string = ''; AOwner: TComponent = nil): boolean;
begin
  if file_path = '' then
    file_path := ExpandFileName(ExtractFileDir(Application.ExeName) + '\ForSign\');
  fmEInvVatServiceLoad := TfmEInvVatServiceLoad.Create(AOwner);
  fmEInvVatServiceLoad.vat := TEInvVatService.Create(file_path);
  if pMode = 0 then
  begin
    fmEInvVatServiceLoad.vat.FOperation := foSignAndSend;
    fmEInvVatServiceLoad.edOperation.Text := '�������� ���� �� ������';
  end
  else
  begin
    fmEInvVatServiceLoad.vat.FOperation := foCheckStatus;
    fmEInvVatServiceLoad.edOperation.Text := '�������� ������� ���� �� �������';
  end;
  fmEInvVatServiceLoad.cxProgressBar1.Properties.Max := 0;
end;

procedure VatServiceAddFile(name: string);
begin
 if Assigned(fmEInvVatServiceLoad.vat) then
 fmEInvVatServiceLoad.vat.invoices.Add(name);
 fmEInvVatServiceLoad.cxProgressBar1.Properties.Max:= fmEInvVatServiceLoad.cxProgressBar1.Properties.Max + 1;
end;

function VatServiceGetResultInfo: TList<TSendInfo>;
begin
  result := fmEInvVatServiceLoad.vat.sendinfo;
end;

procedure VatServiceRun;
begin
  if fmEInvVatServiceLoad.vat.FOperation = foSignAndSend then
    fmEInvVatServiceLoad.mResult.Lines.Add('���������� ���� � �������� �� ������ = ' + IntToStr(fmEInvVatServiceLoad.vat.invoices.Count))
  else
    fmEInvVatServiceLoad.mResult.Lines.Add('���������� ���� ��� �������� ������� = ' + IntToStr(fmEInvVatServiceLoad.vat.invoices.Count));
  fmEInvVatServiceLoad.ShowModal;
end;

procedure VatServiceDestroy;
begin
  if Assigned(fmEInvVatServiceLoad.vat) then
    FreeAndNil(fmEInvVatServiceLoad.vat);
  FreeAndNil(fmEInvVatServiceLoad);
end;

procedure TfmEInvVatServiceLoad.actExitExecute(Sender: TObject);
begin
   Close;
end;

procedure TfmEInvVatServiceLoad.actRunExecute(Sender: TObject);
begin
  vat.Start;
  edStatus.Text := '��������';
  btnRun.Action := actStop;
end;

procedure TfmEInvVatServiceLoad.actStopExecute(Sender: TObject);
begin
  fmEInvVatServiceLoad.edStatus.Text := '��������������';
  if vat.Stop then
   fmEInvVatServiceLoad.edStatus.Text := '�������� �������������'
  else
   fmEInvVatServiceLoad.edStatus.Text := '��������';
end;

procedure TfmEInvVatServiceLoad.actStopUpdate(Sender: TObject);
begin
  actStop.Enabled:= (btnRun.Action = actStop) and Assigned(vat) and (vat.FStatus = thRun);
end;

procedure TfmEInvVatServiceLoad.FormClose(Sender: TObject; var Action: TCloseAction);
begin
 if Assigned(vat) and (vat.FStatus = thRun) then
    raise Exception.Create(Self.Caption + #$0D#$0A + '������� �������. ��������� ����� ������')   ;
end;




end.
