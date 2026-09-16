@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status Priority'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZCDS_I_PRIORITY_DHL
  as select from zdt_priority_dhl
{
      @Search.defaultSearchElement: true
  key priority_code        as PriorityCode,
      @Search.defaultSearchElement: true
      priority_description as PriorityDescription
}
