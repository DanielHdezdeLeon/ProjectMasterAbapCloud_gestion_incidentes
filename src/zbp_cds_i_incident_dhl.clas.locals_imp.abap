CLASS lhc_ZCDS_I_INCIDENT_DHL DEFINITION INHERITING FROM cl_abap_behavior_handler.
  " DHL: Clase manejadora del comportamiento RAP de la entidad Incident (acciones, determinaciones y autorizaciones).
  PRIVATE SECTION.

    " DHL: Estados finales: cuando un incidente llega a uno de ellos, ya no puede modificarse.
    CONSTANTS: BEGIN OF c_status,
                 closed   TYPE zde_status_dhl VALUE 'CL',
                 canceled TYPE zde_status_dhl VALUE 'CN',
               END OF c_status.


    METHODS get_instance_features FOR INSTANCE FEATURES
      keys REQUEST requested_features FOR Incident RESULT result.


    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR Incident RESULT result.


    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR Incident RESULT result.


    METHODS Change_Status FOR MODIFY
       keys FOR ACTION Incident~Change_Status RESULT result.


    METHODS Initialvalue FOR DETERMINE ON MODIFY
       keys FOR Incident~Initialvalue.


    METHODS createInitialValue FOR DETERMINE ON SAVE
       keys FOR Incident~createInitialValue.

    METHODS SetCreationDate FOR DETERMINE ON MODIFY
       keys FOR Incident~SetCreationDate.

    " DHL: Validación de campos obligatorios: title, Description, Priority no pueden estar vacíos.
    METHODS validate_mandatory_fields FOR VALIDATE ON SAVE
       keys FOR Incident~validate_mandatory_fields.

    METHODS validate_status_change  IMPORTING
                                      iv_status       TYPE zde_status_dhl
                                    RETURNING
                                      VALUE(rv_valid) TYPE abap_bool.

    "! DHL: Comprueba si la transición del estado actual al nuevo estado está permitida
    "! (los estados finales son inmutables y no se permite repetir el mismo estado).
    METHODS validate_status_transition IMPORTING
                                         iv_current_status TYPE zde_status_dhl
                                         iv_new_status     TYPE zde_status_dhl
                                       RETURNING
                                         VALUE(rv_valid)   TYPE abap_bool.

    " DHL: Tipos auxiliares para leer incidentes y para las respuestas de failed/reported.
    TYPES:
      tt_incident_read    TYPE TABLE FOR READ RESULT zcds_i_incident_dhl,
      ty_history_failed   TYPE RESPONSE FOR FAILED zcds_i_incident_dhl,
      ty_history_reported TYPE RESPONSE FOR REPORTED zcds_i_incident_dhl,
      tt_change_status    TYPE TABLE FOR ACTION IMPORT zcds_i_incident_dhl~Change_Status.

    " DHL: Crea las entradas de histórico para los cambios de estado válidos.
    METHODS saveHistory2
      IMPORTING
        it_incident   TYPE tt_incident_read
        it_valid_keys TYPE tt_change_status
      EXPORTING
        et_failed     TYPE ty_history_failed
        et_reported   TYPE ty_history_reported.

ENDCLASS.

