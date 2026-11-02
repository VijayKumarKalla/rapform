CLASS zcl_fi_acctdoc_form DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_sadl_exit_calc_element_read.

    CLASS-METHODS get_pdf
      IMPORTING
        im_v_company_code TYPE zfi_c_acctdocheader-companycode
        im_v_fiscal_year  TYPE zfi_c_acctdocheader-fiscalyear
        im_v_document     TYPE zfi_c_acctdocheader-accountingdocument
      RETURNING
        VALUE(rt_v_pdf)   TYPE xstring
      RAISING
        cx_fp_fdp_error
        cx_fp_form_reader
        cx_fp_ads_util.

    CLASS-METHODS get_xml
      IMPORTING
        im_v_company_code TYPE zfi_c_acctdocheader-companycode
        im_v_fiscal_year  TYPE zfi_c_acctdocheader-fiscalyear
        im_v_document     TYPE zfi_c_acctdocheader-accountingdocument
      RETURNING
        VALUE(rt_v_xml)   TYPE xstring
      RAISING
        cx_fp_fdp_error.

  PRIVATE SECTION.

    CLASS-DATA mc_duplicate_call TYPE abap_boolean.
    " Recursion guard: the form data read re-reads this entity, which would call calculate again.

    CLASS-DATA mv_last_error TYPE string.
    " Last error text. Read it in the debugger after a failed file generation.

    CLASS-METHODS get_pdf_from_xml
      IMPORTING
        im_v_xml        TYPE xstring
      RETURNING
        VALUE(rt_v_pdf) TYPE xstring
      RAISING
        cx_fp_form_reader
        cx_fp_ads_util.

ENDCLASS.


CLASS zcl_fi_acctdoc_form IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~calculate.

    DATA lt_header TYPE STANDARD TABLE OF zfi_c_acctdocheader WITH DEFAULT KEY.
    DATA lv_xml    TYPE xstring.
    DATA lv_pdf    TYPE xstring.
    DATA lv_xml_ok TYPE abap_boolean.

    lt_header = CORRESPONDING #( it_original_data ).

    " Which binary streams does the consumer want right now? Names are UPPERCASE.
    DATA(lv_want_pdf)     = xsdbool( line_exists( it_requested_calc_elements[ table_line = 'ATTACHMENT' ] ) ).
    DATA(lv_want_preview) = xsdbool( line_exists( it_requested_calc_elements[ table_line = 'PREVIEWPDF' ] ) ).
    DATA(lv_want_xml)     = xsdbool( line_exists( it_requested_calc_elements[ table_line = 'XMLATTACHMENT' ] ) ).
    DATA(lv_need_data)    = xsdbool( lv_want_pdf = abap_true
                                  OR lv_want_preview = abap_true
                                  OR lv_want_xml = abap_true ).

    LOOP AT lt_header ASSIGNING FIELD-SYMBOL(<fs_header>).

      CLEAR: lv_xml, lv_pdf, lv_xml_ok.
      " Fresh state per row, so one failure can never reuse the previous row's content.

      "---- File names and content types: cheap, always filled ----
      <fs_header>-filename =
        |{ <fs_header>-companycode }_{ <fs_header>-fiscalyear }_| &&
        |{ <fs_header>-accountingdocument ALPHA = OUT }.pdf|.
      <fs_header>-mimetype = 'application/pdf'.

      <fs_header>-previewfilename =
        |{ <fs_header>-companycode }_{ <fs_header>-fiscalyear }_| &&
        |{ <fs_header>-accountingdocument ALPHA = OUT }_PREVIEW.pdf|.
      <fs_header>-previewmimetype = 'application/pdf'.

      <fs_header>-xmlfilename =
        |{ <fs_header>-companycode }_{ <fs_header>-fiscalyear }_| &&
        |{ <fs_header>-accountingdocument ALPHA = OUT }.xml|.
      <fs_header>-xmlmimetype = 'application/xml'.

      "---- File contents: only when requested and not inside our own nested read ----
      IF lv_need_data = abap_true AND mc_duplicate_call IS INITIAL.

        " Step 1: the XML. Its own TRY, so a PDF problem can never wipe it.
        TRY.
            lv_xml = get_xml(
              im_v_company_code = <fs_header>-companycode
              im_v_fiscal_year  = <fs_header>-fiscalyear
              im_v_document     = <fs_header>-accountingdocument ).
            lv_xml_ok = abap_true.

          CATCH cx_fp_fdp_error cx_sy_itab_line_not_found INTO DATA(lx_xml).
            mv_last_error = lx_xml->get_text( ).
            " Breakpoint here while testing. The streams simply stay empty.
        ENDTRY.

        IF lv_xml_ok = abap_true.

          IF lv_want_xml = abap_true.
            <fs_header>-xmlattachment = lv_xml.
          ENDIF.

          " Step 2: the PDF. Separate TRY, and it only ever clears the PDF fields.
          IF lv_want_pdf = abap_true OR lv_want_preview = abap_true.
            TRY.
                lv_pdf = get_pdf_from_xml( im_v_xml = lv_xml ).

                IF lv_want_pdf = abap_true.
                  <fs_header>-attachment = lv_pdf.
                ENDIF.
                IF lv_want_preview = abap_true.
                  <fs_header>-previewpdf = lv_pdf.
                ENDIF.

              CATCH cx_fp_form_reader cx_fp_ads_util INTO DATA(lx_pdf).
                mv_last_error = lx_pdf->get_text( ).
                " Expected until the form ZFI_ACCTDOC_OUTPUT exists. The XML is untouched.
            ENDTRY.
          ENDIF.

        ENDIF.

      ENDIF.

    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_header ).

  ENDMETHOD.


