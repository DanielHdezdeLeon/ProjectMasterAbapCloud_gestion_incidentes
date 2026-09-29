CLASS lhc_ZCDS_I_INCIDENT_DHL DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.



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
*    METHODS saveHistory FOR MODIFY
*       keys FOR ACTION Incident~saveHistory.

    METHODS validate_status_change  IMPORTING
                                      iv_status       TYPE zde_status_dhl
                                    RETURNING
                                      VALUE(rv_valid) TYPE abap_bool.
    TYPES:
      tt_incident_read    TYPE TABLE FOR READ RESULT zcds_i_incident_dhl,
      ty_history_failed   TYPE RESPONSE FOR FAILED zcds_i_incident_dhl,
      ty_history_reported TYPE RESPONSE FOR REPORTED zcds_i_incident_dhl,
      tt_change_status    TYPE TABLE FOR ACTION IMPORT zcds_i_incident_dhl~Change_Status.

    METHODS saveHistory2
      IMPORTING
        it_incident   TYPE tt_incident_read
        it_valid_keys TYPE tt_change_status
      EXPORTING
        et_failed     TYPE ty_history_failed
        et_reported   TYPE ty_history_reported.

ENDCLASS.

CLASS lhc_ZCDS_I_INCIDENT_DHL IMPLEMENTATION.

  METHOD get_instance_features.

    READ ENTITIES OF zcds_i_incident_dhl
    IN LOCAL MODE
    ENTITY Incident
    FIELDS ( status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_incident).

    IF 1 = 2 .
      result = VALUE #(
      FOR ls_incident IN lt_incident (
      %tky = ls_incident-%tky
      %action-Change_Status =
      COND #(
      WHEN ls_incident-status = 'CL'
      THEN if_abap_behv=>fc-o-disabled
      ELSE if_abap_behv=>fc-o-enabled
      )
      )
      ).
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD Change_Status.

    DATA lt_valid_keys LIKE keys.

    "Tabla para preparar todas las altas de histórico
    DATA lt_history_create TYPE TABLE FOR CREATE zcds_i_incident_dhl\_History.
    " 0. Validate the new status against the domain fixed values BEFORE doing anything else

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

    " 1. Read current data of the instances to be changed (only the valid ones)
    READ ENTITIES OF zcds_i_incident_dhl
    IN LOCAL MODE
    ENTITY Incident
*    FIELDS ( status )
    ALL FIELDS
    WITH CORRESPONDING #( lt_valid_keys )
    RESULT DATA(lt_incident)
    FAILED DATA(lt_read_failed)
    REPORTED DATA(lt_read_reported).

    APPEND LINES OF lt_read_failed-incident
    TO failed-incident.

    APPEND LINES OF lt_read_reported-incident
    TO reported-incident.

    " 2. Update the status with the new value coming from the abstract entity parameter (NewStatus)
    MODIFY ENTITIES OF zcds_i_incident_dhl
    IN LOCAL MODE
    ENTITY Incident
    UPDATE FIELDS ( status )
    WITH VALUE #(
      FOR ls_key1 IN lt_valid_keys (
        %tky   = ls_key1-%tky
        status = ls_key1-%param-NewStatus
      )
    )
    FAILED DATA(lt_update_failed)
    REPORTED DATA(lt_update_reported).

    APPEND LINES OF lt_update_failed-incident
    TO failed-incident.

    APPEND LINES OF lt_update_reported-incident
    TO reported-incident.


    savehistory2(
      EXPORTING
        it_incident   = lt_incident
        it_valid_keys = lt_valid_keys
      IMPORTING
        et_failed     = DATA(lt_history_failed)
        et_reported   = DATA(lt_history_reported)
    ).

    APPEND LINES OF lt_history_failed-incident
   TO failed-incident.

    APPEND LINES OF lt_history_reported-incident
    TO reported-incident.

    " 3. Create a history entry with the comment/text provided in the parameter
*    LOOP AT lt_incident INTO DATA(ls_incidente).
*      MODIFY ENTITIES OF zcds_i_incident_dhl
*      IN LOCAL MODE
*      ENTITY Incident
*      CREATE BY \_History
*      FIELDS ( IncUuid HisId PreviousStatus NewStatus Text )
*      WITH VALUE #(
*        FOR ls_key2 IN lt_valid_keys (
*          %tky = ls_key2-%tky
*          %target = VALUE #(
*            (
*              %cid       = |HIST_{ sy-index }|
*              IncUuid    = ls_incidente-IncUuid
*              HisId      = ls_incidente-IncidentId
*              NewStatus  = ls_key2-%param-NewStatus
*              PreviousStatus = ls_incidente-status
*              Text       = ls_key2-%param-Text
*            )
*          )
*        )
*      )
*      FAILED failed
*      REPORTED reported.
*
*    ENDLOOP.

    " 4. Re-read the updated instances to return them as the action result
    READ ENTITIES OF zcds_i_incident_dhl
    IN LOCAL MODE
    ENTITY Incident
    ALL FIELDS WITH CORRESPONDING #( lt_valid_keys )
    RESULT DATA(lt_incident_updated).

    result = VALUE #(
      FOR ls_incident IN lt_incident_updated (
        %tky   = ls_incident-%tky
        %param = ls_incident
      )
    ).
  ENDMETHOD.

  METHOD Initialvalue.

    DATA lv_incident_id TYPE zcds_i_incident_dhl-IncidentId.

    " Obtener el último IncidentID persistido
    SELECT MAX( IncidentId )
    FROM zcds_i_incident_dhl
    INTO @lv_incident_id.

    lv_incident_id = lv_incident_id + 1.

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

  METHOD createInitialValue.

    READ ENTITIES OF zcds_i_incident_dhl
      IN LOCAL MODE
      ENTITY Incident
      FIELDS ( IncUuid IncidentId Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_incidents)
      FAILED DATA(lt_read_failed)
      REPORTED DATA(lt_read_reported).

    IF lt_incidents IS INITIAL.
      RETURN.
    ENDIF.

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

  METHOD validate_status_change.
    SELECT SINGLE @abap_true
      FROM zcds_i_status_dhl
      WHERE StatusCode = @iv_status
      INTO @rv_valid.

    IF sy-subrc <> 0.
      rv_valid = abap_false.
    ENDIF.
  ENDMETHOD.

*  METHOD saveHistory.
*
*
*
*  ENDMETHOD.

  METHOD savehistory2.
    DATA lt_history_create TYPE TABLE FOR CREATE zcds_i_incident_dhl\_History.
    DATA(lv_history_number) = 0.
    LOOP AT it_incident INTO DATA(ls_incident).
      READ TABLE it_valid_keys
      INTO DATA(ls_valid_key)
      WITH KEY %tky = ls_incident-%tky.

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      lv_history_number += 1.

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

  METHOD SetCreationDate.

  MODIFY ENTITIES OF zcds_i_incident_dhl
    IN LOCAL MODE
    ENTITY Incident
    UPDATE FIELDS ( ChangedDate )
    WITH VALUE #(
      FOR key IN keys
      (
        %tky        = key-%tky
        ChangedDate = cl_abap_context_info=>get_system_date( )
      )
    )
    FAILED DATA(lt_failed)
    REPORTED DATA(lt_reported).
  ENDMETHOD.

ENDCLASS.

CLASS lhc_ZCDS_I_INCT_H_DHL DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      keys REQUEST requested_features FOR History RESULT result.

ENDCLASS.

CLASS lhc_ZCDS_I_INCT_H_DHL IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.

ENDCLASS.
