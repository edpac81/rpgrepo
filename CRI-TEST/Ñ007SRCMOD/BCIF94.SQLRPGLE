**free
ctl-opt nomain bnddir('CCGIBNDDIR':'CMQBNDDIR':'CIFSRV':'CEXCEPBNDD');

//@@module
//@name:      BCIF94
//@objective: Invocar servicio Core que actualiza clientes en el sistema
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
//@since:     agosto 2020
//@comments:  Agregar campo CES a servicio de modificación de Cliente
//@@
/INCLUDE CCGITSRC/QSRCTXT,PROTOTYPEB
/INCLUDE CCGITSRC/QSRCTXT,USEC
/INCLUDE CMQASRC/QSRCTXT,CFWUTIL4
/INCLUDE CSYSTSRC/QSRCTXT,CEXCEPTION
/INCLUDE CMQASRC/QSRCTXT,CENVPARMS4
/INCLUDE CSYSTSRC/QSRCTXT,PGMSTSH

//Prototipos de Modulos de Logica de Negocio y Base de Datos
/INCLUDE BBCOSRC/QSRCTXT,BITAR12094
/INCLUDE BBCOSRC/QSRCTXT,CUMAIDNGST

//Prototipo de lógica de negocio
/INCLUDE BBCOSRC/QSRCTXT,OBJBASH
/INCLUDE Ñ007SRCTXT,BCIF94
/INCLUDE BBCOSRC/QSRCTXT,CIFPARH
/INCLUDE BBCOSRC/QSRCTXT,CTLCIFH

//Variables Globales
dcl-s vWorkCountryCodeISO char(3) inz;
dcl-s vWorkRegionCodeISO char(7) inz;
dcl-s vWorkCountryCodeRef char(3) inz;
dcl-s vWorkRegionCodeRef char(7) inz;
dcl-s vOtherCitizenshipRef char(3) inz;
dcl-s idNumberV20 char(20) inz;
dcl-s posicion zoned(2) inz;
dcl-s nextsequence packed(2);
dcl-s numTelefono zoned(11);
dcl-s propositoTel char(1);
dcl-c vLegalType '2';
dcl-s existeCumst2TB ind inz(*on);

// Clases Globales
dcl-ds key likeds(serviceKey_T) based(serviceKeyPtr);
dcl-s serviceKeyPtr pointer inz;
dcl-s serviceLog like(BITAR12094Type);
dcl-s cumaidngst like(CUMAIDNGSTType);
dcl-s parameter like(CIFPARType);
dcl-s cifController like(CTLCIFType);

//@@method
//@name:      BCIF94_updateCustomer
//@objective: actualizar un cliente físico en el sistema
//@version:   CRI-026607
//@since:     Enero 2019
//@author:    Jorge R. Jaramillo Herreria -- Novacomp S.A.
//@@
dcl-proc BCIF94_updateCustomer export;
  dcl-pi *n ind;
    pServiceKeyP  pointer const;
    pXmlValidator pointer const;
  end-pi;
  dcl-s successInquiry ind inz(*on);

  serviceKeyPtr = pServiceKeyP;
  loadLogData();
  loadParameterClass();

  monitor;
    exec sql SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    writeRequestId();

    CTLCIF_new(cifController:parameter:pXmlValidator);
    CTLCIF_updateCIF(cifController);

    writeResponse();
    exec sql commit;

  on-error;
    exec sql rollback;
    CEXCEPTION_catchException();
    BITAR12094_setCODERR(serviceLog:CEXCEPTION_getMessageId());
    BITAR12094_setMSGERR(serviceLog:CEXCEPTION_getMessageText());

    clrHtmlBuffer();
    CFWUTIL4_createErrorRes( CEXCEPTION_getMessageId()
                           : %trim(CEXCEPTION_getMessageText()));

    successInquiry = *off;
  endmon;
  BITAR12094_setFECRPT(serviceLog:%timestamp);
  BITAR12094_insert(serviceLog);
  return successInquiry;

end-proc;