METHOD if_sadl_exit_calc_element_read~get_calculation_info.

  DATA lv_element TYPE string.

  " Accounting Document Number
  lv_element = 'ACCOUNTINGDOCUMENT'.
  INSERT lv_element INTO TABLE et_requested_orig_elements.

  " Company Code
  lv_element = 'COMPANYCODE'.
  INSERT lv_element INTO TABLE et_requested_orig_elements.

  " Fiscal Year
  lv_element = 'FISCALYEAR'.
  INSERT lv_element INTO TABLE et_requested_orig_elements.

ENDMETHOD.


  METHOD get_xml.

    DATA(lv_previous_guard) = mc_duplicate_call.
    mc_duplicate_call = abap_true.
    " Guard up BEFORE the read, so the nested calculate( ) skips file generation.

    TRY.
        DATA(lo_fdp_api) = cl_fp_fdp_services=>get_instance(
          iv_max_depth          = 1
          iv_service_definition = 'ZFI_ACCTDOC_FORM_DATA' ).

        DATA(lt_keys) = lo_fdp_api->get_keys( ).

        lt_keys[ name = 'COMPANYCODE' ]-value        = im_v_company_code.
        lt_keys[ name = 'FISCALYEAR' ]-value         = im_v_fiscal_year.
        lt_keys[ name = 'ACCOUNTINGDOCUMENT' ]-value = im_v_document.

        rt_v_xml = lo_fdp_api->read_to_xml_v2( it_select = lt_keys ).

      CLEANUP.
        mc_duplicate_call = lv_previous_guard.
        " Runs only if an exception leaves the TRY block.
    ENDTRY.

    mc_duplicate_call = lv_previous_guard.

  ENDMETHOD.


  METHOD get_pdf.

    DATA(lv_xml) = get_xml(
      im_v_company_code = im_v_company_code
      im_v_fiscal_year  = im_v_fiscal_year
      im_v_document     = im_v_document ).

    rt_v_pdf = get_pdf_from_xml( im_v_xml = lv_xml ).

  ENDMETHOD.


  METHOD get_pdf_from_xml.

    DATA(lo_reader) = cl_fp_form_reader=>create_form_reader( 'ZFI_ACCTDOC_OUTPUT' ).
    DATA(ls_layout) = lo_reader->get_layout( ).

    cl_fp_ads_util=>render_pdf(
      EXPORTING iv_xml_data   = im_v_xml
                iv_xdp_layout = ls_layout
                iv_locale     = 'en_US'
      IMPORTING ev_pdf        = rt_v_pdf ).

  ENDMETHOD.

ENDCLASS.
