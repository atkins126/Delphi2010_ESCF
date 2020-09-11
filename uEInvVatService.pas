unit uEInvVatService;

interface

uses
  Classes, SysUtils, ComObj, Generics.Collections,
  Variants, Dialogs, UITypes, uVars;

const
  // �������� ��������, ������ ��������� �������������� ����������� � ��
  TInvoiceStatus: array[0..8] of string = (
        // 0 - ��� ������� (������ ������� �� ������� ���, �������� ��� �������)
        'NULL',
        // 1 - � ����������
        'IN_PROGRESS', 
        // 2 - � ����������. ������
        'IN_PROGRESS_ERROR' ,
        // 3 - ���������
        'COMPLETED', 
        // 4 - ���������. �������� �����������
        'COMPLETED_SIGNED',
        // 5 - ���������. ����������� �����������
        'ON_AGREEMENT_CANCEL', 
        // 6 - �� ������������
        'ON_AGREEMENT',
        // 7 - �����������
        'CANCELLED',
        // 8 - ������ �������
        'PORTAL_ERROR' );
  TCaprionStatus: array[0..8] of string = (
        '<���>',
        '� ����������',
        '� ����������. ������',
        '���������',
        '���������. �������� �����������',
        '���������. ����������� �����������',
        '�� ������������',
        '�����������',
        '������ �������' );
        

type
  //����� � ������������ �������� ����
  TSendInfo = class
  public
   VatInvoice: string;  //����� ����
   IsException: Boolean;//������� ������ (��/���)
   ResMessage: string;  //��������� � �����������
   Status: integer;     //������ ���� � ������� (�� ��������� 0)
   constructor Create(vatInv: string; isExc: Boolean; resMsg:string; stat: Integer = 0);
  end;

  //����� �������������� � ��������
  TEInvVatService = class(TThread)
  private
    //���������� ��� ���������� ������� � ������� ����
    EVatService: Variant;      //��� ��������� ActiveX
    EVatAU: Integer;           //������� ����������� (0 - ���, 1 - ��)
    files_path: string;        //���� � ��������� ������ xml (��������������� ��� �������� �������)         
    procedure Disconnect;      //���������� �� �������
    procedure Login;           //����������� ������������
    function Connect: Boolean; //����������� � �������
    function ExceptionMessage(msg: string): string; //string + ���������������� ��������� �� �������
    function GetStatusInt(s: string): Integer;  //�������������� ������� string � integer
    procedure AddLog(msg:string);
  public
    Progress: integer;
    FOperation: TVatOperation;
    FStatus: TSyncFilesStatus;
    invoices: TList<string>;
    sendinfo: TList<TSendInfo>;
    //�������� ������� ��� ������ ������
    constructor Create(file_path: string);

    //����������� ������� ��� ���������� ������
    destructor Destroy; override;

    //�������� ����� �� ������
    //�������������� ������ invoices c �������� ���� (������������� ����� ��� ��� ���� .xml)
    //����������� �������� �� ������.
    //�����!!! � �������� �������� �� ���� file_path ������ ���� ������� xsd � ���������
    procedure SignAndSendOut;

    //�������� ������� ���� �� �������
    //�������������� ������ invoices c �������� ����
    procedure CheckStatus;
    function Stop: boolean;
   protected
    procedure SyncThr;
    procedure Execute; override;
    procedure DoTerminate; override;
  end;

const
  //����� ������� ��� ��������������
  portalUrl  = 'https://195.50.4.43/InvoicesWS/services/InvoicesPort' ;       //��������
//portalUrl = 'https://ws.vat.gov.by:443/InvoicesWS/services/InvoicesPort?wsdl';

var  
  resMsg: string;
                     
implementation

uses uEInvVatServiceLoad, uMain;    


constructor TSendInfo.Create(vatInv: string; isExc: Boolean; resMsg: string; stat: integer = 0);
begin
  VatInvoice := vatInv;
  IsException := isExc;
  ResMessage := resMsg;
  Status := stat;
end;


//������������� ������� ��������� ������ �������������� � ����������� ������������ ���������� ActiveX
constructor TEInvVatService.Create(file_path: string);
var
  connector: string;