//@@method
//@name:      loadLogData
//@version:   start
//@objective: Cargar la información de la bitácora
//@author:    Edson Parajeles Corrales
//@since:     Enero 2019
//@@
dcl-proc loadLogData;
  dcl-s sysName char(8);

  exec sql VALUES CURRENT_SERVER INTO :sysName ;

  BITAR12094_new(serviceLog);
  BITAR12094_setFECREQ(serviceLog:%timestamp);
  BITAR12094_setCODAPL(serviceLog:CENVPARMS4_getServiceCode());
  BITAR12094_setNOMJOB(serviceLog:PgmJob);
  BITAR12094_setUSRJOB(serviceLog:PgmUsr);
  BITAR12094_setNUMJOB(serviceLog:PgmJobNbr);
  BITAR12094_setNOMPRG(serviceLog:PgmNam);
  BITAR12094_setCANREQ(serviceLog:%trim(CENVPARMS4_getReqOrgChannel()));
  BITAR12094_setIDNAPL(serviceLog:%trim(CENVPARMS4_getReqOrgApplicationId()));
  BITAR12094_setUSRCHN(serviceLog:%trim(CENVPARMS4_getReqOrgUserChannelId()));
  BITAR12094_setNOMSVD(serviceLog:sysName);
  // datos del request
  BITAR12094_setIDNETD(serviceLog:key.managementCode);
  BITAR12094_setNUMCIF(serviceLog:key.personalInformation.customerNumber);
end-proc;

//@@method
//@name:      loadParameterClass
//@version:   CRI-026092
//@objective: Cargar atributos en clase de parametros CIFPAR
//@author:    Jorge R. Jaramillo Herreria -- Novacomp S.A.
//@since:     Enero 2019
//@@
dcl-proc loadParameterClass;

  CIFPAR_new(parameter);
  CIFPAR_setOperation(parameter:UPDATE);

  loadPersonalInformation(%addr(key.personalInformation));
  if key.c_contactInformation > 0;
    loadContactInformation(%addr(key.contactInformation));
  endif;
  if key.c_workPlaceData > 0;
    loadWorkPlaceData(%addr(key.workPlaceData));
  endif;
  if key.c_classificationCodes > 0;
    loadClassificationCodes(%addr(key.classificationCodes));
  endif;
  if key.c_fatcaInformation > 0;
    loadFatcaInformation(%addr(key.fatcaInformation));
  endif;
  if key.c_multiContractDetail > 0;
    loadMultiContractDetail(%addr(key.multiContractDetail));
  endif;
  if key.c_pepInformation > 0;
    loadPepInformation(%addr(key.pepInformation));
  endif;
  if key.c_listCustomerReference > 0;
    loadListCustomerReference(%addr(key.listCustomerReference));
  endif;
  if key.c_customerTaxInformation > 0;
    loadCustomerTaxInformation(%addr(key.customerTaxInformation));
  endif;

end-proc;

