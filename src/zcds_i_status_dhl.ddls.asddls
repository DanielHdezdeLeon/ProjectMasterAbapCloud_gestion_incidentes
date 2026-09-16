@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZCDS_I_STATUS_DHL as select from zdt_status_dhl
{
    key status_code as StatusCode,
    status_description as StatusDescription
}
