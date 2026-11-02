CLASS lhc_header DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      get_instance_authorizations FOR INSTANCE AUTHORIZATION
        IMPORTING keys REQUEST requested_authorizations FOR Header RESULT result,

      read FOR READ
        IMPORTING keys FOR READ Header RESULT result,

      lock FOR LOCK
        IMPORTING keys FOR LOCK Header,

      rba_item FOR READ
        IMPORTING keys_rba FOR READ Header\_Item FULL result_requested
        RESULT result LINK association_links.
ENDCLASS.


CLASS lhc_header IMPLEMENTATION.

  METHOD get_instance_authorizations.
    " No modifying operations exist, so nothing needs authorizing per instance.
    result = VALUE #( FOR key IN keys ( %tky = key-%tky ) ).
  ENDMETHOD.


  METHOD read.
    DATA ls_result LIKE LINE OF result.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      SELECT SINGLE
        FROM zfi_i_acctdocheader
        FIELDS companycode, fiscalyear, accountingdocument,
               accountingdocumenttype, documentdate, postingdate,
               accountingdocumentheadertext, documentreferenceid,
               transactioncurrency, accountingdocumentcreationdate
        WHERE companycode        = @<key>-companycode
          AND fiscalyear         = @<key>-fiscalyear
          AND accountingdocument = @<key>-accountingdocument
        INTO @DATA(ls_header).

      IF sy-subrc = 0.
        CLEAR ls_result.
        ls_result = CORRESPONDING #( ls_header ).
        INSERT ls_result INTO TABLE result.
        " INSERT respects the table's sort order. APPEND does not check it.
      ELSE.
        INSERT VALUE #( %tky        = <key>-%tky
                        %fail-cause = if_abap_behv=>cause-not_found )
               INTO TABLE failed-header.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD lock.
    " Read-only application: nothing is ever locked.
  ENDMETHOD.


  METHOD rba_item.
    DATA ls_result LIKE LINE OF result.

    LOOP AT keys_rba ASSIGNING FIELD-SYMBOL(<key>).
      SELECT
        FROM zfi_i_acctdocitem
        FIELDS companycode, fiscalyear, accountingdocument, accountingdocumentitem,
               glaccount, financialaccounttype, debitcreditcode, postingdate,
               supplier, customer, profitcenter, costcenter, documentitemtext,
               amountincompanycodecurrency, companycodecurrency,
               amountintransactioncurrency, transactioncurrency
        WHERE companycode        = @<key>-companycode
          AND fiscalyear         = @<key>-fiscalyear
          AND accountingdocument = @<key>-accountingdocument
        ORDER BY accountingdocumentitem
        INTO TABLE @DATA(lt_items).
      " ORDER BY gives a stable, predictable order for the rows inserted below.

      LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<item>).

        IF result_requested = abap_true.
          CLEAR ls_result.
          ls_result = CORRESPONDING #( <item> ).
          INSERT ls_result INTO TABLE result.
          " Item data only when the framework asked for it (FULL result_requested).
        ENDIF.

        INSERT VALUE #( source-%tky                   = <key>-%tky
                        target-companycode            = <item>-companycode
                        target-fiscalyear             = <item>-fiscalyear
                        target-accountingdocument     = <item>-accountingdocument
                        target-accountingdocumentitem = <item>-accountingdocumentitem )
               INTO TABLE association_links.
        " Links are always returned: they say which item belongs to which header.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      read FOR READ
        IMPORTING keys FOR READ Item RESULT result,

      rba_header FOR READ
        IMPORTING keys_rba FOR READ Item\_Header FULL result_requested
        RESULT result LINK association_links.
ENDCLASS.


CLASS lhc_item IMPLEMENTATION.

  METHOD read.
    DATA ls_result LIKE LINE OF result.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      SELECT SINGLE
        FROM zfi_i_acctdocitem
        FIELDS companycode, fiscalyear, accountingdocument, accountingdocumentitem,
               glaccount, financialaccounttype, debitcreditcode, postingdate,
               supplier, customer, profitcenter, costcenter, documentitemtext,
               amountincompanycodecurrency, companycodecurrency,
               amountintransactioncurrency, transactioncurrency
        WHERE companycode            = @<key>-companycode
          AND fiscalyear             = @<key>-fiscalyear
          AND accountingdocument     = @<key>-accountingdocument
          AND accountingdocumentitem = @<key>-accountingdocumentitem
        INTO @DATA(ls_item).

      IF sy-subrc = 0.
        CLEAR ls_result.
        ls_result = CORRESPONDING #( ls_item ).
        INSERT ls_result INTO TABLE result.
      ELSE.
        INSERT VALUE #( %tky        = <key>-%tky
                        %fail-cause = if_abap_behv=>cause-not_found )
               INTO TABLE failed-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD rba_header.
    DATA ls_result LIKE LINE OF result.

    LOOP AT keys_rba ASSIGNING FIELD-SYMBOL(<key>).
      SELECT SINGLE
        FROM zfi_i_acctdocheader
        FIELDS companycode, fiscalyear, accountingdocument,
               accountingdocumenttype, documentdate, postingdate,
               accountingdocumentheadertext, documentreferenceid,
               transactioncurrency, accountingdocumentcreationdate
        WHERE companycode        = @<key>-companycode
          AND fiscalyear         = @<key>-fiscalyear
          AND accountingdocument = @<key>-accountingdocument
        INTO @DATA(ls_header).

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      IF result_requested = abap_true.
        CLEAR ls_result.
        ls_result = CORRESPONDING #( ls_header ).
        INSERT ls_result INTO TABLE result.
      ENDIF.

      INSERT VALUE #( source-%tky               = <key>-%tky
                      target-companycode        = ls_header-companycode
                      target-fiscalyear         = ls_header-fiscalyear
                      target-accountingdocument = ls_header-accountingdocument )
             INTO TABLE association_links.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lsc_zfi_i_acctdocheader DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS:
      save REDEFINITION,
      cleanup REDEFINITION,
      cleanup_finalize REDEFINITION.
ENDCLASS.


CLASS lsc_zfi_i_acctdocheader IMPLEMENTATION.

  METHOD save.
    " Read-only application: nothing to save.
  ENDMETHOD.

  METHOD cleanup.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
