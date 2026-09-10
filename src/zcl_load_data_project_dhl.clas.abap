CLASS zcl_load_data_project_dhl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.


CLASS zcl_load_data_project_dhl IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

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

ENDCLASS.
