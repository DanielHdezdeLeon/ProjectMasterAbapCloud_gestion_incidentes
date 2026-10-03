CLASS zcl_load_data_project_dhl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.



  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    METHODS:
      delete_tables IMPORTING out TYPE REF TO if_oo_adt_classrun_out,
      fill_priority IMPORTING out TYPE REF TO if_oo_adt_classrun_out,
      fill_status IMPORTING out TYPE REF TO if_oo_adt_classrun_out,
      create_incident_dhl
        IMPORTING
          out              TYPE REF TO if_oo_adt_classrun_out
          iv_title         TYPE string
          iv_description   TYPE string
          iv_status        TYPE string
          iv_priority      TYPE string,
      cleanup_empty_history_records IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

    METHODS load_demo_data.
ENDCLASS.


CLASS zcl_load_data_project_dhl IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    " DHL: Descomentados para ejecutar al invocar la clase
    " delete_tables( out ).
    " fill_status( out ).
    " fill_priority( out ).
    " load_demo_data( ).
    cleanup_empty_history_records( out ).
    create_incident_dhl(
	  out            = out
	  iv_title       = 'Incidente de prueba DHL'
	  iv_description = 'Este es un incidente de prueba creado por el usuario DHL.'
	  iv_status      = 'OP'
	  iv_priority    = 'H'
	).
	

  ENDMETHOD.

    METHOD fill_status.
      DATA lt_status TYPE STANDARD TABLE OF zdt_status_dhl
                       WITH EMPTY KEY.

      lt_status = VALUE #(
        ( status_code = 'OP'
          status_description = 'Open' )

        ( status_code = 'IP'
          status_description = 'In Progress' )

        ( status_code = 'PE'
          status_description = 'Pending' )

        ( status_code = 'CO'
          status_description = 'Completed' )

        ( status_code = 'CL'
          status_description = 'Closed' )

        ( status_code = 'CN'
          status_description = 'Canceled' )
      ).

      MODIFY zdt_status_dhl FROM TABLE @lt_status.

      IF sy-subrc = 0.
        COMMIT WORK.
        out->write(
          |Estados cargados correctamente: { lines( lt_status ) }|
        ).
      ELSE.
        ROLLBACK WORK.
        out->write(
          |Error al cargar los estados. SY-SUBRC: { sy-subrc }|
        ).
      ENDIF.

    ENDMETHOD.

    METHOD delete_tables.
      " Only reset the demo master data for the local (test/demo) client.
      " Never run this class against a system where zdt_status_dhl /
      " zdt_priority_dhl already contain productive data.
      DELETE FROM zdt_status_dhl.
      DELETE FROM zdt_priority_dhl.

      IF sy-subrc = 0.
        COMMIT WORK.
        out->write(
          |Tablas eliminadas correctamente.|
        ).
      ELSE.
        ROLLBACK WORK.
        out->write(
          |Error al eliminar la tabla zdt_status_dhl. SY-SUBRC: { sy-subrc }|
        ).
      ENDIF.
    ENDMETHOD.

    METHOD fill_priority.
      DATA lt_status TYPE STANDARD TABLE OF zdt_priority_dhl
                          WITH EMPTY KEY.

      lt_status = VALUE #(
        ( priority_code = 'H'
          priority_description = 'High' )
        ( priority_code = 'M'
          priority_description = 'Medium' )
        ( priority_code = 'L'
          priority_description = 'Low' )
      ).

      MODIFY zdt_priority_dhl FROM TABLE @lt_status.

      IF sy-subrc = 0.
        COMMIT WORK.
        out->write(
          |Estados cargados correctamente: { lines( lt_status ) }|
        ).
      ELSE.
        ROLLBACK WORK.
        out->write(
          |Error al cargar los estados. SY-SUBRC: { sy-subrc }|
        ).
      ENDIF.

    ENDMETHOD.

METHOD load_demo_data.

  DATA:
    lv_inc_uuid TYPE sysuuid_x16,
    lv_his_uuid TYPE sysuuid_x16,
    lv_timestamp TYPE timestampl.

  TRY.

      GET TIME STAMP FIELD lv_timestamp.

      DO 10 TIMES.

        DATA(lv_index) = sy-index.

        lv_inc_uuid = cl_system_uuid=>create_uuid_x16_static( ).
        lv_his_uuid = cl_system_uuid=>create_uuid_x16_static( ).

        INSERT zdt_inct_dhl FROM @( VALUE #(
          client                = sy-mandt
          inc_uuid              = lv_inc_uuid
          incident_id           = lv_index
          title                 = |Incidente { lv_index }|
          description           = |Descripción incidente { lv_index }|
          status                = 'OP'
          priority              = 'H'
          creation_date         = cl_abap_context_info=>get_system_date( )
          changed_date          = cl_abap_context_info=>get_system_date( )
          local_created_by      = sy-uname
          local_created_at      = lv_timestamp
          local_last_changed_by = sy-uname
          local_last_changed_at = lv_timestamp
          last_changed_at       = lv_timestamp
        ) ).

        IF sy-subrc <> 0.
          ROLLBACK WORK.
          RETURN.
        ENDIF.

        INSERT zdt_inct_h_dhl FROM @( VALUE #(
          client                = sy-mandt
          his_uuid              = lv_his_uuid
          inc_uuid              = lv_inc_uuid
          his_id                = lv_index
          previous_status       = ''
          new_status            = 'OP'
          text                  = |Creación del incidente { lv_index }|
          local_created_by      = sy-uname
          local_created_at      = lv_timestamp
          local_last_changed_by = sy-uname
          local_last_changed_at = lv_timestamp
          last_changed_at       = lv_timestamp
        ) ).

        IF sy-subrc <> 0.
          ROLLBACK WORK.
          RETURN.
        ENDIF.

      ENDDO.

      COMMIT WORK.

    CATCH cx_uuid_error INTO DATA(lx_uuid).
      ROLLBACK WORK.

      " Sustituye esto por tu gestión de mensajes si fuera necesario
      DATA(lv_error_text) = lx_uuid->get_text( ).

  ENDTRY.

