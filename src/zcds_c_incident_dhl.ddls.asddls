@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consume rooyt entity'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZCDS_C_INCIDENT_DHL 
provider contract transactional_query
as projection on ZCDS_I_INCIDENT_DHL


{
    key IncUuid,
    IncidentId,
    Title,
    Description,
    Status,
    Priority,
    CreationDate,
    ChangedDate,
    LocalCreatedBy,
    LocalCreatedAt,
    LocalLastChangedBy,
    LocalLastChangedAt,
    LastChangedAt,
    /* Associations */
    _History: redirected to composition child ZCDS_C_INCT_H_DHL,
    _Priority,
    _Status
}