begin
  inherited Create(True);
  files_path := file_path;
  FStatus := thStopped;
  Progress := 0;
  EVatAU := 0;
  invoices:= TList<string>.Create;
  sendinfo:= TList<TSendInfo>.Create;   
  try
    connector := 'EInvVatService.Connector';
    try
      EVatService := GetActiveOleObject(connector);
    except
      EVatService := CreateOleObject(connector);
    end;
    AddLog('���������� ������� � ������� ���� ���������');
  except
    AddLog('�� ���������� �� ���������� ����������, ����������� ��� ������� � ������� ����!');
    FStatus := thLocked;
  //  Destroy;
  end;
end;

//����������� ������� ��� ���������� ������
destructor TEInvVatService.Destroy;
begin     
  Disconnect;
  FreeAndNil(invoices);
  FreeAndNil(sendinfo);
  inherited;
end;

//����������� ������������
procedure TEInvVatService.Login;
var
  s: string;
begin   
  if EVatService.Login[s, 0] = 0 then
  begin
    EVatAU := 1;
    AddLog('����������� �������');  
  end
  else
  begin
    EVatAU := 0;
    AddLog(ExceptionMessage('������ �����������'));  
    Abort;
  end;     
end;


//����������� � �������, �� ������ ��������� �����������
function TEInvVatService.Connect: Boolean;
begin
  Result:=False;
  if EVatAU = 0 then
    Login;
  if EVatService.Connect[portalUrl] = 0 then
    Result:=True
  else
    AddLog(ExceptionMessage('������ �����������'));
end;

//���������� �� �������
procedure TEInvVatService.Disconnect;
begin
  if EVatAU = 1 then
  begin
    if EVatService.Disconnect <> 0 then
      AddLog('������ ��� ���������� ����������� � ������ �����������');
    if EVatService.Logout <> 0 then
      AddLog('������ ��� ���������� �������������� ������');
  end;
end;


procedure TEInvVatService.DoTerminate;
begin
  resMsg := '���������!';
  Synchronize(SyncThr);     
end;

//string + ���������������� ��������� �� �������
function TEInvVatService.ExceptionMessage(msg: string): string;
begin
    Result := msg + ': ' + EVatService.LastError;
end;

function TEInvVatService.Stop: boolean;
begin
  result:=true;
  if FStatus = thStopped then exit
  else if FStatus = thRun then
  begin
     FStatus := thPause;    
     if TaskMessageDlg('������������� ������', '�������� ������� �������������� � ��������?' , mtConfirmation,[mbYes,mbNO], 0) = mrYes  then   
      FStatus := thStopped    
     else 
     begin
      FStatus := thRun;    
      result := false; 
     end;
  end;     
end;

procedure TEInvVatService.Execute;     
begin
  try
   // try
    if FStatus <> thLocked then
    begin
      FStatus := thRun;
      if FOperation = foSignAndSend then
        SignAndSendOut
      else if FOperation = foCheckStatus then
        CheckStatus
      else
        AddLog('��� �������� �� �����');
    end;
        //except
    // on E: Exception do
    //    AddLog(e.ClassName + ' ������, � ���������� : ' + e.Message);
    // end;
  finally
    FStatus := thStopped;
    Terminate;
  end;
end;              

//������� �� �������� ���� �� ������
// �� ����� TList<string> - ������ � �������� ���� � ������� ���-���-����� (��������, 192050981-2020-0000000001)
// ����� xml ������ ����� ����������� ������������
procedure TEInvVatService.SignAndSendOut;
var
  i: TSendInfo;
  filename, f, xsd, fn, TicketIssuerUri,
  InvVatType: string;
  InvVatXml, InvVatTicket, status: Variant;
