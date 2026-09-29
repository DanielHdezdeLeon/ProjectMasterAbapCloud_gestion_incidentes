@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Incidentes'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZCDS_I_INCIDENT_DHL
  as select from zdt_inct_dhl
  composition [0..*] of ZCDS_I_INCT_H_DHL as _History
  association [0..1] to zdt_status_dhl    as _Status   on $projection.Status = _Status.status_code
  association [0..1] to zdt_priority_dhl  as _Priority on $projection.Priority = _Priority.priority_code

{
  key inc_uuid              as IncUuid,
      incident_id           as IncidentId,
      title                 as Title,
      description           as Description,
      @ObjectModel.foreignKey.association: '_Status'

      status                as Status,
      @ObjectModel.foreignKey.association: '_Priority'
    
      priority              as Priority,
      creation_date         as CreationDate,
      changed_date          as ChangedDate,
      @Semantics.user.createdBy: true
      local_created_by      as LocalCreatedBy,
      @Semantics.systemDateTime.createdAt: true
      local_created_at      as LocalCreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      _Status,
      _Priority,
      _History // Make association public
}
