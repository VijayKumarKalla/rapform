@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Accounting Document Item'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZFI_I_AcctDocItem
  as select from I_OperationalAcctgDocItem

  /*----------------------------------------------------------*/
  /* Parent Association                                       */
  /*----------------------------------------------------------*/
  association to parent ZFI_I_AcctDocHeader as _Header
    on  _Header.CompanyCode        = $projection.CompanyCode
    and _Header.FiscalYear         = $projection.FiscalYear
    and _Header.AccountingDocument = $projection.AccountingDocument

  /*----------------------------------------------------------*/
  /* Supplier Master Association                              */
  /*----------------------------------------------------------*/
  association [0..1] to I_Supplier as _Supplier
    on _Supplier.Supplier = I_OperationalAcctgDocItem.Supplier

{
  /*----------------------------------------------------------*/
  /* Accounting Document Item Keys                            */
  /*----------------------------------------------------------*/
  key CompanyCode,
  key FiscalYear,
  key AccountingDocument,
  key AccountingDocumentItem,

  /*----------------------------------------------------------*/
  /* General Ledger Information                               */
  /*----------------------------------------------------------*/
      GLAccount,
      FinancialAccountType,
      DebitCreditCode,
      PostingDate,

  /*----------------------------------------------------------*/
  /* Supplier and Customer Information                        */
  /*----------------------------------------------------------*/
      Supplier,
      Customer,

  /*----------------------------------------------------------*/
  /* Organizational Information                               */
  /*----------------------------------------------------------*/
      ProfitCenter,
      CostCenter,

  /*----------------------------------------------------------*/
  /* Document Item Description                                */
  /*----------------------------------------------------------*/
      DocumentItemText,

  /*----------------------------------------------------------*/
  /* Company Code Currency Amount                             */
  /*----------------------------------------------------------*/
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      @Aggregation.default: #SUM
      AmountInCompanyCodeCurrency,
      CompanyCodeCurrency,

  /*----------------------------------------------------------*/
  /* Transaction Currency Amount                              */
  /*----------------------------------------------------------*/
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      @Aggregation.default: #SUM
      AmountInTransactionCurrency,
      TransactionCurrency,

  /*----------------------------------------------------------*/
  /* Associations                                             */
  /*----------------------------------------------------------*/
      _Header,
      _Supplier
}


/*------------------------------------------------------------*/
/* DEVELOPER NOTES                                             */
/*------------------------------------------------------------*/
/*
  1. CHILD ENTITY
     This entity represents accounting document line items.
     It is not a root entity.

  2. DATA SOURCE
     I_OperationalAcctgDocItem is the released SAP source
     used for operational accounting document items.

  3. PARENT ASSOCIATION
     _Header connects every item to its accounting document.
     All three parent keys are matched.

  4. CHILD KEYS
     The four keys identify one individual accounting line.

  5. SUPPLIER ASSOCIATION
     _Supplier provides access to supplier master information.
     The projection uses it to expose SupplierName.

  6. CURRENCY SEMANTICS
     AmountInCompanyCodeCurrency is linked to
     CompanyCodeCurrency.

     AmountInTransactionCurrency is linked to
     TransactionCurrency.

  7. ASSOCIATION EXPOSURE
     Both _Header and _Supplier are exposed so that the
     projection layer can redirect and consume them.

  8. RAP COMPOSITION
     The root entity declares composition [0..*] of this
     child entity. This entity supplies the corresponding
     association to parent.
*/