ENDMETHOD.

METHOD cleanup_empty_history_records.
  " DHL: Metodo para eliminar registros del historico con his_id vacio o nulo.
  DATA lv_deleted_count TYPE i.

  TRY.

    " DHL: Se eliminan todos los registros de ZDT_INCT_H_DHL donde his_id esta vacio o es nulo.
    DELETE FROM zdt_inct_h_dhl WHERE his_id = '' OR his_id IS NULL.

    lv_deleted_count = sy-dbcnt.

    IF sy-subrc = 0.
      COMMIT WORK.
      out->write(
        |Limpieza de historico completada. Registros eliminados: { lv_deleted_count }|
      ).
    ELSE.
      ROLLBACK WORK.
      out->write(
        |Error al limpiar el historico. SY-SUBRC: { sy-subrc }|
      ).
    ENDIF.

  CATCH cx_root INTO DATA(lx_error).
    ROLLBACK WORK.
    out->write(
      |Error al limpiar historico: { lx_error->get_text( ) }|
    ).

  ENDTRY.

ENDMETHOD.

METHOD create_incident_dhl.
  " DHL: Metodo para crear un incidente con usuario DHL en la tabla ZDT_INCT_DHL.
  DATA lv_inc_uuid TYPE sysuuid_x16.
  DATA lv_his_uuid TYPE sysuuid_x16.
  DATA lv_timestamp TYPE timestampl.

  TRY.

    " DHL: Se generan UUIDs unicos para el incidente y su historico inicial.
    lv_inc_uuid = cl_system_uuid=>create_uuid_x16_static( ).
    lv_his_uuid = cl_system_uuid=>create_uuid_x16_static( ).
    GET TIME STAMP FIELD lv_timestamp.

    " DHL: Se inserta el incidente con usuario DHL.
    INSERT zdt_inct_dhl FROM @( VALUE #(
      client                = sy-mandt
      inc_uuid              = lv_inc_uuid
      incident_id           = 999  " Valor por defecto; se puede actualizar despues
      title                 = iv_title
      description           = iv_description
      status                = iv_status
      priority              = iv_priority
      creation_date         = cl_abap_context_info=>get_system_date( )
      changed_date          = cl_abap_context_info=>get_system_date( )
      local_created_by      = 'DHL'
      local_created_at      = lv_timestamp
      local_last_changed_by = 'DHL'
      local_last_changed_at = lv_timestamp
      last_changed_at       = lv_timestamp
    ) ).

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      out->write( |Error al crear incidente. SY-SUBRC: { sy-subrc }| ).
      RETURN.
    ENDIF.

    " DHL: Se crea el primer registro del historico.
    INSERT zdt_inct_h_dhl FROM @( VALUE #(
      client                = sy-mandt
      his_uuid              = lv_his_uuid
      inc_uuid              = lv_inc_uuid
      his_id                = 999
      previous_status       = ''
      new_status            = iv_status
      text                  = |Incidente creado por usuario DHL: { iv_title }|
      local_created_by      = 'DHL'
      local_created_at      = lv_timestamp
      local_last_changed_by = 'DHL'
      local_last_changed_at = lv_timestamp
      last_changed_at       = lv_timestamp
    ) ).

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      out->write( |Error al crear historico del incidente. SY-SUBRC: { sy-subrc }| ).
      RETURN.
    ENDIF.

    COMMIT WORK.
    out->write( |Incidente creado exitosamente con usuario DHL| ).
    out->write( |UUID del incidente: { lv_inc_uuid }| ).
    out->write( |Titulo: { iv_title }| ).
    out->write( |Descripcion: { iv_description }| ).
    out->write( |Estado: { iv_status }| ).
    out->write( |Prioridad: { iv_priority }| ).

  CATCH cx_root INTO DATA(lx_error).
    ROLLBACK WORK.
    out->write( |Error al crear incidente: { lx_error->get_text( ) }| ).

  ENDTRY.

ENDMETHOD.

ENDCLASS.