//@@method
//@name:      loadPersonalInformation
//@version:   CRI-026607
//@objective: cargar información de elemento 'personalInformation' en CIFPAR
//@author:    Edson Parajeles Corrales
//@since:     Marzo 2019
//@@
dcl-proc loadPersonalInformation;
  dcl-pi *n;
    ptr pointer const;
  end-pi;
  dcl-ds personalInformation likeds(personalInformation_T) based(ptr);

  loadTagsProperties(%addr(personalInformation.c_customerNumber)
    :%addr(personalInformationTag_a) :43 );

  CIFPAR_setCustomerNumber(parameter:personalInformation.customerNumber);
  CIFPAR_setLegalType(parameter:personalInformation.legalType);
  CIFPAR_setCustomerType(parameter:personalInformation.customerType);
  CIFPAR_setCustomerStatus(parameter:personalInformation.customerStatus);
  CIFPAR_setIdentificationType(parameter:personalInformation.identificationType);
  CIFPAR_setIdentificationNumber(parameter:personalInformation.identificationNumber);
  CIFPAR_setIdentificationCountry(parameter:personalInformation.identificationCountry);
  CIFPAR_setNitCode(parameter:personalInformation.nitCode);
  CIFPAR_setNumberRTN(parameter:personalInformation.numberRTN);
  CIFPAR_setFirstName(parameter:personalInformation.firstName);
  CIFPAR_setMiddleName(parameter:personalInformation.middleName);
  CIFPAR_setLastName(parameter:personalInformation.lastName);
  CIFPAR_setSecondLastName(parameter:personalInformation.secondLastName);
  CIFPAR_setMarriedName(parameter:personalInformation.marriedname);
  CIFPAR_setOtherName(parameter:personalInformation.otherName);
  CIFPAR_setGender(parameter:personalInformation.gender);
  CIFPAR_setBirthDate(parameter:personalInformation.birthDate);
  CIFPAR_setCitizenship(parameter:personalInformation.citizenship);

  // Personal Data +
  CIFPAR_setIdentificationRegionCode(parameter:personalInformation.identificationRegionCode);
  CIFPAR_setIdentificationTownshipCode(parameter:personalInformation.identificationTownshipCode);
  CIFPAR_setIdentificationEmissionDate(parameter:personalInformation.identificationEmissionDate);
  CIFPAR_setIdentificationDueDate(parameter:personalInformation.identificationDueDate);
  CIFPAR_setOtherCitizenshipCode(parameter:key.personalInformation.otherCitizenshipCode);
  CIFPAR_setMigrationStatusCode(parameter:personalInformation.migrationStatusCode);
  CIFPAR_setBirthCountryCode(parameter:personalInformation.birthCountryCode);
  CIFPAR_setEducationLevel(parameter:personalInformation.educationLevel);
  CIFPAR_setMaritalStatus(parameter:personalInformation.maritalStatus);
  CIFPAR_setSpouseName(parameter:personalInformation.spouseName);
  CIFPAR_setSpouseLastName(parameter:personalInformation.spouseLastName);
  CIFPAR_setSpouseSecondLastName(parameter:personalInformation.spouseSecondLastName);
  CIFPAR_setDependantNumber(parameter:personalInformation.dependantNumber);
  CIFPAR_setWhoDependsName(parameter:personalInformation.whoDependsName);
  CIFPAR_setWhoDependsIdType(parameter:personalInformation.whoDependsIdType);
  CIFPAR_setWhoDependsIdNumber(parameter:personalInformation.whoDependsIdNumber);
  CIFPAR_setManageByYourself(parameter:personalInformation.manageByYourself);
  CIFPAR_setKycCode(parameter:personalInformation.kycCode);
  CIFPAR_setGroupCode(parameter:personalInformation.groupCode);
  CIFPAR_setStaffMemberFlag(parameter:personalInformation.staffMemberFlag);
  CIFPAR_setInquiryLevel(parameter:personalInformation.inquiryLevel);
  CIFPAR_setGlobalRenewal(parameter:personalInformation.globalRenewal);
  CIFPAR_setCustomerClassification(parameter:personalInformation.customerClassification);
  CIFPAR_setAtmIssued(parameter:personalInformation.atmIssued);
  CIFPAR_setComercialName(parameter:personalInformation.comercialName);

end-proc;