begin
  //  ����������� � ������� ����
  sendinfo.Clear;
  if not Connect then
     Abort;
  for f in invoices do
  begin
    //������ �����
    filename := files_path + 'invoice-' + f + '.xml';
    InvVatXml := EVatService.CreateEDoc;
    if InvVatXml.Document.LoadFromFile[filename] <> 0 then
      i := TSendInfo.Create(f, True, ExceptionMessage('������ ������ �����'))
    else
    begin
      //�������� XML ����� �� ������������  xsd-�����
      InvVatType := InvVatXml.Document.GetXmlNodeValue['issuance/general/documentType'];
      if InvVatType = 'ORIGINAL' then
        xsd := 'MNSATI_original.xsd'
      else if InvVatType = 'FIXED' then
        xsd := 'MNSATI_fixed.xsd'
      else if InvVatType = 'ADDITIONAL' then
        xsd := 'MNSATI_additional.xsd'
      else if InvVatType = 'ADD_NO_REFERENCE' then
        xsd := 'MNSATI_add_no_reference.xsd'
      else xsd:='';

      if xsd='' then
        i := TSendInfo.Create(f, True, ExceptionMessage('���� .xml �������� �������� ��� ���������'))
      else if InvVatXml.Document.ValidateXML[files_path + 'xsd\' + xsd, 0] <> 0 then
        i := TSendInfo.Create(f, True, ExceptionMessage('�������� �� ������������� ��������� ����� xsd'))
      else if InvVatXml.Sign[0] <> 0 then
        i := TSendInfo.Create(f, True, ExceptionMessage('������ ��������� �������'))
      else
      begin
        //���������� ������������ ����� � ����������� '.edoc.xml'
        //fn := filename + '.edoc.xml';
        //if InvVatXml.SaveToFile[fn] <> 0 then
        //   DialogStop(ExceptionMessage('������ ���������� ������������ ���������'));

        //�������� ������������ ��������� �� ������ ����
        if EVatService.SendEDoc[InvVatXml] <> 0 then
          i := TSendInfo.Create(f, True, ExceptionMessage('������ ��������'))
        else
        begin
          //����� �� ������� ���� ����� �������� � ���� � ����������� '.ticket.error.xml' � ������
          // ������  � �   '.ticket.xml'  � ������ ��������� �������� ����� ��������
          InvVatTicket := EVatService.Ticket;
          if InvVatTicket.Accepted <> 0 then
          begin
            i := TSendInfo.Create(f, True, '�������� �� ������: ' + InvVatTicket.Message);
            fn := files_path + f + '.ticket.error.xml';
          end
          else
          begin
            //���� �������� ������ ��������, �� �� �� ����� �������� �������� ��� ������, ��� ��� ������ ����� ������� ��������
            //�� �� ����������� ��������-����������� �������� �� �������� ���
            status := EVatService.GetStatus[f];
            if VarIsNull(status) then
              i := TSendInfo.Create(f, True, '���� �� ������ �������� �� ������� ������ �� ������')
            else
            begin
              if (status.Verify <> 0) then
                i := TSendInfo.Create(f, True, ExceptionMessage('������ ��������� �������'))
              else
              begin
                if (status.Status = 'NOT_FOUND') then
                  i := TSendInfo.Create(f, True, '���� �� ������ �������� �� ������� ('+ status.Message + ')')
                else
                begin
                  if (status.Status = 'ERROR') then
                    i := TSendInfo.Create(f, True, status.Message)
                  else
                    i := TSendInfo.Create(f, false, InvVatTicket.Message, GetStatusInt(status.Status));
                end;
              end;
            end;      
           // fn := filename + '.ticket.xml';
          end;
         { // ���������� ���������
          if InvVatTicket.SaveToFile[fn] <> 0 then
            ShowMessage(ExceptionMessage('������ ���������� ���������'))
          else
            resMsg := resMsg + #10#13 + ('���� ��������� ' + fn + ' ��������');    }
        end;
      end;
    end;
    if not i.IsException then
    begin
     TicketIssuerUri := InvVatTicket.Document.GetXmlNodeAttribute['ticket/issuer/URI'];
     resMsg := '�������� ������� ������ �������� ' + TicketIssuerUri;
    end
    else
     resMsg := '������: '+i.ResMessage;
    resMsg := i.VatInvoice + ' - ' + resMsg;
    inc(Progress);
    Synchronize(SyncThr);
    sendinfo.Add(i);
    while FStatus = thPause do
    begin
      //����������� ���� �� ����� �����
      Sleep(500);
    end;
  end;
end;

procedure TEInvVatService.SyncThr;
begin 
  fmEInvVatServiceLoad.mResult.Lines.Add(resMsg);
  fmEInvVatServiceLoad.cxProgressBar1.Position := Progress;
  if Terminated then
    fmEInvVatServiceLoad.edStatus.Text :='���������';
end;

procedure TEInvVatService.AddLog(msg:string);
begin
  resMsg:=msg;
  Synchronize(SyncThr);
end;

procedure TEInvVatService.CheckStatus;
var
  f: string;
  status: Variant;
  i: TSendInfo;
begin
  sendinfo.Clear;
  //  ����������� � ������� ����
  if not Connect then
     Abort;
  for f in invoices do
  begin
    status := EVatService.GetStatus[f];
    if not VarIsNull(status) then
    begin
      if (status.Verify <> 0) then
        i:= TSendInfo.Create(f, True, '������ ����������� �������')
      else
        i:=TSendInfo.Create(f, False, status.Message, GetStatusInt(status.status));
    end
    else
        i:=TSendInfo.Create(f, True, 'C����� �� ������� �� �������');
    Inc(Progress);
    if i.IsException or (i.Status = 0) then
      resMsg := i.VatInvoice + ' - ������: ' +  i.ResMessage
    else
      resMsg := i.VatInvoice + ' - ������: ' + TCaprionStatus[i.Status];
    Synchronize(SyncThr);
    sendinfo.Add(i);
  end;
end;


function TEInvVatService.GetStatusInt(s: string): Integer;
var
  i: integer;
begin
  result := 0;
  for i := 1 to 8 do
    if TInvoiceStatus[i] = s then
    begin
      Result := i;
      Break;
    end;
end;

{  �� ������������ ��������� �� C#
public IEnumerable<LoadInfo> LoadIncomeVatInvoice(DateTime date)
begin
            var info = new List<LoadInfo>();

            var removeXmlDeclarationRegex = new Regex(@"<\?xml.*\?>");

            Connect();
            var list = connector.GetList[date.ToString("s")];
            if (list != null)
            begin
                var listCount = list.Count;

                for (var i = 0; i < listCount; i++)
                begin
                    var number = list.GetItemAttribute[i, @"document/number"];
                    var eDoc = connector.GetEDoc[number];
                    if (eDoc != null)
                    begin
                        var verifySign = eDoc.VerifySign[0, 0];
                        if (verifySign == 0)
                        begin
                            var signXml = Encoding.UTF8.GetString(Convert.FromBase64String(eDoc.GetData[1]));
                            var xml = Encoding.UTF8.GetString(Convert.FromBase64String(eDoc.Document.GetData[1]));

                            xml = removeXmlDeclarationRegex.Replace(xml, "");

                            var invoice = serializer.Deserialize(xml);

                            info.Add(new LoadInfo(invoice, number, xml, signXml));
                        end;
                    end;
                end;
            end;
            else
            begin
                ThrowException("������ ��������� ������ ���� ");
            end;
            Disconnect();

            return info;
        end;
end;        }
{
public IEnumerable<SendInInfo> SignAndSendIn(params VatInvoiceXml[] invoices)
        begin
            var info = new List<SendInInfo>();
            Connect();
                invoices.ToList().ForEach(x =>
                begin
                    SendInInfo i;
                    var eDoc = connector.CreateEDoc;
                    if (eDoc.SetData[Convert.ToBase64String(Encoding.UTF8.GetBytes(x.SignXml)), 1] != 0)
                        i = new SendInInfo(x, true, ExceptionMessage("������ �������� ���������� "));
                    else
                    begin

                        var signCount = eDoc.GetSignCount;
                        if (signCount == 0)
                            i = new SendInInfo(x, true, ExceptionMessage("�������� �� �������� ��� "));
                        else begin
                           // if (eDoc.VerifySign[1, 0] != 0)
                           //     i = new SendInInfo(x, true, ExceptionMessage("������ �������� ������� "));
                           // else
                            begin
                                if (eDoc.Sign[0] != 0)
                                    i = new SendInInfo(x, true, ExceptionMessage("������ �������"));
                                else
                                begin
                                    if (connector.SendEDoc[eDoc] != 0)
                                        i = new SendInInfo(x, true, ExceptionMessage("������ ��������"));
                                    else
                                    begin
                                        var ticket = connector.Ticket;

                                        if (ticket.Accepted != 0)
                                        begin
                                            i = new SendInInfo(x, true, ticket.Message);
                                        end;
                                        else
                                        begin
                                            x.Sign2Xml =
                                                Encoding.UTF8.GetString(Convert.FromBase64String(eDoc.GetData[1]));

                                            i = new SendInInfo(
                                                x,
                                                false,
                                                ticket.Message
                                                );
                                        end;
                                    end;
                                end;
                            end;
                        end;
                    end;

                    info.Add(i);

                end;);
            Disconnect();
            return info;
        end;                 }

end.

