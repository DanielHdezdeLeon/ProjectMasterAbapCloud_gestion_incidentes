@EndUserText.label: 'Entidad abstracta'
define abstract entity ZABS_CHANGE_STATUS_DHL
{
  @Consumption.valueHelpDefinition: [{
  entity    : {
  name      : 'ZCDS_I_STATUS_DHL',
  element   : 'StatusCode'
  },
  useForValidation : true} ]
  NewStatus : zde_status_dhl;
  Text      : abap.char(80);
}