//@@method
//@name:      loadContactInformation
//@version:   CRI-026607
//@objective: cargar información de elemento 'contactInformation' en CIFPAR
//@author:    Edson Parajeles Corrales
//@since:     Marzo 2019
//@@
dcl-proc loadContactInformation;
  dcl-pi *n;
    ptr pointer const;
  end-pi;
  dcl-ds contactInformation likeds(contactInformation_T) based(ptr);

  loadTagsProperties( %addr(contactInformation.c_address)
                    : %addr(contactInformationTag_a)
                    : 9 );
  loadTagsProperties( %addr(contactInformation.address.c_residencyCountryCode)
                    : %addr(addressTag_a)
                    : 9 );
  CIFPAR_setResidencyCountryCode(parameter:contactInformation.address.residencyCountryCode);
  CIFPAR_setResidencyStateCode(parameter:contactInformation.address.residencyStateCode);
  CIFPAR_setResidencyTownShipCode(parameter:contactInformation.address.residencyTownShipCode);
  CIFPAR_setResidencyStateZoneCode(parameter:contactInformation.address.residencyStateZoneCode);
  CIFPAR_setResidencyCity(parameter:contactInformation.address.residencyCity);
  CIFPAR_setResidencyAddressLine1(parameter:contactInformation.address.residencyAddressLine1);
  CIFPAR_setResidencyAddressLine2(parameter:contactInformation.address.residencyAddressLine2);
  CIFPAR_setResidencyAddressLine3(parameter:contactInformation.address.residencyAddressLine3);
  CIFPAR_setResidencyAreaCode(parameter:contactInformation.address.residencyAreaCode);

  // mail Address
  CIFPAR_setMailingCode(parameter:contactInformation.mailingCode);
  CIFPAR_setEmailAddress(parameter:contactInformation.emailAddress);
  CIFPAR_setEmailAddress2(parameter:contactInformation.emailAddress2);
  CIFPAR_setPoBox(parameter:contactInformation.poBox);

  // home phone number
  CIFPAR_setHomeAreaCode(parameter:contactInformation.homePhoneNumber.areaCode);
  CIFPAR_setHomePhoneNumber(parameter:contactInformation.homePhoneNumber.phoneNumber);

  // work phone number
  CIFPAR_setWorkAreaCode(parameter:contactInformation.workPhoneNumber.areaCode);
  CIFPAR_setWorkPhoneNumber(parameter:contactInformation.workPhoneNumber.phoneNumber);

  // mobile phone number
  CIFPAR_setMobileAreaCode(parameter:contactInformation.mobilePhoneNumber.areaCode);
  CIFPAR_setMobilePhoneNumber(parameter:contactInformation.mobilePhoneNumber.phoneNumber);

  // fax phone number
  CIFPAR_setFaxAreaCode(parameter:contactInformation.faxPhoneNumber.areaCode);
  CIFPAR_setFaxPhoneNumber(parameter:contactInformation.faxPhoneNumber.phoneNumber);

end-proc;

//@@method
//@name:      loadWorkPlaceData
//@version:   CRI-026607
//@objective: cargar información de elemento 'workPlaceData' en CIFPAR
//@author:    Edson Parajeles Corrales
//@since:     Marzo 2019
//@@
dcl-proc loadWorkPlaceData;
  dcl-pi *n;
    ptr pointer const;
  end-pi;
  dcl-ds workPlaceData likeds(workPlaceData_T) based(ptr);

  loadTagsProperties(%addr(workPlaceData.c_companyName)
    :%addr(workPlaceDataTag_a) :19 );

  CIFPAR_setCompanyName(parameter:workPlaceData.companyName);
  CIFPAR_setCompanyAddress(parameter:workPlaceData.companyAddress);
  CIFPAR_setCompanyPosition(parameter:workPlaceData.companyPosition);
  CIFPAR_setTimeWorking(parameter:workPlaceData.timeWorking);
  CIFPAR_setTimeWorkingMeasurement(parameter:workPlaceData.timeWorkingMeasurement);
  CIFPAR_setMonthlyIncome(parameter:workPlaceData.monthlyIncome);
  CIFPAR_setMonthlyIncomeCurrency(parameter:workPlaceData.monthlyIncomeCurrency);
  CIFPAR_setOtherIncome(parameter:workPlaceData.otherIncome);
  CIFPAR_setOtherIncomeCurrency(parameter:workPlaceData.otherIncomeCurrency);
  CIFPAR_setSourceOfOtherIncomeCode(parameter:workPlaceData.sourceOfOtherIncomeCode);
  CIFPAR_setWorkWebsite(parameter:workPlaceData.workWebsite);
  CIFPAR_setWorkEmailAddress(parameter:workPlaceData.workEmailAddress);
  CIFPAR_setWorkTypeCode(parameter:workPlaceData.workTypeCode);
  CIFPAR_setWorkCountryCode(parameter:workPlaceData.workCountryCode);
  CIFPAR_setWorkRegionCode(parameter:workPlaceData.workRegionCode);
  CIFPAR_setWorkTownshipCode(parameter:workPlaceData.workTownshipCode);
  CIFPAR_setWorkZoneCode(parameter:workPlaceData.workZoneCode);
  CIFPAR_setMonthlyExpenses(parameter:workPlaceData.monthlyExpenses);
  CIFPAR_setAssetsTotal(parameter:workPlaceData.assetsTotal);

