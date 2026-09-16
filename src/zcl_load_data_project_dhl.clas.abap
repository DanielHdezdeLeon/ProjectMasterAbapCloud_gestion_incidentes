CLASS zcl_load_data_project_dhl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.



  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    METHODS: delete_tables IMPORTING out TYPE REF TO if_oo_adt_classrun_out,
      fill_priority IMPORTING out TYPE REF TO if_oo_adt_classrun_out,
      fill_status IMPORTING out TYPE REF TO if_oo_adt_classrun_out. .

    METHODS load_demo_data.
ENDCLASS.


CLASS zcl_load_data_project_dhl IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    delete_tables( out ).
    fill_status( out ).
    fill_priority( out ).
    load_demo_data( ).


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
          creation_date         = sy-datum
          changed_date          = sy-datum
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
          previous_status       = 'NW'
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

ENDCLASS.
