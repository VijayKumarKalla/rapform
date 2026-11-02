@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Accounting Document Header (Projection)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.supportedCapabilities: [#OUTPUT_FORM_DATA_PROVIDER]
@Metadata.allowExtensions: true

define root view entity ZFI_C_AcctDocHeader
  provider contract transactional_query
  as projection on ZFI_I_AcctDocHeader
{
          /*----------------------------------------------------------*/
          /* Accounting Document Header Keys                          */
          /*----------------------------------------------------------*/
  key     CompanyCode,
  key     FiscalYear,
  key     AccountingDocument,

          /*----------------------------------------------------------*/
          /* Accounting Document Header Information                   */
          /*----------------------------------------------------------*/
          AccountingDocumentType,
          DocumentDate,
          PostingDate,
          AccountingDocumentHeaderText,
          DocumentReferenceID,
          TransactionCurrency,
          AccountingDocumentCreationDate,

          /*----------------------------------------------------------*/
          /* PDF Download - Existing Implementation                   */
          /*----------------------------------------------------------*/
          @EndUserText.label: 'PDF Filename'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_FI_ACCTDOC_FORM'
  virtual Filename        : abap.char(50),

          @EndUserText.label: 'PDF MIME Type'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_FI_ACCTDOC_FORM'
          @Semantics.mimeType: true
  virtual MimeType        : abap.char(50),

          @EndUserText.label: 'Download PDF'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_FI_ACCTDOC_FORM'
          @Semantics.largeObject: {
            mimeType: 'MimeType',
            fileName: 'Filename',
            contentDispositionPreference: #ATTACHMENT
          }
  virtual Attachment      : abap.rawstring(0),

          /*----------------------------------------------------------*/
          /* PDF Preview - Inline Browser Display                     */
          /*----------------------------------------------------------*/
          @EndUserText.label: 'PDF Preview Filename'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_FI_ACCTDOC_FORM'
  virtual PreviewFilename : abap.char(100),

          @EndUserText.label: 'PDF Preview MIME Type'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_FI_ACCTDOC_FORM'
          @Semantics.mimeType: true
  virtual PreviewMimeType : abap.char(50),

          @EndUserText.label: 'Preview PDF'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_FI_ACCTDOC_FORM'
          @Semantics.largeObject: {
            mimeType: 'PreviewMimeType',
            fileName: 'PreviewFilename',
            contentDispositionPreference: #INLINE
          }
  virtual PreviewPDF      : abap.rawstring(0),

          /*----------------------------------------------------------*/
          /* XML Download - Adobe Form Data                           */
          /*----------------------------------------------------------*/
          @EndUserText.label: 'XML Filename'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_FI_ACCTDOC_FORM'
  virtual XMLFilename     : abap.char(100),

          @EndUserText.label: 'XML MIME Type'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_FI_ACCTDOC_FORM'
          @Semantics.mimeType: true
  virtual XMLMimeType     : abap.char(50),

          @EndUserText.label: 'Download Form XML'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_FI_ACCTDOC_FORM'
          @Semantics.largeObject: {
            mimeType: 'XMLMimeType',
            fileName: 'XMLFilename',
            contentDispositionPreference: #ATTACHMENT
          }
  virtual XMLAttachment   : abap.rawstring(0),

          /*----------------------------------------------------------*/
          /* Header-to-Item Composition                               */
          /*----------------------------------------------------------*/
          _Item : redirected to composition child ZFI_C_AcctDocItem
}

/*------------------------------------------------------------*/
/* DEVELOPER NOTES                                             */
/*------------------------------------------------------------*/
/*
  1. Attachment
     Existing PDF download stream. Its content disposition is
     #ATTACHMENT.

  2. PreviewPDF
     Separate PDF stream intended for inline browser display.
     It uses the same Adobe Form output as Attachment.

  3. XMLAttachment
     Contains the XML data used by the Adobe Form.
     It is configured as a downloadable attachment.

  4. Virtual Elements
     All new fields are calculated by ZCL_FI_ACCTDOC_FORM.
     They are not database columns.

  5. Keys
     CompanyCode, FiscalYear and AccountingDocument identify
     one accounting document.

  6. Composition
     _Item exposes the accounting document items through
     the projected child entity.

  7. Adobe Form Data Provider
     OUTPUT_FORM_DATA_PROVIDER is retained so this projection
     remains available as the Adobe Form data source.
*/