end-proc;

//@@method
//@name:      loadClassificationCodes
//@version:   CRI-026607
//@objective: cargar información de elemento 'classificationCodes' en CIFPAR
//@author:    Edson Parajeles Corrales
//@since:     Marzo 2019
//@@
dcl-proc loadClassificationCodes;
  dcl-pi *n;
    ptr pointer const;
  end-pi;
  dcl-ds classificationCodes likeds(classificationCodes_T) based(ptr);

  loadTagsProperties(%addr(classificationCodes.c_mainOfficerCode)
    :%addr(classificationCodesTag_a) :14 );

  CIFPAR_setMainOfficerCode(parameter:classificationCodes.mainOfficerCode);
  CIFPAR_setSecondOfficerCode(parameter:classificationCodes.secondOfficerCode);
  CIFPAR_setBusinessCode(parameter:classificationCodes.businessCode);
  CIFPAR_setIndustryCode(parameter:classificationCodes.industryCode);
  CIFPAR_setUserCode1(parameter:classificationCodes.userCode1);
  CIFPAR_setUserCode2(parameter:classificationCodes.userCode2);
  CIFPAR_setUserCode3(parameter:classificationCodes.userCode3);
  CIFPAR_setUserCode4(parameter:classificationCodes.userCode4);
  CIFPAR_setWithholdingTaxFlag(parameter:classificationCodes.withholdingTaxFlag);
  CIFPAR_setReferredByCode(parameter:classificationCodes.referredByCode);
  CIFPAR_setReferredByName(parameter:classificationCodes.referredByName);
  CIFPAR_setRiskLevel(parameter:classificationCodes.riskLevel);
  CIFPAR_setSourceOfIncome(parameter:classificationCodes.sourceOfIncome);
  CIFPAR_setSimplifiedFile(parameter:key.classificationCodes.simplifiedFile);
end-proc;

//@@method
//@name:      loadFatcaInformation
//@version:   CRI-026607
//@objective: cargar información de elemento 'fatcaInformation' en CIFPAR
//@author:    Edson Parajeles Corrales
//@since:     Marzo 2019
//@@
dcl-proc loadFatcaInformation;
  dcl-pi *n;
    ptr pointer const;
  end-pi;
  dcl-ds fatcaInformation likeds(fatcaInformation_T) based(ptr);
  dcl-s i int(10);

  loadTagsProperties(%addr(fatcaInformation.c_fatcaFormCode)
    :%addr(fatcaInformationTag_a) :9);

  CIFPAR_setFatcaFormCode(parameter:fatcaInformation.fatcaFormCode);
  CIFPAR_setFatcaID(parameter:fatcaInformation.fatcaID);
  CIFPAR_setIsTaxPayer(parameter:fatcaInformation.isTaxPayer);
  for i = 1 to key.fatcaInformation.taxResidence.c_country;
    CIFPAR_addTaxResidence(parameter
                          :fatcaInformation.taxResidence.country(i).code
                          :fatcaInformation.taxResidence.country(i).id);
  endfor;
end-proc;

//@@method
//@name:      loadMulticontractDetail
//@version:   CRI-026607
//@objective: cargar información de elemento 'multiContractDetail' en CIFPAR
//@author:    Edson Parajeles Corrales
//@since:     Marzo 2019
//@@
dcl-proc loadMulticontractDetail;
  dcl-pi *n;
    ptr pointer const;
  end-pi;
  dcl-ds multiContractDetail likeds(multicontract_T) based(ptr);

  loadTagsProperties(
     %addr(multiContractDetail.c_multicontractFirm)
    :%addr(multiContractDetailTag_a) :2 );

  CIFPAR_setMulticontractFirm(parameter:multiContractDetail.multicontractFirm);
  CIFPAR_setMulticontractVersion(parameter:multiContractDetail.multicontractVersion);