CLASS lhc_ZCDS_I_INCIDENT_DHL IMPLEMENTATION.
  " DHL: Controla qué acciones están habilitadas según el estado de cada instancia.
  METHOD get_instance_features.

    " DHL: Se lee el estado actual de las instancias solicitadas.
    READ ENTITIES OF zcds_i_incident_dhl
    IN LOCAL MODE
    ENTITY Incident
    FIELDS ( status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_incident).

    " DHL: La acción Change_Status se deshabilita cuando el incidente está en estado final (CL/CN).
    result = VALUE #(
      FOR ls_incident IN lt_incident (
        %tky = ls_incident-%tky
        %action-Change_Status =
          COND #(
            WHEN ls_incident-status = c_status-closed
              OR ls_incident-status = c_status-canceled
            THEN if_abap_behv=>fc-o-disabled
            ELSE if_abap_behv=>fc-o-enabled
          )
      )
    ).
  ENDMETHOD.
  " DHL: Autorización a nivel de instancia (actualizar / borrar).
  METHOD get_instance_authorizations.

    " DHL: Se lee el creador y el estado de cada incidente.
    READ ENTITIES OF zcds_i_incident_dhl
    IN LOCAL MODE
    ENTITY Incident
    FIELDS ( LocalCreatedBy status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_incident).

    " DHL: Regla de negocio: solo el creador del incidente puede actualizarlo o borrarlo.
    " Cualquier usuario puede leerlo.
    result = VALUE #(
      FOR ls_incident IN lt_incident (
        %tky = ls_incident-%tky

        %update = COND #(
          WHEN ls_incident-LocalCreatedBy = sy-uname
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

        %delete = COND #(
          WHEN ls_incident-LocalCreatedBy = sy-uname
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )
      )
    ).
  ENDMETHOD.
  " DHL: Autorización global (crear).
  METHOD get_global_authorizations.
    " DHL: Cualquier usuario autenticado de este servicio puede crear incidentes.

    result-%create = if_abap_behv=>auth-allowed.
  ENDMETHOD.
  " DHL: Acción que cambia el estado de un incidente y registra el histórico.
  METHOD Change_Status.

    " DHL: lt_valid_keys = claves con estado válido; lt_transition_keys = claves con transición permitida.
    DATA lt_valid_keys      LIKE keys.
    DATA lt_transition_keys LIKE keys.

    " DHL: 1. Se valida que el nuevo estado exista en el catálogo antes de hacer cualquier otra cosa.
    LOOP AT keys INTO DATA(ls_key).
      IF validate_status_change( ls_key-%param-NewStatus ) = abap_false.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-incident.
        APPEND VALUE #( %tky  = ls_key-%tky
                         %msg = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |Status { ls_key-%param-NewStatus } no es válido| )
                       ) TO reported-incident.
      ELSE.
        APPEND ls_key TO lt_valid_keys.
      ENDIF.
    ENDLOOP.

    IF lt_valid_keys IS INITIAL.
      RETURN.
    ENDIF.

    " DHL: 2. Se leen los datos actuales de las instancias a cambiar (solo las válidas).
    READ ENTITIES OF zcds_i_incident_dhl
    IN LOCAL MODE
    ENTITY Incident
    ALL FIELDS
    WITH CORRESPONDING #( lt_valid_keys )
    RESULT DATA(lt_incident)
    FAILED DATA(lt_read_failed)
    REPORTED DATA(lt_read_reported).

    APPEND LINES OF lt_read_failed-incident
    TO failed-incident.

    APPEND LINES OF lt_read_reported-incident
    TO reported-incident.

    " DHL: 3. Se valida que la transición sea permitida (defensa adicional al control de features):
    " los estados finales no cambian y se rechaza repetir el mismo estado.
    LOOP AT lt_valid_keys INTO DATA(ls_valid_key).
      READ TABLE lt_incident INTO DATA(ls_current)
        WITH KEY %tky = ls_valid_key-%tky.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      IF validate_status_transition(
           iv_current_status = ls_current-status
           iv_new_status     = ls_valid_key-%param-NewStatus ) = abap_false.

        APPEND VALUE #( %tky = ls_valid_key-%tky ) TO failed-incident.
        APPEND VALUE #( %tky  = ls_valid_key-%tky
                         %msg = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |No es posible cambiar de { ls_current-status } a { ls_valid_key-%param-NewStatus }| )
                       ) TO reported-incident.
      ELSE.
        APPEND ls_valid_key TO lt_transition_keys.
      ENDIF.
    ENDLOOP.

    IF lt_transition_keys IS INITIAL.
      RETURN.
    ENDIF.

    " DHL: 4. Se actualiza el estado con el valor del parámetro NewStatus de la entidad abstracta.
    " Se actualiza tambien ChangedDate para que siempre refleje el último cambio.
    MODIFY ENTITIES OF zcds_i_incident_dhl
    IN LOCAL MODE
    ENTITY Incident
    UPDATE FIELDS ( status ChangedDate )
    WITH VALUE #(
      FOR ls_key1 IN lt_transition_keys (
        %tky        = ls_key1-%tky
        status      = ls_key1-%param-NewStatus
        ChangedDate = cl_abap_context_info=>get_system_date( )
      )
    )
    FAILED DATA(lt_update_failed)
    REPORTED DATA(lt_update_reported).

    APPEND LINES OF lt_update_failed-incident
    TO failed-incident.

    APPEND LINES OF lt_update_reported-incident
    TO reported-incident.

    " DHL: 5. Se crea la entrada de histórico correspondiente.
    savehistory2(
      EXPORTING
        it_incident   = lt_incident
        it_valid_keys = lt_transition_keys
      IMPORTING
        et_failed     = DATA(lt_history_failed)
        et_reported   = DATA(lt_history_reported)
    ).

    APPEND LINES OF lt_history_failed-incident
   TO failed-incident.

    APPEND LINES OF lt_history_reported-incident
    TO reported-incident.

    " DHL: 6. Se vuelven a leer las instancias actualizadas para devolverlas como resultado de la acción.
    READ ENTITIES OF zcds_i_incident_dhl
    IN LOCAL MODE
    ENTITY Incident
    ALL FIELDS WITH CORRESPONDING #( lt_transition_keys )
    RESULT DATA(lt_incident_updated).

    result = VALUE #(
      FOR ls_incident IN lt_incident_updated (
        %tky   = ls_incident-%tky
        %param = ls_incident
      )
    ).
  ENDMETHOD.
    " DHL: Determinación al modificar: asigna ID, fechas y estado inicial 'OP'.
  METHOD Initialvalue.

    " DHL: NOTA: se creó el objeto de rango de números ZNRINCDHL para este fin, pero la API
    " liberada cl_numberrange_runtime de este sistema no admite aún una llamada NUMBER_GET
    " compatible en este punto. Por ahora se mantiene el enfoque MAX()+1; el intervalo "01"
    " de ZNRINCDHL queda reservado para una futura migración a una numeración sin
    " condiciones de carrera (API liberada o bloqueo sobre ZDT_INCT_DHL).
    DATA lv_incident_id TYPE zcds_i_incident_dhl-IncidentId.

    " DHL: Se obtiene el mayor ID de incidente existente.
    SELECT MAX( IncidentId )
    FROM zcds_i_incident_dhl
    INTO @lv_incident_id.

    " DHL: Se calcula el siguiente ID.
    lv_incident_id = lv_incident_id + 1.

    " DHL: Se asignan ID, fechas de creación/cambio (hoy) y estado inicial 'OP' (abierto).
    MODIFY ENTITIES OF zcds_i_incident_dhl IN LOCAL MODE
    ENTITY Incident
    UPDATE FIELDS ( IncidentId
                    ChangedDate
                    CreationDate
                    Status )
    WITH VALUE #(
    FOR key IN keys
    ( %tky = key-%tky
    IncidentId = lv_incident_id
    CreationDate = cl_abap_context_info=>get_system_date( )
    ChangedDate = cl_abap_context_info=>get_system_date( )
    Status = 'OP' )
    ).

  ENDMETHOD.
  " DHL: Determinación al guardar: crea la primera entrada del histórico.
  METHOD createInitialValue.

    " DHL: Se leen los incidentes recién creados.
    READ ENTITIES OF zcds_i_incident_dhl
      IN LOCAL MODE
      ENTITY Incident
      FIELDS ( IncUuid IncidentId Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_incidents)
      FAILED DATA(lt_read_failed)
      REPORTED DATA(lt_read_reported).

    " DHL: Si no hay datos, no hay nada que hacer.
    IF lt_incidents IS INITIAL.
      RETURN.
    ENDIF.

    " DHL: Se crea la entrada inicial del histórico ("First Incident") para cada incidente.
    MODIFY ENTITIES OF zcds_i_incident_dhl
      IN LOCAL MODE
      ENTITY Incident
      CREATE BY \_History
      FIELDS (
        HisId
        PreviousStatus
        NewStatus
        Text
      )
      WITH VALUE #(
        FOR ls_incident IN lt_incidents
        (
          %tky = ls_incident-%tky

          %target = VALUE #(
            (
              %cid           = |INITIAL_{ sy-tabix }|
              %is_draft      = ls_incident-%is_draft
              HisId          = ls_incident-IncidentId
              PreviousStatus = ''
              NewStatus      = ls_incident-Status
              Text           = 'First Incident'
            )
          )
        )
      )
      FAILED DATA(lt_history_failed)
      REPORTED DATA(lt_history_reported).


  ENDMETHOD.
    " DHL: Comprueba que el código de estado exista en el catálogo de estados.
  METHOD validate_status_change.
    " DHL: Busca el código de estado en la vista CDS de estados; si no existe, no es válido.
    SELECT SINGLE @abap_true
      FROM zcds_i_status_dhl
      WHERE StatusCode = @iv_status
      INTO @rv_valid.

    IF sy-subrc <> 0.
      rv_valid = abap_false.
    ENDIF.
  ENDMETHOD.

  METHOD validate_status_transition.

    " DHL: Los estados finales son inmutables: un incidente cerrado o cancelado no puede cambiar de estado.
    IF iv_current_status = c_status-closed OR iv_current_status = c_status-canceled.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    " DHL: Repetir el mismo estado no se considera una transición válida.
    IF iv_current_status = iv_new_status.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    " DHL: Si no se cumple ninguna restricción, la transición es válida.
    rv_valid = abap_true.

  ENDMETHOD.

  METHOD savehistory2.
    " DHL: Tabla donde se acumulan las entradas de histórico a crear.
    DATA lt_history_create TYPE TABLE FOR CREATE zcds_i_incident_dhl\_History.
    DATA(lv_history_number) = 0.
    " DHL: Se recorre cada incidente y se busca su solicitud de cambio válida.
    LOOP AT it_incident INTO DATA(ls_incident).
      READ TABLE it_valid_keys
      INTO DATA(ls_valid_key)
      WITH KEY %tky = ls_incident-%tky.

      " DHL: Si el incidente no tiene cambio válido, se omite.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " DHL: Contador para generar un %cid único por entrada de histórico.
      lv_history_number += 1.

      " DHL: Se registra el estado anterior, el nuevo y el texto del cambio.
      APPEND VALUE #(
      %tky = ls_incident-%tky

      %target = VALUE #(
      (
      %cid = |HIST_{ lv_history_number }|
      %is_draft = ls_incident-%is_draft
      IncUuid = ls_incident-IncUuid
      HisId = ls_incident-IncidentId
      PreviousStatus = ls_incident-status
      NewStatus = ls_valid_key-%param-NewStatus
      Text = ls_valid_key-%param-Text
      )
      )
      ) TO lt_history_create.

    ENDLOOP.

    " DHL: Si hay entradas, se crean en la entidad hija History.
    IF lt_history_create IS NOT INITIAL.

      MODIFY ENTITIES OF zcds_i_incident_dhl
      IN LOCAL MODE
      ENTITY Incident
      CREATE BY \_History
      FIELDS (
      HisId
      PreviousStatus
      NewStatus
      Text
      )
      WITH lt_history_create
      FAILED et_failed
      REPORTED et_reported.

    ENDIF.

  ENDMETHOD.
 " DHL: Determinación al modificar: actualiza la fecha de última modificación.
  METHOD SetCreationDate.

    " DHL: Esta determinación se dispara en cualquier actualización de la instancia, incluida la
    " que ella misma realiza sobre ChangedDate. Sin una comprobación previa se produciría un
    " bucle infinito (RAP lanza RAISE_SHORTDUMP al superar su límite de rondas). Por ello solo
    " se modifican las instancias cuya ChangedDate no esté ya al día, de modo que la segunda
    " ronda no encuentra nada que hacer y el proceso se estabiliza.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    " DHL: Se lee la fecha de cambio actual de las instancias afectadas.
    READ ENTITIES OF zcds_i_incident_dhl
      IN LOCAL MODE
      ENTITY Incident
      FIELDS ( ChangedDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_current).

    " DHL: Se seleccionan solo las instancias con fecha distinta de hoy.
    DATA lt_keys_to_update LIKE keys.
    LOOP AT lt_current INTO DATA(ls_current) WHERE ChangedDate <> lv_today.
      APPEND VALUE #( %tky = ls_current-%tky ) TO lt_keys_to_update.
    ENDLOOP.

    " DHL: Si todas están al día, se termina.
    IF lt_keys_to_update IS INITIAL.
      RETURN.
    ENDIF.

    " DHL: Se actualiza ChangedDate con la fecha del sistema.
    MODIFY ENTITIES OF zcds_i_incident_dhl
      IN LOCAL MODE
      ENTITY Incident
      UPDATE FIELDS ( ChangedDate )
      WITH VALUE #(
        FOR key IN lt_keys_to_update
        (
          %tky        = key-%tky
          ChangedDate = lv_today
        )
      )
      FAILED DATA(lt_failed)
      REPORTED DATA(lt_reported).
  ENDMETHOD.

  " DHL: Validación al guardar: verifica que los campos obligatorios no estén vacíos.
  METHOD validate_mandatory_fields.
    " DHL: Se leen los datos del incidente para validar campos obligatorios.
    READ ENTITIES OF zcds_i_incident_dhl
      IN LOCAL MODE
      ENTITY Incident
      FIELDS ( Title Description Priority )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_incidents)
      FAILED DATA(lt_read_failed)
      REPORTED DATA(lt_read_reported).

    " DHL: Se recorre cada incidente y se valida que los campos obligatorios tengan valor.
    LOOP AT lt_incidents INTO DATA(ls_incident).
      IF ls_incident-Title IS INITIAL.
        APPEND VALUE #( %tky = ls_incident-%tky ) TO failed-incident.
        APPEND VALUE #(
          %tky  = ls_incident-%tky
          %msg  = new_message_with_text(
                    severity = if_abap_behv_message=>severity-error
                    text     = 'El título (Title) es obligatorio'
                  )
        ) TO reported-incident.
      ENDIF.

      IF ls_incident-Description IS INITIAL.
        APPEND VALUE #( %tky = ls_incident-%tky ) TO failed-incident.
        APPEND VALUE #(
          %tky  = ls_incident-%tky
          %msg  = new_message_with_text(
                    severity = if_abap_behv_message=>severity-error
                    text     = 'La descripción (Description) es obligatoria'
                  )
        ) TO reported-incident.
      ENDIF.

      IF ls_incident-Priority IS INITIAL.
        APPEND VALUE #( %tky = ls_incident-%tky ) TO failed-incident.
        APPEND VALUE #(
          %tky  = ls_incident-%tky
          %msg  = new_message_with_text(
                    severity = if_abap_behv_message=>severity-error
                    text     = 'La prioridad (Priority) es obligatoria'
                  )
        ) TO reported-incident.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
CLASS lhc_ZCDS_I_INCT_H_DHL DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      keys REQUEST requested_features FOR History RESULT result.

ENDCLASS.

CLASS lhc_ZCDS_I_INCT_H_DHL IMPLEMENTATION.
" DHL: Clase manejadora del comportamiento de la entidad hija History (histórico de estados).
  METHOD get_instance_features.
    " DHL: Sin lógica por ahora: el histórico no tiene restricciones de features.
  ENDMETHOD.

ENDCLASS.

