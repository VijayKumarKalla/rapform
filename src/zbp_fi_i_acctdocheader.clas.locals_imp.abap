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
        RESULT result LINK association_links,
      DisplaySummary FOR MODIFY
            keys FOR ACTION Header~DisplaySummary RESULT result,
      ShowItemCount FOR MODIFY
            keys FOR ACTION Header~ShowItemCount RESULT result,
      CheckDocumentBalance FOR MODIFY
            keys FOR ACTION Header~CheckDocumentBalance RESULT result.
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



METHOD displaySummary.

  LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

    "Read selected Accounting Document Header
    SELECT SINGLE
      FROM zfi_i_acctdocheader
      FIELDS companycode,
             fiscalyear,
             accountingdocument,
             accountingdocumenttype,
             documentdate,
             postingdate,
             accountingdocumentheadertext,
             documentreferenceid,
             transactioncurrency,
             accountingdocumentcreationdate
      WHERE companycode        = @<key>-companycode
        AND fiscalyear         = @<key>-fiscalyear
        AND accountingdocument = @<key>-accountingdocument
      INTO @DATA(ls_header).

    IF sy-subrc = 0.

      "Return the selected entity as action result
      APPEND VALUE #(
        %tky   = <key>-%tky
        %param = CORRESPONDING #( ls_header )
      ) TO result.

      "Summary message 1: Company Code
      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-information
          text     = |Company Code: { ls_header-companycode }|
        )
      ) TO reported-header.

      "Summary message 2: Fiscal Year
      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-information
          text     = |Fiscal Year: { ls_header-fiscalyear }|
        )
      ) TO reported-header.

      "Summary message 3: Accounting Document
      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-information
          text     = |Accounting Document: { ls_header-accountingdocument }|
        )
      ) TO reported-header.

    ELSE.

      "Document not found
      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Accounting Document not found.'
        )
      ) TO reported-header.

    ENDIF.

  ENDLOOP.

ENDMETHOD.




METHOD showItemCount.

  LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

    "Count accounting line items for the selected document
    SELECT COUNT( * )
      FROM zfi_i_acctdocitem
      WHERE companycode        = @<key>-companycode
        AND fiscalyear         = @<key>-fiscalyear
        AND accountingdocument = @<key>-accountingdocument
      INTO @DATA(lv_item_count).

    "Return the selected header as the action result
    APPEND VALUE #(
      %tky   = <key>-%tky
      %param = CORRESPONDING #( <key> )
    ) TO result.

    "Display the item count
    APPEND VALUE #(
      %tky = <key>-%tky
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-success
        text     = |This document contains { lv_item_count } accounting line items.|
      )
    ) TO reported-header.

  ENDLOOP.

ENDMETHOD.



METHOD checkDocumentBalance.

  LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

    "Calculate total debit and credit amounts
    SELECT
      FROM zfi_i_acctdocitem
      FIELDS
        debitcreditcode,
        SUM( amountincompanycodecurrency ) AS total_amount
      WHERE companycode        = @<key>-companycode
        AND fiscalyear         = @<key>-fiscalyear
        AND accountingdocument = @<key>-accountingdocument
      GROUP BY debitcreditcode
      INTO TABLE @DATA(lt_totals).

    DATA: lv_debit  TYPE zfi_i_acctdocitem-amountincompanycodecurrency,
          lv_credit TYPE zfi_i_acctdocitem-amountincompanycodecurrency.

    CLEAR: lv_debit, lv_credit.

    LOOP AT lt_totals ASSIGNING FIELD-SYMBOL(<total>).

      CASE <total>-debitcreditcode.

        WHEN 'S'.
          lv_debit = <total>-total_amount.

        WHEN 'H'.
          lv_credit = <total>-total_amount.

      ENDCASE.

    ENDLOOP.

    "Calculate difference
    DATA(lv_difference) = lv_debit - lv_credit.

    "Return selected header
    APPEND VALUE #(
      %tky   = <key>-%tky
      %param = CORRESPONDING #( <key> )
    ) TO result.

    "Report balance status
    IF lv_difference = 0.

      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-success
          text = 'Accounting Document is balanced.'
        )
      ) TO reported-header.

    ELSE.

      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-warning
          text = |Document is NOT balanced. Difference: { lv_difference }|
        )
      ) TO reported-header.

    ENDIF.

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