end-proc;

//@@method
//@name:      loadPepInformation
//@version:   CRI-026607
//@objective: cargar información de elemento 'pepInformation' en CIFPAR
//@author:    Edson Parajeles Corrales
//@since:     Marzo 2019
//@@
dcl-proc loadPepInformation;
  dcl-pi *n;
    ptr pointer const;
  end-pi;
  dcl-ds pepInformation likeds(pepInformation_T) based(ptr);

  loadTagsProperties(%addr(pepInformation.c_isPEP) :%addr(pepInformationTag_a) :9);

  CIFPAR_setIsPEP(parameter:pepInformation.isPEP);
  CIFPAR_setIsRelatedWithPEP(parameter:pepInformation.isRelatedWithPEP);
  CIFPAR_setIsAssociatedWithPEP(parameter:pepInformation.isAssociatedWithPEP);
  CIFPAR_setIsRepresentedPEP(parameter:pepInformation.isRepresentedPEP);
  CIFPAR_setIsRepresentedStateSupplier(parameter:pepInformation.isRepresentedStateSupplier);
  CIFPAR_setIsExchangePawnshopNightClubActivity(parameter
    :pepInformation.isExchangePawnshopNightClubActivity);
  CIFPAR_setIsStateSupplier(parameter:pepInformation.isStateSupplier);
  CIFPAR_setPepPositionCode(parameter:pepInformation.pepPositionCode);
  CIFPAR_setPepRelationshipType(parameter:pepInformation.pepRelationshipType);
end-proc;

//@@method
//@name:      loadListCustomerReference
//@version:   CRI-026607
//@objective: cargar información de elemento 'listCustomerReference' en CIFPAR
//@author:    Edson Parajeles Corrales
//@since:     Marzo 2019
//@@
dcl-proc loadListCustomerReference;
  dcl-pi *n;
    ptr pointer const;
  end-pi;
  dcl-ds listCustomerReference likeds(listCustomerReference_T) based(ptr);
  dcl-s i int(10);

  loadTagsProperties(%addr(listCustomerReference.c_CustomerReference)
    :%addr(listCustomerReferenceTag_a) :13);

  for i = 1 to key.listCustomerReference.c_customerReference;
    CIFPAR_addCustomerReference(parameter
      :listCustomerReference.customerReference(i).referenceSequence
      :listCustomerReference.customerReference(i).referenceType
      :listCustomerReference.customerReference(i).referringFirstName
      :listCustomerReference.customerReference(i).referringSecondName
      :listCustomerReference.customerReference(i).referringLastName
      :listCustomerReference.customerReference(i).referringSecondLastName
      :listCustomerReference.customerReference(i).referringPhone
      :listCustomerReference.customerReference(i).referringCellphone
      :listCustomerReference.customerReference(i).relationshipType
      :listCustomerReference.customerReference(i).contactName
      :listCustomerReference.customerReference(i).relationshipTime
      :listCustomerReference.customerReference(i).relationshipTimeFrecuency
      :listCustomerReference.customerReference(i).referenceWayCode);
  endfor;
end-proc;

