@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Historico'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZCDS_C_INCT_H_DHL
  as projection on ZCDS_I_INCT_H_DHL
{
  key HisUuid,
      IncUuid,
      HisId,
      PreviousStatus,
      NewStatus,
      Text,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,
      /* Associations */
      _Incident: redirected to parent ZCDS_C_INCIDENT_DHL
}
