@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Accounting Document Header'
@Metadata.ignorePropagatedAnnotations: true
@AbapCatalog.viewEnhancementCategory: [#NONE]

define root view entity ZFI_I_AcctDocHeader
  as select from I_JournalEntry

  /*----------------------------------------------------------*/
  /* Header-to-Item Composition                               */
  /*----------------------------------------------------------*/
  composition [0..*] of ZFI_I_AcctDocItem as _Item

{
  /*----------------------------------------------------------*/
  /* Accounting Document Header Keys                          */
  /*----------------------------------------------------------*/
  key CompanyCode,
  key FiscalYear,
  key AccountingDocument,

  /*----------------------------------------------------------*/
  /* Accounting Document Information                          */
  /*----------------------------------------------------------*/
      AccountingDocumentType,
      DocumentDate,
      PostingDate,
      AccountingDocumentHeaderText,
      DocumentReferenceID,
      TransactionCurrency,
      AccountingDocumentCreationDate,

  /*----------------------------------------------------------*/
  /* Child Association                                        */
  /*----------------------------------------------------------*/
      _Item // Exposed safely now that composition structure is pristine
}


/*------------------------------------------------------------*/
/* DEVELOPER NOTES                                             */
/*------------------------------------------------------------*/
/*
  1. ROOT ENTITY
     This is the root node of the accounting document RAP
     business object.

  2. DATA SOURCE
     I_JournalEntry is the SAP released accounting document
     header interface view.

  3. PRIMARY KEY
     CompanyCode + FiscalYear + AccountingDocument uniquely
     identify an accounting document.

  4. COMPOSITION
     _Item defines the parent-child relationship between
     the accounting document header and its line items.

     Cardinality [0..*] allows zero or multiple items.

  5. CHILD ASSOCIATION
     The actual parent relationship is defined in the child
     interface CDS using association to parent.

  6. PROJECTION
     ZFI_C_AcctDocHeader exposes the fields required by
     Fiori Elements and the Adobe Form data provider.

  7. PDF AND XML
     PDF Preview, PDF Download and XML Download are
     presentation/output fields maintained in the projection.
     They do not belong in this interface CDS.

  8. AUTHORIZATION
     #NOT_REQUIRED disables the access-control check for
     this entity. Review authorization design before production
     use because accounting documents contain sensitive data.
*/