//@@method
//@name:      loadCustomerTaxInformation
//@version:   CRI-028566
//@objective: cargar información de elemento 'customerTaxInformation' en CIFPAR
//@author:    Jeffry Torres Alvarez
//@since:     Marzo 2020
//@@
dcl-proc loadCustomerTaxInformation;
  dcl-pi *n;
    ptr pointer const;
  end-pi;
  dcl-ds customerTaxInformation likeds(customerTaxInformation_T) based(ptr);
  dcl-s i int(10);

  loadTagsProperties(%addr(customerTaxInformation.c_taxID)
    :%addr(customerTaxInformationTag_a) :4);

  loadTagsProperties(%addr(customerTaxInformation.c_taxCountriesList)
    :%addr(taxCountriesListTag_a) :1);

  loadTagsProperties(%addr(customerTaxInformation.taxCountriesList.
    c_countryOriginOrDestinationOffunds)
    :%addr(countryOriginOrDestinationOffundsTag_a) :2);
  //-------------------------------------
  // Se carga la informacion para la
  // validacion dinamica de los tags.
  //-------------------------------------
  loadTagsProperties(%addr(customerTaxInformation.
                           c_countriesWhereCustomerIsTaxed)
                    :%addr(countriesWhereCustomerIsTaxedTag_a) :1);
  loadTagsProperties(%addr(customerTaxInformation.countriesWhereCustomerIsTaxed
                           .c_taxIDList)
                    :%addr(taxIDListTag_a) :2);

  CIFPAR_setTaxIDType(parameter :customerTaxInformation.taxID);
  CIFPAR_setCountryTaxType(parameter :customerTaxInformation.countryTax);

  for i = 1 to key.customerTaxInformation.taxCountriesList.c_countryOriginOrDestinationOffunds;
    CIFPAR_addCustomerTaxInformation(parameter:
      customerTaxInformation.taxCountriesList.countryOriginOrDestinationOffunds(i).country:
      customerTaxInformation.taxCountriesList.countryOriginOrDestinationOffunds(i).type);
  endfor;

  //-------------------------------------
  // Se ingresa el nuevo tag del XML
  // <countriesWhereCustomerIsTaxed>.
  //-------------------------------------
  for i = 1 to key.customerTaxInformation.countriesWhereCustomerIsTaxed.c_taxIDList;
    CIFPAR_addCountriesWhereCustomerIsTaxed(parameter:
        customerTaxInformation.countriesWhereCustomerIsTaxed.taxIDList(i).countryTax
       :customerTaxInformation.countriesWhereCustomerIsTaxed.taxIDList(i).taxID);
  endfor;
end-proc;

//@@method
//@name:      loadTagsProperties
//@version:   start
//@objective: Obtener datos de los elementos provenientes en XML Request
//@author:    Edson Parajeles Corrales
//@since:     Julio 2019
//@@
dcl-proc loadTagsProperties;
  dcl-pi *n;
    pTagCounter pointer const;
    pTagName pointer const;
    pTotal int(5) const;
  end-pi;
  dcl-s i int(5) inz;
  dcl-s tag_c int(5) dim(50) based(pTagCounter);
  dcl-s tag_n char(tagNameLen) dim(50) based(pTagName);

  for i = 1 to pTotal;
    CIFPAR_addTag(parameter :tag_n(i) :(tag_c(i) = 0));
  endfor;
end-proc;

//@@method
//@name:      writeRequestId
//@version:   start
//@objective: Escribir tabla de control de gestiones CUMAIDNGST
//@author:    Edson Parajeles Corrales
//@since:     Enero 2019
//@@
dcl-proc writeRequestId;
  CUMAIDNGST_new(cumaidngst);
  if CUMAIDNGST_isOnFile(cumaidngst
                        :key.managementCode
                        :CENVPARMS4_getServiceCode());
    CEXCEPTION_throwNewException('CUS0065':'BMSGFILUTL');
  endif;
  CUMAIDNGST_setGSTETD(cumaidngst:key.managementCode);
  CUMAIDNGST_setUSRGST(cumaidngst:PgmUsr);
  CUMAIDNGST_setFEIGST(cumaidngst:%timestamp);
  CUMAIDNGST_setCODSRV(cumaidngst:CENVPARMS4_getServiceCode());
  CUMAIDNGST_insert(cumaidngst);
end-proc;

//@@method
//@name:      writeResponse
//@version:   start
//@objective: Escribir respuesta del servicio
//@author:    Edson Parajeles Corrales
//@since:     Enero 2019
//@@
dcl-proc writeResponse;
  updHTMLvar('idManagement': %char(CUMAIDNGST_getGSTSDA(cumaidngst)));
  updHTMLvar('customerNumber': %char(key.personalInformation.customerNumber));
  wrtSection('IdManagement': *on);
end-proc;

