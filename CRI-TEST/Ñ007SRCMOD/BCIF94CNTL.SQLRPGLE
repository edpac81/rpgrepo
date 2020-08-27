**free
ctl-opt nomain bnddir('CCGIBNDDIR':'CMQBNDDIR':'CIFSRV':'CEXCEPBNDD');
//@@module
//@name:      BCIF94CNTL
//@objective: Controlador de servicio actualizacion de CIF 12094
//@comments:  Este servicio sustituye a servicio 12052.
//@author:    Edson Parajeles Corrales
//@           Jorge R. Jaramillo Herreria -- Novacomp S.A.
//@since:     Enero 2019
//@-----------------------------------------------------------------------------
//@version:   REG-005614
//@author:    Edson Parajeles Corrales
//@since:     marzo 2020
//@comments:  Se recompila para refrescar el campo residencyStateCode a 7
//@           caracteres
//@-----------------------------------------------------------------------------
//@version:   CRI-028566
//@author:    Jeffry Torres Alvarez.
//@since:     Abril 2020
//@comments:  Se agrega la lógica de negocio para la sección
//@           customerTaxInformation.
//@-----------------------------------------------------------------------------
//@version:   CRI-029156
//@comments:  Se agrega la lógica de Negocio para la nueva seccion
//@             countriesWhereCustomerIsTaxed
//@date:      24/07/2020
//@team:      iLegends
//@author:    Esteban Zuñiga Ureña  --  Novacomp S.A.
//@author:    Elliot Castro Chaves
//@-----------------------------------------------------------------------------
//@version:   CRI-027916
//@author:    Edson Parajeles Corrales
//@since:     Julio 2020
//@comments:  Se agrega la lógica de negocio para la campo CES
//@@

/INCLUDE CCGITSRC/QSRCTXT,PROTOTYPEB
/INCLUDE CCGITSRC/QSRCTXT,USEC
/INCLUDE CMQASRC/QSRCTXT,CENVPARMS4
/INCLUDE CMQASRC/QSRCTXT,CFWUTIL4
/INCLUDE CSYSTSRC/QSRCTXT,CEXCEPTION
/INCLUDE Ñ007SRCTXT,BCIF94
/INCLUDE BBCOSRC/QSRCTXT,OBJBASH
/INCLUDE BBCOSRC/QSRCTXT,VALXMLH

dcl-ds serviceKey likeds(serviceKey_T);
dcl-s xmlvalidator like(VALXMLType);

dcl-proc processParms export;
  dcl-pi *n ind;
    XMLReqBuffer char(32767);
    parmsPath varchar(150);
  end-pi;
  dcl-s status ind inz(*on);

  monitor;
    clear serviceKey;
    if validateAgainstXSD(XMLReqBuffer) and loadKeys(XMLReqBuffer:parmsPath);
      status = BCIF94_updateCustomer(%addr(serviceKey):xmlvalidator);
    else;
      status = *off;
    endif;
  on-error;
    CEXCEPTION_catchException();

    CFWUTIL4_logError('CMSGFILUTL'
                     :'FSC4003'
                     :CENVPARMS4_getReqOperationCode()
                     :createXMLResponse);
    status = *off;
  endmon;

  return status;
end-proc;
//------------------------------------------------------------------------------

dcl-proc validateAgainstXSD;
  dcl-pi *n ind;
    XMLReqBuffer char(32767);
  end-pi;
  dcl-s xmlValidatorMessage varchar(500) inz;
  dcl-s i int(10) inz;
   dcl-ds wMessage qualified ;
     schemaLocation varchar(1000);
   end-ds;
   monitor;
    xml-into wMessage %xml(XMLReqBuffer
                          :'path=message +
                            case=any +
                            allowextra=yes +
                            allowmissing=yes +
                            ns=remove');

    VALXML_new(xmlvalidator);
    VALXML_setSchemaLocation(xmlvalidator:wMessage.schemaLocation);
    VALXML_setXmlInput(xmlvalidator:XMLReqBuffer);
    VALXML_execute(xmlvalidator);
    return *on;
  on-error;
    CEXCEPTION_catchException();
    clrHtmlBuffer();
    if CEXCEPTION_getMessageId() = 'SQ20399';
      xmlValidatorMessage = CEXCEPTION_getMessageData();
      i = %scan(':':%trim(xmlValidatorMessage):10);
      if i > 0;
        xmlValidatorMessage = %trim(%subst(xmlValidatorMessage:i+1));
      endif;
    else;
    endif;
    CFWUTIL4_createErrorRes( CEXCEPTION_getMessageId()
                           : %trim(CEXCEPTION_getMessageText())+
                             %trim(xmlValidatorMessage) );
    return *off;
  endmon;
end-proc;
//------------------------------------------------------------------------------

dcl-proc loadKeys;
  dcl-pi *n ind;
    XMLReqBuffer char(32767);
    parmsPath varchar(150);
  end-pi;
  dcl-s successGetKeys ind inz(*on);
  dcl-s xmlIntoOpt char(150);

  if XMLReqBuffer <> *blanks;
    monitor;
      xmlIntoOpt = 'path='+parmsPath+' +
                    case=any +
                    countprefix=c_ +
                    allowextra=yes +
                    allowmissing=yes +
                    ns=remove';

      XML-INTO serviceKey %xml(XMLReqBuffer:xmlIntoOpt);

    on-error;
      CFWUTIL4_logError('CMSGFILUTL':'FSC4001'
                       :CENVPARMS4_getReqOperationCode()
                       :createXMLResponse);

      successGetKeys = *off;

    endmon;

  else;
    CFWUTIL4_logError('CMSGFILUTL':'FSC4002'
                     :CENVPARMS4_getReqOperationCode()
                     :createXMLResponse);

    successGetKeys = *off;

  endif;

  return successGetKeys;
end-proc;
//------------------------------------------------------------------------------

