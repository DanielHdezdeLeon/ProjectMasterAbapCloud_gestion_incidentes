@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Historial de incidentes'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZCDS_I_INCT_H_DHL
  as select from zdt_inct_h_dhl
  association to parent ZCDS_I_INCIDENT_DHL as _Incident on $projection.IncUuid = _Incident.IncUuid
{
  key his_uuid              as HisUuid,
      @ObjectModel.foreignKey.association: '_Incident'
      inc_uuid              as IncUuid,
      his_id                as HisId,
      previous_status       as PreviousStatus,
      new_status            as NewStatus,
      text                  as Text,
      local_created_by      as LocalCreatedBy,
      local_created_at      as LocalCreatedAt,
      local_last_changed_by as LocalLastChangedBy,
      local_last_changed_at as LocalLastChangedAt,
      last_changed_at       as LastChangedAt,
      _Incident
}
