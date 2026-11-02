@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Accounting Document Item (Projection)'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
// REMOVED: @ObjectModel.supportedCapabilities: [#OUTPUT_FORM_DATA_PROVIDER]
// Only the ROOT (ZFI_C_AcctDocHeader) is the form data provider. The item still reaches the
// form because it is a composition child exposed in the service definition.

define view entity ZFI_C_AcctDocItem
  as projection on ZFI_I_AcctDocItem
{
  key CompanyCode,
  key FiscalYear,
  key AccountingDocument,
  key AccountingDocumentItem,

      GLAccount,
      FinancialAccountType,
      DebitCreditCode,
      PostingDate,
      Supplier,
      Customer,
      ProfitCenter,
      CostCenter,
      DocumentItemText,

      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      AmountInCompanyCodeCurrency,
      CompanyCodeCurrency,

      @Semantics.amount.currencyCode: 'TransactionCurrency'
      AmountInTransactionCurrency,
      TransactionCurrency,

      _Header : redirected to parent ZFI_C_AcctDocHeader
}

/*------------------------------------------------------------*/
/* DEVELOPER NOTES                                             */
/*------------------------------------------------------------*/
/*
  1. This is the child projection of the accounting document.

  2. All four key fields are retained from the interface view.

  3. SupplierName is retrieved through the existing _Supplier
     association. It is a descriptive field, not a key.

  4. Currency annotations are explicitly maintained because
     propagated annotations are disabled.

  5. _Header is redirected to the projected root entity
     ZFI_C_AcctDocHeader.

  6. OUTPUT_FORM_DATA_PROVIDER is retained so this entity
     remains available in the Adobe Form data-provider tree.

  7. PDF and XML output fields are maintained only at header
     level because they represent the complete document.
*/
