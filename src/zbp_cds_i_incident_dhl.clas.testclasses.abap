*"* DHL: Clases de prueba ABAP Unit para validar la acción Change_Status de incidentes.

CLASS ltc_change_status DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    " DHL: Entorno de test CDS compartido por todos los tests (dobles de las vistas CDS).
    CLASS-DATA:
      environment TYPE REF TO if_cds_test_environment.

    " DHL: Métodos de ciclo de vida: se ejecutan una vez antes/después de todos los tests.
    CLASS-METHODS:
      class_setup,
      class_teardown.

    " DHL: setup se ejecuta antes de cada test; given_incident es un helper para crear datos.
    METHODS:
      setup,

      given_incident
        IMPORTING
          iv_status          TYPE zde_status_dhl
        RETURNING
          VALUE(rv_inc_uuid) TYPE sysuuid_x16
        RAISING
          cx_static_check,

      " DHL: Tests: código inexistente, mismo estado, estado final y transición válida.
      reject_invalid_code FOR TESTING RAISING cx_static_check,
      reject_same_status  FOR TESTING RAISING cx_static_check,
      reject_final_state  FOR TESTING RAISING cx_static_check,
      accept_transition   FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_change_status IMPLEMENTATION.

  METHOD class_setup.
    " DHL: Prepara el entorno CDS doble para aislar las pruebas de persistencia real.
    environment = cl_cds_test_environment=>create_for_multiple_cds(
      i_for_entities = VALUE #(
        ( i_for_entity = 'ZCDS_I_INCIDENT_DHL' )
        ( i_for_entity = 'ZCDS_I_INCT_H_DHL' )
        ( i_for_entity = 'ZCDS_I_STATUS_DHL' )
        ( i_for_entity = 'ZCDS_I_PRIORITY_DHL' )
      )
    ).
  ENDMETHOD.

  METHOD class_teardown.
    " DHL: Libera el entorno de pruebas al finalizar toda la clase.
    environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    " DHL: Limpia dobles y carga catálogos mínimos requeridos para cada test.
    environment->clear_doubles( ).

    " DHL: Catálogo de estados: Abierto (OP), En progreso (IP) y Cerrado (CL).
    DATA lt_status TYPE STANDARD TABLE OF zdt_status_dhl WITH EMPTY KEY.
    lt_status = VALUE #(
      ( client = sy-mandt status_code = 'OP' status_description = 'Open' )
      ( client = sy-mandt status_code = 'IP' status_description = 'In Progress' )
      ( client = sy-mandt status_code = 'CL' status_description = 'Closed' )
    ).
    environment->insert_test_data( i_data = lt_status ).

    " DHL: Catálogo de prioridades: solo se necesita la prioridad Alta (H).
    DATA lt_priority TYPE STANDARD TABLE OF zdt_priority_dhl WITH EMPTY KEY.
    lt_priority = VALUE #(
      ( client = sy-mandt priority_code = 'H' priority_description = 'High' )
    ).
    environment->insert_test_data( i_data = lt_priority ).
  ENDMETHOD.

  METHOD given_incident.
    " DHL: Crea un incidente base en memoria con el estado indicado para probar transiciones.
    " DHL: Se obtiene la marca de tiempo actual para los campos de auditoría.
    DATA lv_timestamp TYPE timestampl.
    GET TIME STAMP FIELD lv_timestamp.

    " DHL: Se genera un UUID único que identifica al incidente de prueba.
    rv_inc_uuid = cl_system_uuid=>create_uuid_x16_static( ).

    " DHL: Se construye la fila del incidente con el estado recibido y campos de auditoría.
    DATA lt_incident TYPE STANDARD TABLE OF zdt_inct_dhl WITH EMPTY KEY.
    lt_incident = VALUE #(
      ( client                = sy-mandt
        inc_uuid              = rv_inc_uuid
        incident_id           = '00000001'
        title                 = 'Test incident'
        description           = 'Created by unit test'
        status                = iv_status
        priority              = 'H'
        creation_date         = cl_abap_context_info=>get_system_date( )
        changed_date          = cl_abap_context_info=>get_system_date( )
        local_created_by      = sy-uname
        local_created_at      = lv_timestamp
        local_last_changed_by = sy-uname
        local_last_changed_at = lv_timestamp
        last_changed_at       = lv_timestamp )
    ).
    " DHL: Se inserta el incidente en la tabla doble para que lo lea el comportamiento RAP.
    environment->insert_test_data( i_data = lt_incident ).
  ENDMETHOD.

  METHOD reject_invalid_code.
    " DHL: Verifica que un estado destino inexistente sea rechazado por la acción.
    DATA(lv_inc_uuid) = given_incident( 'OP' ).

    " DHL: Se ejecuta Change_Status con el código 'XX', que no existe en el catálogo.
    MODIFY ENTITIES OF zcds_i_incident_dhl
      IN LOCAL MODE
      ENTITY Incident
      EXECUTE Change_Status
      FROM VALUE #( ( %tky   = VALUE #( IncUuid = lv_inc_uuid )
                      %param = VALUE #( NewStatus = 'XX' Text = 'invalid code' ) ) )
      FAILED DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " DHL: Se espera que la acción falle (tabla FAILED con registros).
    cl_abap_unit_assert=>assert_not_initial(
      msg = 'Un código de estado inexistente debe rechazarse'
      act = lt_failed-incident ).
  ENDMETHOD.

  METHOD reject_same_status.
    " DHL: Verifica que no se permita transicionar al mismo estado actual.
    DATA(lv_inc_uuid) = given_incident( 'OP' ).

    " DHL: Se intenta cambiar de 'OP' a 'OP' (sin cambio real).
    MODIFY ENTITIES OF zcds_i_incident_dhl
      IN LOCAL MODE
      ENTITY Incident
      EXECUTE Change_Status
      FROM VALUE #( ( %tky   = VALUE #( IncUuid = lv_inc_uuid )
                      %param = VALUE #( NewStatus = 'OP' Text = 'same status' ) ) )
      FAILED DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " DHL: Se espera que la acción falle por repetir el estado.
    cl_abap_unit_assert=>assert_not_initial(
      msg = 'Repetir el mismo estado no debe considerarse una transición válida'
      act = lt_failed-incident ).
  ENDMETHOD.

  METHOD reject_final_state.
    " DHL: Verifica que un incidente cerrado no pueda reabrirse por Change_Status.
    DATA(lv_inc_uuid) = given_incident( 'CL' ).

    " DHL: Se intenta reabrir ('OP') un incidente que está cerrado ('CL').
    MODIFY ENTITIES OF zcds_i_incident_dhl
      IN LOCAL MODE
      ENTITY Incident
      EXECUTE Change_Status
      FROM VALUE #( ( %tky   = VALUE #( IncUuid = lv_inc_uuid )
                      %param = VALUE #( NewStatus = 'OP' Text = 'reopen closed' ) ) )
      FAILED DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " DHL: Se espera que la acción falle porque 'CL' es un estado final.
    cl_abap_unit_assert=>assert_not_initial(
      msg = 'Un incidente en estado final (CL/CN) no debe poder cambiar de estado'
      act = lt_failed-incident ).
  ENDMETHOD.

  METHOD accept_transition.
    " DHL: Verifica una transición válida y confirma la persistencia del nuevo estado.
    DATA(lv_inc_uuid) = given_incident( 'OP' ).

    " DHL: Se cambia de 'OP' a 'IP', transición permitida por las reglas de negocio.
    MODIFY ENTITIES OF zcds_i_incident_dhl
      IN LOCAL MODE
      ENTITY Incident
      EXECUTE Change_Status
      FROM VALUE #( ( %tky   = VALUE #( IncUuid = lv_inc_uuid )
                      %param = VALUE #( NewStatus = 'IP' Text = 'work started' ) ) )
      FAILED DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " DHL: La acción no debe devolver errores (tabla FAILED vacía).
    cl_abap_unit_assert=>assert_initial(
      msg = 'Una transición válida (OP -> IP) no debe fallar'
      act = lt_failed-incident ).

    " DHL: Se lee de nuevo el incidente para comprobar el estado resultante.
    READ ENTITIES OF zcds_i_incident_dhl
      IN LOCAL MODE
      ENTITY Incident
      FIELDS ( Status )
      WITH VALUE #( ( IncUuid = lv_inc_uuid ) )
      RESULT DATA(lt_incident).

    " DHL: Se confirma que el estado almacenado ahora es 'IP'.
    cl_abap_unit_assert=>assert_equals(
      msg = 'El estado debe haberse actualizado a IP'
      act = COND #( WHEN lines( lt_incident ) > 0 THEN lt_incident[ 1 ]-Status ELSE '' )
      exp = 'IP' ).
  ENDMETHOD.

ENDCLASS.


